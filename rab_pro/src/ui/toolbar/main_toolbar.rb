# ==============================================================================
# RAB Pro - Main Toolbar
# Creates the SketchUp toolbar with RAB Pro action buttons.
# Icons are loaded from resources/icons/ (16x16 and 24x24 PNG).
# ==============================================================================

module RABPro
  module UI
    module Toolbar
      class MainToolbar

        ICONS_PATH = File.join(RABPro::RESOURCES_PATH, 'icons').freeze

        def initialize(app_controller)
          @app = app_controller
          @tb  = nil
        end

        def build
          @tb = ::UI::Toolbar.new('RAB Pro')

          _add_button(
            name:    'Buka Panel RAB Pro',
            icon:    'rab_panel',
            tooltip: 'Buka Panel Utama RAB Pro (Ctrl+Shift+R)',
            status:  'Buka panel utama RAB Pro untuk inspeksi model dan estimasi biaya'
          ) { @app.toggle_main_panel }

          _add_separator

          _add_button(
            name:    'Auto-tag Model',
            icon:    'rab_tag',
            tooltip: 'Auto-tag semua entitas model dengan kategori pekerjaan',
            status:  'Deteksi dan beri kategori RAB pada semua komponen dan group secara otomatis'
          ) { @app.auto_tag_model }

          _add_separator

          _add_button(
            name:    'Inspeksi Model',
            icon:    'rab_inspect',
            tooltip: 'Baca dan analisis model aktif',
            status:  'Baca seluruh entitas model dan tampilkan di panel RAB Pro'
          ) { @app.main_panel&.refresh_model_context(Sketchup.active_model) }

          _add_button(
            name:    'Pengaturan RAB Pro',
            icon:    'rab_settings',
            tooltip: 'Buka pengaturan RAB Pro',
            status:  'Konfigurasi harga satuan, mata uang, dan preferensi export'
          ) { @app.open_settings }

          # Show toolbar by default (persists via SketchUp prefs)
          @tb.show if @tb.get_last_state == -1  # -1 = never shown before
        end

        def show; @tb&.show end
        def hide; @tb&.hide end

        private

        def _add_button(name:, icon:, tooltip:, status:, &block)
          # ✅ Buat Command object dulu
          cmd = ::UI::Command.new(name) { block.call }
        
          # Load icon files
          icon_small = File.join(ICONS_PATH, "#{icon}_16.png")
          icon_large = File.join(ICONS_PATH, "#{icon}_24.png")
        
          if File.exist?(icon_small) && File.exist?(icon_large)
            cmd.small_icon = icon_small
            cmd.large_icon = icon_large
          elsif File.exist?(icon_small)
            cmd.small_icon = icon_small
            cmd.large_icon = icon_small
          end
        
          cmd.tooltip         = tooltip
          cmd.status_bar_text = status
        
          # ✅ Pass Command object ke toolbar
          @tb.add_item(cmd)
        
          cmd
        end

        def _add_separator
          @tb.add_separator
        end

      end
    end
  end
end
