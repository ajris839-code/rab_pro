# ==============================================================================
# RAB Pro - RAB Panel (Fase 2) — Fixed
# ==============================================================================

module RABPro
  module UI
    module Panels
      class RABPanel

        def initialize(app_controller)
          @app          = app_controller
          @last_rab_doc = nil
        end

        def register_callbacks(dialog)
          @dlg = dialog
          _cb_save_project_info
          _cb_get_financial_settings
          _cb_save_financial_settings
          _cb_run_qto
          _cb_build_rab
          _cb_export_excel
          _cb_export_pdf
          _cb_get_harga_satuan
          _cb_update_price
          _cb_set_quantity_override
          _cb_ai_analyze_rab
          _cb_ai_suggest_alternatives
          _cb_ai_detect_anomalies
          Logger.info('RABPanel: callbacks registered')
        end

        private

        # ---- Project info --------------------------------------------------
        def _cb_save_project_info
          @dlg.add_action_callback('saveProjectInfo') do |_, payload|
            begin
              data = _parse_payload(payload)
              info = {}
              info[:name]        = data['name'].to_s
              info[:owner]       = data['owner'].to_s
              info[:location]    = data['location'].to_s
              info[:consultant]  = data['consultant'].to_s
              info[:contractor]  = data['contractor'].to_s
              info[:start_date]  = data['start_date'].to_s
              info[:end_date]    = data['end_date'].to_s
              info[:description] = data['description'].to_s
              @app.project_store.save_project_info(info)
              _send('onProjectInfoSaved', { ok: true, message: 'Info proyek disimpan' })
            rescue => e
              _send_error('saveProjectInfo', e)
            end
          end
        end

        # ---- Financial settings --------------------------------------------
        def _cb_get_financial_settings
          @dlg.add_action_callback('getFinancialSettings') do |_, _|
            begin
              ps = @app.project_store
              _send('onFinancialSettings', {
                overhead_pct: ps.overhead_pct,
                profit_pct:   ps.profit_pct,
                ppn_pct:      ps.ppn_pct,
                currency:     @app.settings.currency,
                symbol:       @app.settings.currency_symbol
              })
            rescue => e
              _send_error('getFinancialSettings', e)
            end
          end
        end

        def _cb_save_financial_settings
          @dlg.add_action_callback('saveFinancialSettings') do |_, payload|
            begin
              data = _parse_payload(payload)
              @app.project_store.save_financial_settings(
                overhead: data['overhead_pct'].to_f,
                profit:   data['profit_pct'].to_f,
                ppn:      data['ppn_pct'].to_f
              )
              _send('onFinancialSettingsSaved', { ok: true })
            rescue => e
              _send_error('saveFinancialSettings', e)
            end
          end
        end

        # ---- QTO -----------------------------------------------------------
        def _cb_run_qto
          @dlg.add_action_callback('runQTO') do |_, _|
            begin
              model = Sketchup.active_model
              raise 'Tidak ada model aktif' unless model

              engine = RAB::QuantityTakeoffEngine.new(
                model,
                settings:      @app.settings,
                project_store: @app.project_store
              )
              result = engine.run

              # Safely serialize — avoid nested Struct issues
              items_arr = (result[:items] || []).map { |item| _serialize_qto_item(item) }
              summary_h = {}
              (result[:summary] || {}).each do |k, sum|
                summary_h[k.to_s] = _serialize_qto_summary(sum)
              end

              _send('onQTOComplete', {
                items:   items_arr,
                summary: summary_h,
                stats:   result[:stats] || {}
              })
            rescue => e
              _send_error('runQTO', e)
            end
          end
        end

        # ---- RAB Build -----------------------------------------------------
        def _cb_build_rab
          @dlg.add_action_callback('buildRAB') do |_, payload|
            begin
              model = Sketchup.active_model
              raise 'Tidak ada model aktif' unless model

              opts = _parse_payload(payload)
              calc = RAB::RABCalculator.new(
                model,
                project_store: @app.project_store,
                settings:      @app.settings
              )
              doc = calc.generate(
                overhead_pct: opts['overhead_pct']&.to_f,
                profit_pct:   opts['profit_pct']&.to_f,
                ppn_pct:      opts['ppn_pct']&.to_f
              )
              @last_rab_doc = doc

              # Serialize the document safely
              doc_hash = _serialize_rab_doc(doc)
              _send('onRABComplete', doc_hash)

              # Cache rab lines for dashboard
              _cache_rab_lines(doc, model)
            rescue => e
              _send_error('buildRAB', e)
            end
          end
        end

        # ---- Export Excel --------------------------------------------------
        def _cb_export_excel
          @dlg.add_action_callback('exportExcel') do |_, _|
            begin
              raise 'Bangun RAB terlebih dahulu' unless @last_rab_doc

              default = _default_filename('rab', 'xlsx')
              path = ::UI.savepanel('Simpan RAB sebagai Excel',
                                    @app.settings.export_path, default)
              next unless path
              path += '.xlsx' unless path.downcase.end_with?('.xlsx')

              exp = Export::ExcelExporter.new(
                @last_rab_doc,
                settings:      @app.settings,
                project_store: @app.project_store
              )
              result = exp.export(path)

              if result[:success]
                _send('onExportComplete', {
                  format: result[:format].to_s,
                  path:   result[:path]
                })
                ::UI.openURL("file:///#{result[:path].gsub('\\', '/')}")
              else
                _send_error('exportExcel', StandardError.new(result[:error].to_s))
              end
            rescue => e
              _send_error('exportExcel', e)
            end
          end
        end

        # ---- Export PDF ----------------------------------------------------
        def _cb_export_pdf
          @dlg.add_action_callback('exportPDF') do |_, _|
            begin
              raise 'Bangun RAB terlebih dahulu' unless @last_rab_doc

              default = _default_filename('rab', 'pdf')
              path = ::UI.savepanel('Simpan RAB sebagai PDF',
                                    @app.settings.export_path, default)
              next unless path
              path += '.pdf' unless path.downcase.end_with?('.pdf')

              exp    = Export::PDFExporter.new(@last_rab_doc, settings: @app.settings)
              result = exp.export(path)

              if result[:success]
                _send('onExportComplete', {
                  format:  result[:format].to_s,
                  path:    result[:path],
                  message: result[:message]
                })
                ::UI.openURL("file:///#{result[:path].gsub('\\', '/')}")
              else
                _send_error('exportPDF', StandardError.new(result[:error].to_s))
              end
            rescue => e
              _send_error('exportPDF', e)
            end
          end
        end

        # ---- Harga Satuan --------------------------------------------------
        def _cb_get_harga_satuan
          @dlg.add_action_callback('getHargaSatuan') do |_, category_id|
            begin
              cat_id  = category_id.to_s.strip.to_sym
              custom  = @app.project_store.all_custom_prices
              ps      = @app.project_store
              analisa = RAB::HargaSatuanDatabase.compute_analisa(
                cat_id,
                custom_prices: custom,
                overhead_pct:  ps.overhead_pct,
                profit_pct:    ps.profit_pct
              )
              _send('onHargaSatuanLoaded', analisa)
            rescue => e
              _send_error('getHargaSatuan', e)
            end
          end
        end

        def _cb_update_price
          @dlg.add_action_callback('updatePrice') do |_, payload|
            begin
              data = _parse_payload(payload)
              @app.project_store.set_price(data['item_key'], data['price'].to_f)
              _send('onPriceUpdated', {
                item_key: data['item_key'],
                price:    data['price'].to_f
              })
            rescue => e
              _send_error('updatePrice', e)
            end
          end
        end

        def _cb_set_quantity_override
          @dlg.add_action_callback('setQuantityOverride') do |_, payload|
            begin
              data   = _parse_payload(payload)
              model  = Sketchup.active_model
              entity = model.find_entity_by_id(data['entity_id'].to_i)
              raise 'Entity tidak ditemukan' unless entity

              model.start_operation('RAB Pro: Override quantity', true)
              Core::Tagger::TagEngine.set_quantity_override(entity, data['quantity'].to_f)
              model.commit_operation
              _send('onQuantityOverrideSet', data)
            rescue => e
              Sketchup.active_model&.abort_operation
              _send_error('setQuantityOverride', e)
            end
          end
        end

        # ---- AI callbacks --------------------------------------------------
        def _cb_ai_analyze_rab
          @dlg.add_action_callback('aiAnalyzeRAB') do |_, _|
            begin
              raise 'Bangun RAB terlebih dahulu' unless @last_rab_doc
              engine = AI::AIEngine.new(@app.settings)
              result = engine.analyze_rab(@last_rab_doc)
              _send('onAIAnalysis', result || { analysis: 'Tidak ada hasil' })
            rescue => e
              _send_error('aiAnalyzeRAB', e)
            end
          end
        end

        def _cb_ai_suggest_alternatives
          @dlg.add_action_callback('aiSuggestAlternatives') do |_, payload|
            begin
              data   = _parse_payload(payload)
              engine = AI::AIEngine.new(@app.settings)
              result = engine.suggest_alternatives(
                data['category_name'].to_s,
                data['unit_price'].to_f,
                data['quantity'].to_f,
                data['unit'].to_s
              )
              _send('onAIResponse', result)
            rescue => e
              _send_error('aiSuggestAlternatives', e)
            end
          end
        end

        def _cb_ai_detect_anomalies
          @dlg.add_action_callback('aiDetectAnomalies') do |_, _|
            begin
              model  = Sketchup.active_model
              engine_qto = RAB::QuantityTakeoffEngine.new(model,
                             settings: @app.settings,
                             project_store: @app.project_store)
              qto    = engine_qto.run
              ai     = AI::AIEngine.new(@app.settings)
              result = ai.detect_anomalies(qto[:summary] || {})
              _send('onAIResponse', result)
            rescue => e
              _send_error('aiDetectAnomalies', e)
            end
          end
        end

        # ---- Serialization helpers -----------------------------------------

        def _serialize_qto_item(item)
          return item if item.is_a?(Hash)
          {
            id:              item.id.to_s,
            category_id:     item.category_id.to_s,
            category_code:   item.category_code.to_s,
            category_name:   item.category_name.to_s,
            entity_id:       item.entity_id.to_i,
            entity_name:     item.entity_name.to_s,
            layer:           item.layer.to_s,
            quantity:        item.quantity.to_f.round(4),
            unit:            item.unit.to_s,
            quantity_type:   item.quantity_type.to_s,
            is_override:     item.is_override ? true : false,
            notes:           item.notes.to_s
          }
        rescue => e
          { error: e.message }
        end

        def _serialize_qto_summary(sum)
          return sum if sum.is_a?(Hash)
          {
            category_id:     sum.category_id.to_s,
            category_code:   sum.category_code.to_s,
            category_name:   sum.category_name.to_s,
            group:           sum.group.to_s,
            group_label:     sum.group_label.to_s,
            unit:            sum.unit.to_s,
            quantity_type:   sum.quantity_type.to_s,
            total_quantity:  sum.total_quantity.to_f.round(4),
            item_count:      sum.item_count.to_i
            # omit :items array to avoid deep nesting issues
          }
        rescue => e
          { error: e.message }
        end

        def _serialize_rab_doc(doc)
          {
            project_info:  doc.project_info,
            sections:      (doc.sections || []).map { |s|
              {
                group:         s.group.to_s,
                group_label:   s.group_label.to_s,
                section_total: s.section_total.to_f,
                items: (s.items || []).map { |item|
                  {
                    no:            item.no.to_i,
                    category_code: item.category_code.to_s,
                    category_name: item.category_name.to_s,
                    unit:          item.unit.to_s,
                    quantity:      item.quantity.to_f,
                    unit_price:    item.unit_price.to_f,
                    total_price:   item.total_price.to_f,
                    item_count:    item.item_count.to_i
                  }
                }
              }
            },
            rekapitulasi:  doc.rekapitulasi,
            subtotal:      doc.subtotal.to_f,
            overhead:      doc.overhead.to_f,
            overhead_pct:  doc.overhead_pct.to_f,
            profit:        doc.profit.to_f,
            profit_pct:    doc.profit_pct.to_f,
            ppn:           doc.ppn.to_f,
            ppn_pct:       doc.ppn_pct.to_f,
            grand_total:   doc.grand_total.to_f,
            terbilang:     doc.terbilang.to_s,
            generated_at:  doc.generated_at.to_s,
            qto_stats:     doc.qto_stats || {}
          }
        end

        def _cache_rab_lines(doc, model)
          lines = (doc.sections || []).flat_map do |s|
            (s.items || []).map do |item|
              {
                category_id:   item.category_code.to_s.downcase.tr('-', '_'),
                category_name: item.category_name.to_s,
                unit:          item.unit.to_s,
                quantity:      item.quantity.to_f,
                total_price:   item.total_price.to_f
              }
            end
          end
          model.set_attribute('RABPro_Dashboard', 'cached_rab_lines',
                              JSON.generate(lines))
        rescue => e
          Logger.warn("_cache_rab_lines: #{e.message}")
        end

        # ---- Utilities -----------------------------------------------------

        def _parse_payload(payload)
          return payload if payload.is_a?(Hash)
          return {} if payload.nil?
          JSON.parse(payload.to_s)
        rescue
          {}
        end

        def _send(event, data)
          require 'json'
          json = JSON.generate(data)
          @dlg&.execute_script(
            "window.RABPro && window.RABPro.onRubyEvent('#{event}', #{json})"
          )
        rescue => e
          Logger.error("RABPanel._send #{event}: #{e.message}")
        end

        def _send_error(source, error)
          Logger.error("RABPanel #{source}: #{error.message}\n#{error.backtrace&.first(3)&.join("\n")}")
          _send('onError', { source: source, message: error.message })
        end

        def _default_filename(prefix, ext)
          pi   = @app.project_store&.project_info
          slug = (pi&.name || 'proyek').to_s.downcase
                   .gsub(/[^a-z0-9]+/, '_').gsub(/_+/, '_')[0, 20]
          "#{prefix}_#{slug}_#{Time.now.strftime('%Y%m%d')}.#{ext}"
        end

      end
    end
  end
end
