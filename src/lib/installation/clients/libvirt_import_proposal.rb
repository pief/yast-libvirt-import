require "installation/proposal_client"
require "installation/libvirt_importer"
require "ui/installation_dialog"

module Yast
  class LibvirtImportProposalClient < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "Ops"
      Yast.import "UI"
      textdomain "installation"
    end

  protected

    def importer
      ::Installation::LibvirtImporter.instance
    end

    def description
      {
        "rich_text_title" => "Import libvirt configuration files",
        "menu_title"      => _("Import &libvirt configuration files"),
        "id"              => "libvirt_import"
      }
    end

    def make_proposal(attrs)
      {
        "preformatted_proposal" => preformatted_proposal
      }
    end

    def count_enabled_for(list, device, type)
        list.select { |cfgfile| cfgfile["import"] && cfgfile["from_device"] == device && cfgfile["type"] == type }.count
    end

    def preformatted_proposal
      if importer.cfgfiles.empty?
        _("No previous Linux installation found")
      else
        lines = []
        importer.cfgfiles.map { |cfgfile| [cfgfile["from_device"], cfgfile["from_os"]] }.uniq.each do |device, os|
          num_storage_pools = count_enabled_for(importer.cfgfiles, device, "Storage pool")
          num_virtual_networks = count_enabled_for(importer.cfgfiles, device, "Virtual network")
          num_virtual_machines = count_enabled_for(importer.cfgfiles, device, "Virtual machine")

          line_parts = []
          line_parts << "#{num_storage_pools} storage pool#{num_storage_pools == 1 ? '' : 's'}" if num_storage_pools > 0
          line_parts << "#{num_virtual_networks} virtual network#{num_virtual_networks == 1 ? '' : 's'}" if num_virtual_networks > 0
          line_parts << "#{num_virtual_machines} virtual machine#{num_virtual_machines == 1 ? '' : 's'}" if num_virtual_machines > 0
          if line_parts.count > 0
            lines << _(
              "Import #{line_parts.join(', ')} from installation on #{device} (#{os}) "
            )
          else
            lines << _(
              "Nothing to import from installation on #{device} (#{os}) "
            )
          end
        end
        HTML.List(lines)
      end
    end

    class LibvirtImportDialog < ::UI::InstallationDialog
      def initialize
        super
        textdomain "installation"

        @initial_table_items = []
        importer.cfgfiles.sort_by { |cfgfile| [ cfgfile["from_device"], cfgfile["sortkey"], cfgfile["name"] ] }.each.with_index(1) do |cfgfile, index|
          @initial_table_items << Item(
            Id(index),
            cfgfile["import"] ? UI.Glyph(:CheckMark) : "",
            cfgfile["autostart"] ? UI.Glyph(:CheckMark) : "",
            cfgfile["name"],
            cfgfile["type"],
            "#{cfgfile['from_device']} (#{cfgfile['from_os']})",
            cfgfile["from_device"],
            cfgfile["filename"],
          )
        end

        @prev_selected = nil
      end

      def table_handler
        row_id = Convert.to_integer(Yast::UI.QueryWidget(Id(:table), :CurrentItem))
        if row_id != @prev_selected
          @prev_selected = row_id
        else
          import_checkmark = UI.QueryWidget(Id(:table), Cell(row_id, 0))
          import_checkmark == UI.Glyph(:CheckMark) ? import_checkmark = "" : import_checkmark = UI.Glyph(:CheckMark)
          UI.ChangeWidget(Id(:table), Cell(row_id, 0), import_checkmark)
        end
        update_checkboxes_for(row_id)
      end

      def import_handler
        log.error "import_handler"
        import_checkbox = Convert.to_boolean(UI.QueryWidget(Id(:import), :Value))
        row_id = Convert.to_integer(Yast::UI.QueryWidget(Id(:table), :CurrentItem))
        UI.ChangeWidget(Id(:table), Cell(row_id, 0), import_checkbox ? UI.Glyph(:CheckMark) : "")    
      end

      def autostart_handler
        log.error "autostart_handler"
        autostart_checkbox = Convert.to_boolean(UI.QueryWidget(Id(:autostart), :Value))
        row_id = Convert.to_integer(Yast::UI.QueryWidget(Id(:table), :CurrentItem))
        UI.ChangeWidget(Id(:table), Cell(row_id, 1), autostart_checkbox ? UI.Glyph(:CheckMark) : "")    
      end

      def accept_handler
        final_table_items = Yast::UI.QueryWidget(Id(:table), :Items)
        final_table_items.each do |table_item|
          import_checkmark = table_item.params[1]
          autostart_checkmark = table_item.params[2]
          from_device = table_item.params[6]
          filename = table_item.params[7]

          importer.cfgfiles.select { |cfgfile| cfgfile["from_device"] == from_device && cfgfile["filename"] == filename }.each do |cfgfile|
            cfgfile["import"] = import_checkmark == UI.Glyph(:CheckMark) ? true : false
            cfgfile["autostart"] = autostart_checkmark == UI.Glyph(:CheckMark) ? true : false
          end
        end

        super
      end

    private
      def importer
        ::Installation::LibvirtImporter.instance
      end

      def create_dialog
        super
        update_checkboxes_for(1)
      end

      def dialog_content
        label = _("Import libvirt configuration files")
        VBox(
          Label(_("Select the configuration files to be imported:")),
          VSpacing(0.3),
          Table(
            Id(:table),
            Opt(:notify, :immediate, :keepSorting),
            Header(
              Center(_("Import")),
              Center(_("Autostart")),
              _("Configuration file"),
              _("Type"),
              _("Source")
            ),
            @initial_table_items
          ),
          Left(
            HBox(
              HSpacing(0.5),
              CheckBox(Id(:import), Opt(:notify), _("&Import"), false),
              HSpacing(0.5),
              CheckBox(Id(:autostart), Opt(:notify), _("&Autostart"), false)
            )
          )
        )
      end

      def dialog_title
        _("Import libvirt configuration files")
      end

      def help_text
        _(
          "<p>If you're reinstalling a libvirt virtual machine (VM) host  " \
          "you may want to keep the existing virtual machine, virtual network and " \
          "storage pool definitions. You can select their configuration files here " \
          "and also whether you want to keep or change their automatic starting on " \
          "bootup.</p>" \
          "<p>Virtual disk storage itself, i.e. image files, will not be preserved since " \
          "they are expected to reside on storage that does not get formatted during the " \
          "new installation.</p>" \
          "<p>Also note that you will still have to install libvirtd itself.</p>"
        )
      end

      def update_checkboxes_for(row_id)
        import_checkmark = Convert.to_string(UI.QueryWidget(:table, Cell(row_id, 0)))
        UI.ChangeWidget(Id(:import), :Value, import_checkmark == UI.Glyph(:CheckMark))

        autostart_checkmark = Convert.to_string(UI.QueryWidget(:table, Cell(row_id, 1)))
        UI.ChangeWidget(Id(:autostart), :Value, autostart_checkmark == UI.Glyph(:CheckMark))
      end
    end

    def ask_user(param)
      args = {
        "enable_back" => true,
        "enable_next" => false,
        "going_back"  => true
      }

      begin
        Yast::Wizard.OpenAcceptDialog
        result = LibvirtImportDialog.new.run
      ensure
        Yast::Wizard.CloseDialog
      end

      { "workflow_sequence" => result }
    end
  end
end
