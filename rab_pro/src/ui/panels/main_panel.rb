# ==============================================================================
# RAB Pro - Main Panel (HtmlDialog SPA)
# ==============================================================================

module RABPro
  module UI
    module Panels
      class MainPanel

        # Compute HTML path relative to THIS file's location
        # __FILE__ = .../rab_pro/src/ui/panels/main_panel.rb
        # HTML is at  .../rab_pro/resources/templates/main_panel.html
        PANEL_HTML = File.expand_path(
          File.join(File.dirname(__FILE__), '..', '..', '..', 'resources', 'templates', 'main_panel.html')
        ).freeze

        def initialize(app_controller)
          @app = app_controller
          @dlg = nil
        end

        def show
          _build_dialog unless @dlg
          _setup_callbacks
          @dlg.show
          _push_initial_data
        end

        def close
          @dlg&.close
        end

        def visible?
          @dlg&.visible? || false
        end

        def refresh_model_context(model)
          return unless visible?
          data = @app.inspect_current_model
          _send_to_js('onModelChanged', data)
        end

        private

        def _build_dialog
          geo = @app.settings.panel_geometry

          @dlg = ::UI::HtmlDialog.new(
            dialog_title:    'RAB Pro',
            preferences_key: 'RABPro_MainPanel',
            style:           ::UI::HtmlDialog::STYLE_UTILITY,
            width:           geo[:width],
            height:          geo[:height],
            left:            geo[:x],
            top:             geo[:y],
            min_width:       420,
            min_height:      500
          )

          if File.exist?(PANEL_HTML)
            Logger.info("MainPanel: loading HTML from #{PANEL_HTML}")
            @dlg.set_file(PANEL_HTML)
          else
            Logger.error("MainPanel: HTML not found at #{PANEL_HTML}")
            @dlg.set_html(_fallback_html)
          end

          @dlg.add_action_callback('onPanelClose') do |_, pos|
            _save_panel_geometry(pos) if pos.is_a?(Hash)
          end
        end

        def _setup_callbacks
          # --- Inspector ---
          @dlg.add_action_callback('inspectModel') do |_, _|
            begin
              _send_to_js('onInspectResult', @app.inspect_current_model)
            rescue => e
              _send_error('inspectModel', e)
            end
          end

          # --- Tagger ---
          @dlg.add_action_callback('autoTagModel') do |_, _|
            begin
              _send_to_js('onAutoTagComplete', @app.auto_tag_model)
            rescue => e
              _send_error('autoTagModel', e)
            end
          end

          @dlg.add_action_callback('tagEntity') do |_, payload|
            begin
              entity_id = payload['entity_id'].to_i
              category  = payload['category'].to_sym
              entity    = Sketchup.active_model.find_entity_by_id(entity_id)
              raise "Entity #{entity_id} not found" unless entity
              Core::Tagger::AutoTagger.new(Sketchup.active_model).tag_entity(entity, category)
              _send_to_js('onTagEntityComplete', { entity_id: entity_id, category: category })
            rescue => e
              _send_error('tagEntity', e)
            end
          end

          # --- Settings ---
          @dlg.add_action_callback('getSettings') do |_, _|
            _send_to_js('onSettingsLoaded', @app.settings.to_hash)
          end

          @dlg.add_action_callback('saveSettings') do |_, payload|
            begin
              @app.settings.from_hash(payload)
              _send_to_js('onSettingsSaved', { ok: true })
            rescue => e
              _send_error('saveSettings', e)
            end
          end

          # --- Category library ---
          @dlg.add_action_callback('getCategoryLibrary') do |_, _|
            _send_to_js('onCategoryLibraryLoaded', {
              categories: Data::CategoryLibrary.to_json_array,
              groups:     Data::CategoryLibrary.groups
            })
          end

          # --- Entity selection ---
          @dlg.add_action_callback('selectEntity') do |_, entity_id|
            begin
              model  = Sketchup.active_model
              entity = model.find_entity_by_id(entity_id.to_i)
              if entity
                model.selection.clear
                model.selection.add(entity)
              end
            rescue => e
              Logger.error("selectEntity: #{e.message}")
            end
          end

          @dlg.add_action_callback('zoomToEntity') do |_, entity_id|
            begin
              model  = Sketchup.active_model
              entity = model.find_entity_by_id(entity_id.to_i)
              if entity
                model.selection.clear
                model.selection.add(entity)
                model.active_view.zoom(model.selection)
              end
            rescue => e
              Logger.error("zoomToEntity: #{e.message}")
            end
          end

          # --- Register Fase 2, 3, 4 panels ---
          _register_fase2_callbacks
          _register_fase3_callbacks
          _register_fase4_callbacks
        end

        def _register_fase2_callbacks
          rab_panel = Panels::RABPanel.new(@app)
          rab_panel.register_callbacks(@dlg)
        rescue => e
          Logger.error("Fase2 callbacks: #{e.message}")
        end

        def _register_fase3_callbacks
          drawings_panel = Panels::DrawingsPanel.new(@app)
          drawings_panel.register_callbacks(@dlg)
        rescue => e
          Logger.error("Fase3 callbacks: #{e.message}")
        end

        def _register_fase4_callbacks
          fase4_panel = Panels::Fase4Panel.new(@app)
          fase4_panel.register_callbacks(@dlg)
        rescue => e
          Logger.error("Fase4 callbacks: #{e.message}")
        end

        def _push_initial_data
          ::UI.start_timer(0.5, false) do
            begin
              # Use lightweight summary only — full read_all triggered by user click
              model   = Sketchup.active_model
              reader  = Core::Inspector::EntityReader.new(model)
              summary = reader.summary
              tag_stats = Core::Tagger::TagEngine.stats(model) rescue {}

              settings   = @app.settings.to_hash
              categories = Data::CategoryLibrary.to_json_array

              _send_to_js('onInit', {
                model: {
                  summary:   summary,
                  entities:  [],   # empty — user clicks "Baca Model" to load
                  tag_stats: tag_stats
                },
                settings:   settings,
                categories: categories,
                version:    EXTENSION_VERSION
              })
            rescue => e
              Logger.error("_push_initial_data: #{e.message}")
            end
          end
        end

        def _send_to_js(event, data)
          require 'json'
          json = JSON.generate(data)
          @dlg&.execute_script("window.RABPro && window.RABPro.onRubyEvent('#{event}', #{json})")
        rescue => e
          Logger.error("_send_to_js #{event}: #{e.message}")
        end

        def _send_error(source, error)
          Logger.error("#{source}: #{error.message}")
          _send_to_js('onError', { source: source, message: error.message })
        end

        def _save_panel_geometry(pos)
          @app.settings.set('panel_x',      pos['x'])    if pos['x']
          @app.settings.set('panel_y',      pos['y'])    if pos['y']
          @app.settings.set('panel_width',  pos['width'])  if pos['width']
          @app.settings.set('panel_height', pos['height']) if pos['height']
        end

        def _fallback_html
          <<~HTML
            <!DOCTYPE html><html lang="id"><head><meta charset="UTF-8">
            <style>body{font-family:-apple-system,sans-serif;display:flex;align-items:center;
            justify-content:center;height:100vh;margin:0;background:#f5f5f5;}
            .box{text-align:center;color:#555;padding:20px;}
            .path{font-size:10px;color:#999;margin-top:8px;word-break:break-all;}
            </style></head><body>
            <div class="box">
              <h2 style="color:#0071e3">RAB Pro</h2>
              <p>HTML panel tidak ditemukan.</p>
              <p class="path">Expected: #{PANEL_HTML}</p>
            </div></body></html>
          HTML
        end

      end
    end
  end
end
