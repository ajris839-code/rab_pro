# ==============================================================================
# RAB Pro - Application Controller (v4 COMPLETE)
# ==============================================================================

require 'singleton'

module RABPro
  class AppController
    include Singleton

    attr_reader :toolbar, :main_panel, :settings, :project_store

    def boot!
      Logger.info('AppController#boot! v4')
      @settings      = SettingsManager.new
      @project_store = ProjectStore.new(@settings)
      _build_toolbar
      _register_menu_items
      _register_model_observers
      Logger.info('AppController#boot! complete')
    rescue => e
      Logger.error("Boot failed: #{e.message}")
      ::UI.messagebox("RAB Pro failed to load:\n#{e.message}", MB_OK)
    end

    def toggle_main_panel
      if @main_panel&.visible?
        @main_panel.close
      else
        @main_panel ||= UI::Panels::MainPanel.new(self)
        @main_panel.show
      end
    end

    def on_model_changed(model)
      Logger.info("Model changed: #{model.path}")
      @project_store.attach(model)
      @main_panel&.refresh_model_context(model)
    end

    def inspect_current_model
      model = Sketchup.active_model
      return nil unless model
      reader   = Core::Inspector::EntityReader.new(model)
      analyzer = Core::Inspector::GeometryAnalyzer.new
      tree     = Core::Inspector::ComponentTree.new(model)
      {
        summary:   reader.summary,
        entities:  reader.read_all,
        geometry:  analyzer.analyze(model.entities),
        tree:      tree.build,
        layers:    _read_layers(model),
        materials: _read_materials(model),
        timestamp: Time.now.iso8601
      }
    end

    def auto_tag_model
      model = Sketchup.active_model
      return unless model
      model.start_operation('RAB Pro: Auto-tag', true)
      result = Core::Tagger::AutoTagger.new(model).run
      model.commit_operation
      result
    rescue => e
      model&.abort_operation
      raise
    end

    def open_settings
      @settings_dialog ||= UI::Dialogs::SettingsDialog.new(@settings)
      @settings_dialog.show
    end

    def open_category_editor
      @cat_editor ||= UI::Dialogs::CategoryEditorDialog.new(@settings)
      @cat_editor.show
    end

    private

    def _build_toolbar
      @toolbar = UI::Toolbar::MainToolbar.new(self)
      @toolbar.build
    end

    def _register_menu_items
      ext_menu = ::UI.menu('Extensions')
      rab_menu = ext_menu.add_submenu('RAB Pro')
      rab_menu.add_item('Buka Panel Utama')    { toggle_main_panel }
      rab_menu.add_item('Auto-tag Model')      { auto_tag_model }
      rab_menu.add_separator
      rab_menu.add_item('Library Kategori...') { open_category_editor }
      rab_menu.add_item('Pengaturan...')       { open_settings }
      rab_menu.add_separator
      rab_menu.add_item('Test Fase 1') { _run_tests('phase1', Tests::Phase1) }
      rab_menu.add_item('Test Fase 2') { _run_tests('phase2', Tests::Phase2) }
      rab_menu.add_item('Test Fase 3') { _run_tests('phase3', Tests::Phase3) }
      rab_menu.add_item('Test Fase 4') { _run_tests('phase4', Tests::Phase4) }
      rab_menu.add_separator
      rab_menu.add_item('Tentang RAB Pro') { _show_about }
    end

    def _register_model_observers
      Sketchup.add_observer(AppObserver.new(self))
    end

    def _read_layers(model)
      model.layers.map { |l| { name: l.name, visible: l.visible? } }
    end

    def _read_materials(model)
      model.materials.map { |m| { name: m.name, display_name: m.display_name } }
    end

    def _run_tests(name, klass)
      require File.join(RABPro::EXTENSION_ROOT, 'tests', "test_#{name}.rb")
      result = klass.run
      ::UI.messagebox("#{name}: #{result[:passed]} passed, #{result[:failed]} failed", MB_OK)
    rescue => e
      ::UI.messagebox("Test error: #{e.message}", MB_OK)
    end

    def _show_about
      ::UI.messagebox(
        "RAB Pro v#{EXTENSION_VERSION}\n\nExtension profesional untuk:\n" \
        "• RAB & Quantity Takeoff\n• Gambar Teknis Otomatis\n" \
        "• AI Assistant (Claude)\n• Dashboard & Kolaborasi\n\n" \
        "© #{Time.now.year} #{EXTENSION_AUTHOR}",
        MB_OK
      )
    end
  end

  class AppObserver < Sketchup::AppObserver
    def initialize(c); @c = c end
    def onNewModel(m);      @c.on_model_changed(m) end
    def onOpenModel(m);     @c.on_model_changed(m) end
    def onActivateModel(m); @c.on_model_changed(m) end
  end
end
