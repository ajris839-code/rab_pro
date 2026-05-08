# ==============================================================================
# RAB Pro - Fase 4 Panel
# Ruby-side callbacks for:
#   - AI Chat (full conversation with model context)
#   - Project Dashboard (progress, milestones, S-curve)
#   - Project Templates (apply, preview)
#   - Cloud Sync (snapshots, JSON export/import, share report, comments)
# ==============================================================================

module RABPro
  module UI
    module Panels
      class Fase4Panel

        def initialize(app_controller)
          @app      = app_controller
          @chat_mgr = nil
          @dashboard = nil
          @sync     = nil
        end

        def register_callbacks(dialog)
          @dlg = dialog
          _register_ai_callbacks
          _register_dashboard_callbacks
          _register_template_callbacks
          _register_sync_callbacks
          Logger.info('Fase4Panel: all Fase 4 callbacks registered')
        end

        private

        # ======================================================================
        # AI CHAT CALLBACKS
        # ======================================================================

        def _register_ai_callbacks
          # Send chat message
          @dlg.add_action_callback('aiChat') do |_, payload|
            begin
              opts    = payload.is_a?(Hash) ? payload : { 'message' => payload.to_s }
              message = opts['message'].to_s.strip
              raise 'Pesan kosong' if message.empty?

              mgr    = _chat_manager
              result = mgr.send(
                message,
                include_model_context: opts.fetch('include_model', true),
                include_rab_context:   opts.fetch('include_rab', false)
              )

              _send('onAIChatResponse', result)
            rescue => e
              _send_error('aiChat', e)
            end
          end

          # Get chat history
          @dlg.add_action_callback('getChatHistory') do |_, _|
            _send('onChatHistory', { messages: _chat_manager.history })
          end

          # Clear chat history
          @dlg.add_action_callback('clearChatHistory') do |_, _|
            _chat_manager.clear_history
            _send('onChatHistoryCleared', {})
          end

          # Parse natural language model command
          @dlg.add_action_callback('parseModelCommand') do |_, text|
            begin
              result = _chat_manager.parse_model_command(text.to_s)
              _send('onCommandParsed', result || { 'action' => 'none', 'explanation' => 'Tidak dapat memproses perintah' })
            rescue => e
              _send_error('parseModelCommand', e)
            end
          end

          # Save API key
          @dlg.add_action_callback('saveApiKey') do |_, key|
            begin
              Sketchup.write_default('RABPro', 'api_key', key.to_s.strip)
              @chat_mgr = nil  # force reinit with new key
              _send('onApiKeySaved', { ok: true })
            rescue => e
              _send_error('saveApiKey', e)
            end
          end

          # Test API key
          @dlg.add_action_callback('testApiKey') do |_, _|
            begin
              mgr    = _chat_manager
              result = mgr.query('Halo, ini test koneksi. Jawab singkat saja.')
              ok     = result[:success]
              _send('onApiKeyTest', { ok: ok, message: ok ? 'Koneksi berhasil ✓' : result[:error] })
            rescue => e
              _send('onApiKeyTest', { ok: false, message: e.message })
            end
          end

          # Get context summary (for display)
          @dlg.add_action_callback('getAIContext') do |_, _|
            begin
              summary = _chat_manager.build_model_context_summary
              _send('onAIContext', { summary: summary, history_count: _chat_manager.history_count })
            rescue => e
              _send_error('getAIContext', e)
            end
          end
        end

        # ======================================================================
        # DASHBOARD CALLBACKS
        # ======================================================================

        def _register_dashboard_callbacks
          # Get full dashboard snapshot
          @dlg.add_action_callback('getDashboard') do |_, _|
            begin
              snap = _dashboard.snapshot
              _send('onDashboard', snap)
            rescue => e
              _send_error('getDashboard', e)
            end
          end

          # Initialize progress from RAB
          @dlg.add_action_callback('initProgress') do |_, _|
            begin
              _dashboard.initialize_progress_from_rab
              _send('onProgressInitialized', { ok: true })
            rescue => e
              _send_error('initProgress', e)
            end
          end

          # Update single category progress
          @dlg.add_action_callback('updateProgress') do |_, payload|
            begin
              opts = payload.is_a?(Hash) ? payload : {}
              entry = _dashboard.update_progress(
                opts['category_id'],
                actual_qty:   opts['actual_qty'].to_f,
                actual_cost:  opts['actual_cost'].to_f,
                pct_complete: opts['pct_complete'].to_f
              )
              _send('onProgressUpdated', { category_id: opts['category_id'], entry: entry.to_h })
            rescue => e
              _send_error('updateProgress', e)
            end
          end

          # Update milestone
          @dlg.add_action_callback('updateMilestone') do |_, payload|
            begin
              opts = payload.is_a?(Hash) ? payload : {}
              ms   = _dashboard.update_milestone(
                opts['id'],
                actual_date: opts['actual_date'],
                status:      opts['status']
              )
              _send('onMilestoneUpdated', ms&.to_h || {})
            rescue => e
              _send_error('updateMilestone', e)
            end
          end

          # Save milestones batch
          @dlg.add_action_callback('saveMilestones') do |_, payload|
            begin
              milestones = payload.is_a?(Array) ? payload : []
              _dashboard.save_milestones(milestones)
              _send('onMilestonesSaved', { count: milestones.size })
            rescue => e
              _send_error('saveMilestones', e)
            end
          end
        end

        # ======================================================================
        # TEMPLATE CALLBACKS
        # ======================================================================

        def _register_template_callbacks
          # Get all templates
          @dlg.add_action_callback('getTemplates') do |_, _|
            _send('onTemplates', { templates: Templates::TemplateEngine.to_json_array })
          end

          # Preview template (get info without applying)
          @dlg.add_action_callback('previewTemplate') do |_, template_id|
            begin
              tmpl = Templates::TemplateEngine.find(template_id.to_sym)
              raise "Template tidak ditemukan: #{template_id}" unless tmpl
              _send('onTemplatePreview', {
                id:              tmpl.id,
                name:            tmpl.name,
                description:     tmpl.description,
                icon:            tmpl.icon,
                typical_area_m2: tmpl.typical_area_m2,
                notes:           tmpl.notes,
                layer_count:     tmpl.layers.size,
                category_count:  tmpl.rab_categories.size,
                scene_count:     tmpl.default_scenes.size,
                layers:          tmpl.layers,
                categories:      tmpl.rab_categories.keys.map do |k|
                  cat = Data::CategoryLibrary.find(k)
                  { id: k, name: cat&.name || k.to_s, unit: cat&.unit || '-' }
                end
              })
            rescue => e
              _send_error('previewTemplate', e)
            end
          end

          # Apply template to model
          @dlg.add_action_callback('applyTemplate') do |_, template_id|
            begin
              model  = Sketchup.active_model
              result = Templates::TemplateEngine.apply(
                model,
                template_id.to_sym,
                project_store: @app.project_store,
                settings:      @app.settings
              )
              _send('onTemplateApplied', result)
            rescue => e
              _send_error('applyTemplate', e)
            end
          end
        end

        # ======================================================================
        # CLOUD SYNC CALLBACKS
        # ======================================================================

        def _register_sync_callbacks
          # Create snapshot
          @dlg.add_action_callback('createSnapshot') do |_, payload|
            begin
              opts  = payload.is_a?(Hash) ? payload : {}
              snap  = _sync.create_snapshot(
                label:      opts['label'],
                created_by: opts['created_by'] || 'RAB Pro User'
              )
              _send('onSnapshotCreated', { id: snap.id, label: snap.label, created_at: snap.created_at })
            rescue => e
              _send_error('createSnapshot', e)
            end
          end

          # Get snapshots list
          @dlg.add_action_callback('getSnapshots') do |_, _|
            snaps = _sync.load_snapshots.map do |s|
              { id: s.id, label: s.label, created_at: s.created_at,
                rab_total: s.rab_total, progress_pct: s.progress_pct }
            end
            _send('onSnapshots', { snapshots: snaps })
          end

          # Export JSON
          @dlg.add_action_callback('exportJSON') do |_, _|
            begin
              default = "rab_pro_#{Time.now.strftime('%Y%m%d')}.json"
              path = ::UI.savepanel('Export Proyek sebagai JSON', @app.settings.export_path, default)
              next unless path
              path += '.json' unless path.downcase.end_with?('.json')
              result = _sync.export_json(path)
              _send('onExportComplete', result)
              ::UI.openURL("file:///#{File.dirname(path).gsub('\\', '/')}")
            rescue => e
              _send_error('exportJSON', e)
            end
          end

          # Import JSON
          @dlg.add_action_callback('importJSON') do |_, _|
            begin
              path = ::UI.openpanel('Import Proyek dari JSON', @app.settings.export_path, '*.json')
              next unless path
              result = _sync.import_json(path)
              _send('onImportComplete', result)
            rescue => e
              _send_error('importJSON', e)
            end
          end

          # Generate share report
          @dlg.add_action_callback('generateShareReport') do |_, _|
            begin
              pi      = @app.project_store&.project_info&.to_h || {}
              slug    = (pi[:name] || 'proyek').downcase.gsub(/[^a-z0-9]+/, '_')[0, 20]
              default = "laporan_#{slug}_#{Time.now.strftime('%Y%m%d')}.html"
              path    = ::UI.savepanel('Simpan Laporan HTML', @app.settings.export_path, default)
              next unless path
              path += '.html' unless path.downcase.end_with?('.html')
              result = _sync.generate_share_report(path)
              _send('onShareReportGenerated', result)
              ::UI.openURL("file:///#{path.gsub('\\', '/')}") if result[:success]
            rescue => e
              _send_error('generateShareReport', e)
            end
          end

          # Add comment
          @dlg.add_action_callback('addComment') do |_, payload|
            begin
              opts = payload.is_a?(Hash) ? payload : {}
              cmt  = _sync.add_comment(
                author:    opts['author'] || 'Pengguna',
                text:      opts['text'].to_s,
                category:  opts['category'],
                entity_id: opts['entity_id']
              )
              _send('onCommentAdded', cmt.to_h)
            rescue => e
              _send_error('addComment', e)
            end
          end

          # Get comments
          @dlg.add_action_callback('getComments') do |_, _|
            cmts = _sync.load_comments.map(&:to_h)
            _send('onComments', { comments: cmts })
          end

          # Resolve comment
          @dlg.add_action_callback('resolveComment') do |_, comment_id|
            _sync.resolve_comment(comment_id.to_s)
            _send('onCommentResolved', { id: comment_id })
          end
        end

        # ======================================================================
        # Helpers
        # ======================================================================

        def _chat_manager
          @chat_mgr ||= AI::Chat::ChatManager.new(
            Sketchup.active_model,
            settings:      @app.settings,
            project_store: @app.project_store
          )
        end

        def _dashboard
          @dashboard ||= Dashboard::ProjectDashboard.new(
            Sketchup.active_model,
            project_store: @app.project_store
          )
        end

        def _sync
          @sync ||= Collaboration::CloudSync.new(
            Sketchup.active_model,
            project_store: @app.project_store,
            settings:      @app.settings
          )
        end

        def _send(event, data)
          require 'json'
          @dlg&.execute_script(
            "window.RABPro && window.RABPro.onRubyEvent('#{event}', #{JSON.generate(data)})"
          )
        rescue => e
          Logger.error("Fase4Panel._send #{event}: #{e.message}")
        end

        def _send_error(source, error)
          Logger.error("Fase4Panel #{source}: #{error.message}")
          _send('onError', { source: source, message: error.message })
        end

      end
    end
  end
end
