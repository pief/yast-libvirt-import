require "fileutils"
require "nokogiri"

module Installation
  class LibvirtImporter
    include Singleton
    include Yast::Logger
    include Yast::I18n

    attr_accessor :cfgfiles

    def initialize
      textdomain "installation"
      @cfgfiles = []
    end

    def scan_device(mount_point, device)
      log.info "Scanning #{device} for libvirt config files"

      # No system partition?
      os_release = File.join(mount_point, "etc", "os-release")
      return unless File.file?(os_release)

      begin
        os_name = Hash[*File.read(os_release).split(/[=\n]+/)]["PRETTY_NAME"].delete!('"')
      rescue IOError, SystemCallError, RuntimeError => error
        log.error "Reading /etc/os-release on #{device} failed with exception: #{error.inspect}"
        os_name = "Linux"
      end

      libvirt_dir = File.join(mount_point, "etc", "libvirt")
      [
        [ "Storage pool", 1, File.join(libvirt_dir, "storage") ],
        [ "Virtual network", 2, File.join(libvirt_dir, "qemu", "networks") ],
        [ "Virtual machine", 3, File.join(libvirt_dir, "qemu") ]
      ].each do |type, sortkey, dir|
        files = Dir.glob("#{dir}/*").select { |f| File.file?(f) && f.end_with?(".xml") }
        files.each do |file|
          content = IO.read(file)

          cfgfile = {
            "name"        => (name_from_xml(content) or "(#{File.basename(file)})"),
            "type"        => type,
            "sortkey"     => sortkey,
            "filename"    => file.delete_prefix(mount_point),
            "content"     => content,
            "permissions" => File.stat(file).mode,
            "from_device" => device,
            "from_os"     => os_name,
            "import"      => type == "Storage pool" ? false: true,
            "autostart"   => File.symlink?(autostart_link(file))
          }

          @cfgfiles << cfgfile
        end
      end

      log.info "#{@cfgfiles.count} config files found"
    end

    def write_cfgfiles(root_dir)
      log.info "Writing libvirt config files"

      @cfgfiles.each do |cfgfile|
        write_cfgfile(root_dir, cfgfile) if cfgfile["import"] && cfgfile["content"]
      end
    end

  protected

    def name_from_xml(content)
      xml = Nokogiri::XML(content)
      xml.at_xpath("//name").inner_text
    rescue NoMethodError, Nokogiri::XML::SyntaxError => e
      log.error "Error parsing:"
      log.error "#{content}"
      nil
    end

    def autostart_link(filename)
      File.join(File.dirname(filename), "autostart", File.basename(filename))
    end

    def write_cfgfile(root_dir, cfgfile)
      destname = File.join(root_dir, cfgfile["filename"])
      log.info "Writing file #{destname}..."

      FileUtils.mv(destname, "#{destname}.bak") if File.exist?(destname)
      FileUtils.mkdir_p(File.dirname(destname))
      IO.write(destname, cfgfile["content"])
      File.chmod(cfgfile["permissions"], destname) if cfgfile["permissions"]

      if cfgfile["autostart"]
        log.info "Symlinking #{destname} for autostart..."
        FileUtils.mkdir_p(File.dirname(autostart_link(destname)))
        File.symlink(cfgfile["filename"], autostart_link(destname))
      end
    end
  end
end
