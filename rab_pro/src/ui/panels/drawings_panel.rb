# ==============================================================================
# RAB Pro - Drawings Panel (Fase 3)
# Ruby-side callbacks for the Gambar Teknis tab in the main HtmlDialog.
# ==============================================================================

module RABPro
  module UI
    module Panels
      class DrawingsPanel

        def initialize(app_controller)
          @app      = app_controller
          @register = nil
        end

        # Register all Fase 3 callbacks onto an existing HtmlDialog
        def register_callbacks(dialog)
          @dlg = dialog

          _cb_get_scene_list
          _cb_create_scenes
          _cb_create_single_scene
          _cb_delete_rab_scenes
          _cb_auto_dimension
          _cb_generate_drawings
          _cb_export_scene_png
          _cb_export_dwg
          _cb_get_drawing_register
          _cb_add_drawing
          _cb_issue_revision
          _cb_update_status
          _cb_batch_export

          Logger.info('DrawingsPanel: Fase 3 callbacks registered')
        end

        private

        # -----------------------------------------------------------------------
        # Scene management callbacks
        # -----------------------------------------------------------------------

        def _cb_get_scene_list
          @dlg.add_action_callback('getSceneList') do |_, _|
            begin
              manager = Drawings::Scenes::SceneManager.new(Sketchup.active_model)
              existing = manager.existing_rab_scenes.map(&:name)
              _send('onSceneList', {
                definitions: Drawings::Scenes::SceneManager.scene_list,
                existing:    existing
              })
            rescue => e
              _send_error('getSceneList', e)
            end
          end
        end

        def _cb_create_scenes
          @dlg.add_action_callback('createScenes') do |_, payload|
            begin
              model    = Sketchup.active_model
              ids      = payload.is_a?(Array) ? payload.map(&:to_sym) : nil
              manager  = Drawings::Scenes::SceneManager.new(model)
              created  = manager.create_standard_scenes(scene_ids: ids)
              _send('onScenesCreated', { created: created, count: created.size })
            rescue => e
              _send_error('createScenes', e)
            end
          end
        end

        def _cb_create_single_scene
          @dlg.add_action_callback('createScene') do |_, scene_id|
            begin
              model   = Sketchup.active_model
              manager = Drawings::Scenes::SceneManager.new(model)
              page    = manager.create_scene(scene_id)
              _send('onSceneCreated', { name: page&.name, id: scene_id })
            rescue => e
              _send_error('createScene', e)
            end
          end
        end

        def _cb_delete_rab_scenes
          @dlg.add_action_callback('deleteRABScenes') do |_, _|
            begin
              manager = Drawings::Scenes::SceneManager.new(Sketchup.active_model)
              manager.delete_rab_scenes
              _send('onScenesDeleted', { ok: true })
            rescue => e
              _send_error('deleteRABScenes', e)
            end
          end
        end

        # -----------------------------------------------------------------------
        # Dimensioning callback
        # -----------------------------------------------------------------------

        def _cb_auto_dimension
          @dlg.add_action_callback('autoDimension') do |_, _|
            begin
              model = Sketchup.active_model
              dim   = Drawings::Annotations::AutoDimensioner.new(model)
              count = dim.auto_dimension_all
              _send('onAutoDimensionComplete', { count: count })
            rescue => e
              _send_error('autoDimension', e)
            end
          end
        end

        # -----------------------------------------------------------------------
        # Drawing generation callback
        # -----------------------------------------------------------------------

        def _cb_generate_drawings
          @dlg.add_action_callback('generateDrawings') do |_, payload|
            begin
              model    = Sketchup.active_model
              opts     = payload.is_a?(Hash) ? payload : {}
              ids      = opts['sheet_ids']&.map(&:to_sym)
              paper    = opts['paper_size'] || @app.settings.get('pdf_paper_size') || 'A3'

              default_name = _default_filename('gambar_teknis', 'pdf')
              path = UI.savepanel(
                'Simpan Gambar Teknis',
                @app.settings.export_path,
                default_name
              )
              next unless path

              layout = Drawings::Layout::LayoutAutomation.new(
                model,
                settings:      @app.settings,
                project_store: @app.project_store
              )

              result = layout.generate(path, sheet_ids: ids, paper_size: paper)
              _send('onDrawingsGenerated', result)

              # Open the file if successful
              if result[:success] && result[:path]
                ::UI.openURL("file:///#{result[:path].gsub('\\', '/')}")
              end
            rescue => e
              _send_error('generateDrawings', e)
            end
          end
        end

        # -----------------------------------------------------------------------
        # PNG export callback
        # -----------------------------------------------------------------------

        def _cb_export_scene_png
          @dlg.add_action_callback('exportScenePNG') do |_, payload|
            begin
              opts       = payload.is_a?(Hash) ? payload : { 'scene' => payload }
              scene_name = opts['scene']
              model      = Sketchup.active_model

              default = _default_filename(scene_name.to_s.downcase, 'png')
              path = ::UI.savepanel('Simpan Scene sebagai PNG', @app.settings.export_path, default)
              next unless path

              path += '.png' unless path.downcase.end_with?('.png')

              layout  = Drawings::Layout::LayoutAutomation.new(model, settings: @app.settings)
              success = layout.export_scene_png(scene_name, path,
                          width:  opts['width']&.to_i  || 3508,
                          height: opts['height']&.to_i || 2480)

              if success
                _send('onExportComplete', { format: 'png', path: path })
                ::UI.openURL("file:///#{path.gsub('\\', '/')}")
              else
                _send_error('exportScenePNG', StandardError.new('PNG export gagal'))
              end
            rescue => e
              _send_error('exportScenePNG', e)
            end
          end
        end

        # -----------------------------------------------------------------------
        # DWG export callback
        # -----------------------------------------------------------------------

        def _cb_export_dwg
          @dlg.add_action_callback('exportDWG') do |_, _|
            begin
              model   = Sketchup.active_model
              default = _default_filename('gambar', 'dwg')
              path    = ::UI.savepanel('Simpan sebagai DWG', @app.settings.export_path, default)
              next unless path

              path += '.dwg' unless path.downcase.end_with?('.dwg')

              exp    = Drawings::DrawingExportManager.new(model, settings: @app.settings,
                                                                  project_store: @app.project_store)
              result = exp.export_current_view_dwg(path)
              _send('onExportComplete', result)
            rescue => e
              _send_error('exportDWG', e)
            end
          end
        end

        # -----------------------------------------------------------------------
        # Drawing register callbacks
        # -----------------------------------------------------------------------

        def _cb_get_drawing_register
          @dlg.add_action_callback('getDrawingRegister') do |_, _|
            begin
              reg = _register
              _send('onDrawingRegister', {
                drawings:    reg.to_table,
                disciplines: Drawings::DrawingRegister::DISCIPLINES,
                statuses:    Drawings::DrawingRegister::STATUS_LABELS
              })
            rescue => e
              _send_error('getDrawingRegister', e)
            end
          end
        end

        def _cb_add_drawing
          @dlg.add_action_callback('addDrawing') do |_, payload|
            begin
              opts  = payload.is_a?(Hash) ? payload : {}
              entry = _register.add(
                title:      opts['title'] || 'Gambar Baru',
                discipline: (opts['discipline'] || 'architecture').to_sym,
                scale:      opts['scale'] || '1:100',
                scene_name: opts['scene_name']
              )
              _send('onDrawingAdded', { drawing_no: entry.drawing_no, title: entry.title })
            rescue => e
              _send_error('addDrawing', e)
            end
          end
        end

        def _cb_issue_revision
          @dlg.add_action_callback('issueRevision') do |_, payload|
            begin
              opts  = payload.is_a?(Hash) ? payload : {}
              entry = _register.issue_revision(
                opts['drawing_no'],
                description: opts['description'] || 'Revisi',
                issued_by:   opts['issued_by']   || 'RAB Pro',
                status:      (opts['status'] || 'issued_for_review').to_sym
              )
              _send('onRevisionIssued', {
                drawing_no: entry.drawing_no,
                revision:   entry.revision
              })
            rescue => e
              _send_error('issueRevision', e)
            end
          end
        end

        def _cb_update_status
          @dlg.add_action_callback('updateDrawingStatus') do |_, payload|
            begin
              opts = payload.is_a?(Hash) ? payload : {}
              _register.update_status(opts['drawing_no'], opts['status'])
              _send('onStatusUpdated', { drawing_no: opts['drawing_no'] })
            rescue => e
              _send_error('updateDrawingStatus', e)
            end
          end
        end

        # -----------------------------------------------------------------------
        # Batch export callback
        # -----------------------------------------------------------------------

        def _cb_batch_export
          @dlg.add_action_callback('batchExport') do |_, payload|
            begin
              model  = Sketchup.active_model
              opts   = payload.is_a?(Hash) ? payload : {}
              format = (opts['format'] || 'png').to_sym
              dir    = @app.settings.export_path

              exp    = Drawings::DrawingExportManager.new(model,
                         settings:      @app.settings,
                         project_store: @app.project_store)
              result = exp.batch_export_scenes(format: format, output_dir: dir)
              _send('onBatchExportComplete', result.merge(output_dir: dir))
            rescue => e
              _send_error('batchExport', e)
            end
          end
        end

        # -----------------------------------------------------------------------
        # Helpers
        # -----------------------------------------------------------------------

        def _register
          @register ||= Drawings::DrawingRegister.new(Sketchup.active_model)
        end

        def _send(event, data)
          require 'json'
          @dlg&.execute_script(
            "window.RABPro && window.RABPro.onRubyEvent('#{event}', #{JSON.generate(data)})"
          )
        rescue => e
          Logger.error("DrawingsPanel._send #{event}: #{e.message}")
        end

        def _send_error(source, error)
          Logger.error("DrawingsPanel #{source}: #{error.message}")
          _send('onError', { source: source, message: error.message })
        end

        def _default_filename(prefix, ext)
          pi   = @app.project_store&.project_info
          slug = (pi&.name || 'proyek').downcase.gsub(/[^a-z0-9]+/, '_')[0, 20]
          "#{prefix}_#{slug}_#{Time.now.strftime('%Y%m%d')}.#{ext}"
        end

      end
    end
  end
end
