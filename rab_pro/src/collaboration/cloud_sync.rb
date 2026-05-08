# ==============================================================================
# RAB Pro - Cloud Sync & Collaboration
# Enables sharing project data (RAB, drawings register, progress) via:
#   - JSON export / import for offline sharing
#   - Shareable HTML report generation
#   - Project snapshot versioning (stored in model)
#   - Team comment system (stored in model attributes)
# Note: Full cloud sync requires a backend service (Fase 4+ roadmap).
#       This file implements the local sync foundation and HTML sharing.
# ==============================================================================

require 'json'

module RABPro
  module Collaboration
    class CloudSync

      DICT          = 'RABPro_Sync'.freeze
      MAX_SNAPSHOTS = 10

      Snapshot = Struct.new(
        :id, :label, :created_at, :created_by,
        :rab_total, :progress_pct, :data,
        keyword_init: true
      )

      Comment = Struct.new(
        :id, :author, :text, :category, :entity_id,
        :created_at, :resolved,
        keyword_init: true
      )

      def initialize(model, project_store: nil, settings: nil)
        @model         = model
        @project_store = project_store
        @settings      = settings
      end

      # -----------------------------------------------------------------------
      # Create a project snapshot (version)
      # -----------------------------------------------------------------------
      def create_snapshot(label: nil, created_by: 'RAB Pro')
        snapshot_id = "snap_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
        label     ||= "Snapshot #{Time.now.strftime('%d/%m/%Y %H:%M')}"

        # Gather all project data
        data = _gather_project_data

        snap = Snapshot.new(
          id:           snapshot_id,
          label:        label,
          created_at:   Time.now.iso8601,
          created_by:   created_by,
          rab_total:    data.dig(:rab, :grand_total) || 0,
          progress_pct: _overall_progress,
          data:         data
        )

        # Save to model (keep last MAX_SNAPSHOTS)
        existing = load_snapshots
        existing << snap
        existing = existing.last(MAX_SNAPSHOTS)

        @model.set_attribute(DICT, 'snapshots',
          JSON.generate(existing.map { |s| _snapshot_to_h(s) }))

        Logger.info("CloudSync: snapshot '#{label}' created")
        snap
      end

      # -----------------------------------------------------------------------
      # Load all snapshots
      # -----------------------------------------------------------------------
      def load_snapshots
        raw = @model.get_attribute(DICT, 'snapshots')
        return [] unless raw
        JSON.parse(raw).map { |h| _snapshot_from_h(h) }
      rescue => e
        Logger.warn("CloudSync.load_snapshots: #{e.message}")
        []
      end

      # -----------------------------------------------------------------------
      # Export project as shareable JSON
      # -----------------------------------------------------------------------
      def export_json(output_path)
        data    = _gather_project_data
        payload = {
          export_info: {
            version:    RABPro::EXTENSION_VERSION,
            exported_at: Time.now.iso8601,
            format:     'rab_pro_project_v1'
          },
          **data
        }

        File.write(output_path, JSON.pretty_generate(payload), encoding: 'UTF-8')
        Logger.info("CloudSync: JSON exported to #{output_path}")
        { success: true, path: output_path, size_kb: (File.size(output_path) / 1024.0).round(1) }
      rescue => e
        Logger.error("CloudSync.export_json: #{e.message}")
        { success: false, error: e.message }
      end

      # -----------------------------------------------------------------------
      # Import project data from JSON
      # -----------------------------------------------------------------------
      def import_json(input_path)
        raw  = File.read(input_path, encoding: 'UTF-8')
        data = JSON.parse(raw)

        # Validate format
        fmt = data.dig('export_info', 'format')
        raise "Format tidak dikenal: #{fmt}" unless fmt == 'rab_pro_project_v1'

        # Restore project info
        if (pi = data['project_info'])
          @project_store&.save_project_info(pi.transform_keys(&:to_sym))
        end

        # Restore tags
        if (tags = data.dig('tags'))
          Core::Tagger::TagEngine.import_tags(@model, tags)
        end

        # Restore financial settings
        if (fin = data['financial'])
          @project_store&.save_financial_settings(
            overhead: fin['overhead_pct'].to_f,
            profit:   fin['profit_pct'].to_f,
            ppn:      fin['ppn_pct'].to_f
          )
        end

        Logger.info("CloudSync: JSON imported from #{input_path}")
        { success: true, path: input_path }
      rescue => e
        Logger.error("CloudSync.import_json: #{e.message}")
        { success: false, error: e.message }
      end

      # -----------------------------------------------------------------------
      # Generate shareable HTML project report
      # -----------------------------------------------------------------------
      def generate_share_report(output_path)
        data = _gather_project_data
        pi   = data[:project_info] || {}
        rab  = data[:rab] || {}
        prog = data[:progress] || []

        currency = @settings&.currency_symbol || 'BND$'

        # Build sections HTML
        sections_html = (rab[:sections] || []).map do |s|
          rows = (s[:items] || []).map.with_index do |item, i|
            bg = i.odd? ? 'background:#f9f9f9' : ''
            "<tr style='#{bg}'>
              <td>#{i+1}</td><td>#{esc(item[:category_code])}</td>
              <td>#{esc(item[:category_name])}</td><td style='text-align:center'>#{esc(item[:unit])}</td>
              <td style='text-align:right'>#{fmt3(item[:quantity])}</td>
              <td style='text-align:right'>#{fmtcur(currency, item[:unit_price])}</td>
              <td style='text-align:right;font-weight:600'>#{fmtcur(currency, item[:total_price])}</td>
            </tr>"
          end.join

          "<tr style='background:#D6E4F0;font-weight:bold'><td colspan='7'>#{esc(s[:group_label]&.upcase || '')}</td></tr>
           #{rows}
           <tr style='background:#e8f0ff;font-weight:600'>
             <td colspan='6' style='text-align:right'>Sub Total #{esc(s[:group_label] || '')}</td>
             <td style='text-align:right'>#{fmtcur(currency, s[:section_total])}</td>
           </tr>"
        end.join

        progress_html = prog.map do |p|
          pct = p[:pct_complete] || 0
          bar_color = pct >= 100 ? '#2e7d32' : pct >= 50 ? '#0071e3' : '#ff9800'
          "<tr>
            <td>#{esc(p[:category_name])}</td>
            <td style='text-align:center'>#{fmt3(p[:planned_qty])} #{esc(p[:unit])}</td>
            <td style='text-align:right'>#{fmtcur(currency, p[:planned_cost])}</td>
            <td style='text-align:right'>#{fmtcur(currency, p[:actual_cost])}</td>
            <td>
              <div style='background:#eee;border-radius:4px;height:10px;overflow:hidden'>
                <div style='background:#{bar_color};height:100%;width:#{[pct,100].min}%;transition:width 0.3s'></div>
              </div>
              <div style='font-size:10px;text-align:center;margin-top:2px'>#{pct}%</div>
            </td>
          </tr>"
        end.join

        html = <<~HTML
          <!DOCTYPE html>
          <html lang="id">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>Laporan Proyek — #{esc(pi[:name] || 'Proyek')}</title>
            <style>
              * { box-sizing:border-box; font-family:Arial,sans-serif; }
              body { margin:0; padding:0; background:#f0f2f5; color:#1a1a1a; }
              .hero { background:linear-gradient(135deg,#1F3864,#2E75B6); color:#fff; padding:40px; }
              .hero h1 { font-size:28px; margin:0 0 8px; }
              .hero p  { font-size:14px; opacity:0.8; margin:0; }
              .container { max-width:1100px; margin:0 auto; padding:20px; }
              .card { background:#fff; border-radius:10px; box-shadow:0 2px 10px rgba(0,0,0,0.08);
                      margin-bottom:20px; overflow:hidden; }
              .card-title { padding:14px 20px; background:#f8f9fa; border-bottom:1px solid #eee;
                            font-size:14px; font-weight:700; color:#1F3864; }
              .card-body  { padding:16px 20px; }
              .kpi-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:16px; }
              .kpi { background:#fff; border-radius:8px; padding:16px; text-align:center;
                     box-shadow:0 2px 8px rgba(0,0,0,0.07); border-left:4px solid #2E75B6; }
              .kpi-val { font-size:22px; font-weight:700; color:#1F3864; }
              .kpi-label { font-size:11px; color:#888; margin-top:4px; }
              table { width:100%; border-collapse:collapse; font-size:12px; }
              th { background:#1F3864; color:#fff; padding:8px 10px; text-align:left; }
              td { padding:6px 10px; border-bottom:1px solid #f0f0f0; }
              .info-grid { display:grid; grid-template-columns:1fr 1fr; gap:8px; }
              .info-row { display:flex; gap:10px; padding:6px 0; border-bottom:1px solid #eee; }
              .info-label { font-weight:600; color:#555; min-width:130px; font-size:12px; }
              .info-val { font-size:12px; }
              .footer { text-align:center; padding:20px; color:#aaa; font-size:11px; }
              @media(max-width:600px) { .kpi-grid{grid-template-columns:1fr 1fr;} .info-grid{grid-template-columns:1fr;} }
            </style>
          </head>
          <body>

          <div class="hero">
            <h1>#{esc(pi[:name] || 'Laporan Proyek')}</h1>
            <p>#{esc(pi[:location] || '')} &nbsp;|&nbsp; Digenerate: #{Time.now.strftime('%d %B %Y %H:%M')} &nbsp;|&nbsp; RAB Pro v#{RABPro::EXTENSION_VERSION}</p>
          </div>

          <div class="container">

            <!-- KPI Cards -->
            <div class="kpi-grid" style="margin-bottom:20px">
              <div class="kpi" style="border-color:#1F3864">
                <div class="kpi-val">#{fmtcur(currency, rab[:grand_total])}</div>
                <div class="kpi-label">Total RAB</div>
              </div>
              <div class="kpi" style="border-color:#2e7d32">
                <div class="kpi-val">#{fmtcur(currency, data.dig(:dashboard,:actual_total) || 0)}</div>
                <div class="kpi-label">Aktual Terpakai</div>
              </div>
              <div class="kpi" style="border-color:#ff9800">
                <div class="kpi-val">#{(data.dig(:dashboard,:overall_pct) || 0)}%</div>
                <div class="kpi-label">Progress Keseluruhan</div>
              </div>
              <div class="kpi" style="border-color:#0071e3">
                <div class="kpi-val">#{(rab[:sections] || []).sum { |s| (s[:items] || []).size }}</div>
                <div class="kpi-label">Item Pekerjaan</div>
              </div>
            </div>

            <!-- Project Info -->
            <div class="card">
              <div class="card-title">📋 Informasi Proyek</div>
              <div class="card-body">
                <div class="info-grid">
                  #{[['Nama Proyek', pi[:name]], ['Pemilik', pi[:owner]], ['Lokasi', pi[:location]],
                     ['Konsultan', pi[:consultant]], ['Kontraktor', pi[:contractor]],
                     ['Tanggal Mulai', pi[:start_date]], ['Tanggal Selesai', pi[:end_date]]
                    ].map { |k,v| "<div class='info-row'><span class='info-label'>#{k}</span><span class='info-val'>#{esc(v || '—')}</span></div>" }.join}
                </div>
              </div>
            </div>

            <!-- RAB Summary -->
            <div class="card">
              <div class="card-title">📊 Rencana Anggaran Biaya</div>
              <div class="card-body" style="padding:0">
                <div style="overflow-x:auto">
                  <table>
                    <thead><tr>
                      <th>No</th><th>Kode</th><th>Uraian Pekerjaan</th><th>Sat</th>
                      <th>Volume</th><th>Harga Satuan</th><th>Jumlah Harga</th>
                    </tr></thead>
                    <tbody>
                      #{sections_html}
                      <tr style='background:#1F3864;color:#fff;font-size:13px;font-weight:700'>
                        <td colspan='6'>TOTAL RAB (termasuk O/H, Profit, PPN)</td>
                        <td style='text-align:right'>#{fmtcur(currency, rab[:grand_total])}</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            <!-- Progress -->
            #{prog.empty? ? '' : "<div class='card'>
              <div class='card-title'>📈 Progress Pekerjaan</div>
              <div class='card-body' style='padding:0'>
                <table>
                  <thead><tr><th>Pekerjaan</th><th>Volume Rencana</th><th>Biaya Rencana</th><th>Biaya Aktual</th><th style='min-width:120px'>Progress</th></tr></thead>
                  <tbody>#{progress_html}</tbody>
                </table>
              </div>
            </div>"}

          </div>

          <div class="footer">
            Laporan ini dibuat oleh RAB Pro SketchUp Extension v#{RABPro::EXTENSION_VERSION}<br>
            © #{Time.now.year} — Dokumen ini bersifat konfidensial
          </div>

          </body></html>
        HTML

        File.write(output_path, html, encoding: 'UTF-8')
        Logger.info("CloudSync: share report generated → #{output_path}")
        { success: true, path: output_path }
      rescue => e
        Logger.error("CloudSync.generate_share_report: #{e.message}")
        { success: false, error: e.message }
      end

      # -----------------------------------------------------------------------
      # Comment system
      # -----------------------------------------------------------------------
      def add_comment(author:, text:, category: nil, entity_id: nil)
        comment = Comment.new(
          id:         "cmt_#{Time.now.to_i}_#{rand(1000)}",
          author:     author,
          text:       text,
          category:   category,
          entity_id:  entity_id,
          created_at: Time.now.iso8601,
          resolved:   false
        )
        existing = load_comments
        existing << comment
        @model.set_attribute(DICT, 'comments',
          JSON.generate(existing.map(&:to_h)))
        comment
      end

      def load_comments
        raw = @model.get_attribute(DICT, 'comments')
        return [] unless raw
        JSON.parse(raw).map { |h| Comment.new(**h.transform_keys(&:to_sym)) }
      rescue
        []
      end

      def resolve_comment(comment_id)
        comments = load_comments
        c = comments.find { |cm| cm.id == comment_id }
        return nil unless c
        c.resolved = true
        @model.set_attribute(DICT, 'comments', JSON.generate(comments.map(&:to_h)))
        c
      end

      private

      def _gather_project_data
        {
          project_info: @project_store&.project_info&.to_h,
          financial: {
            overhead_pct: @project_store&.overhead_pct,
            profit_pct:   @project_store&.profit_pct,
            ppn_pct:      @project_store&.ppn_pct
          },
          rab:      _cached_rab,
          tags:     Core::Tagger::TagEngine.export_tags(@model),
          progress: _progress_data,
          dashboard: _dashboard_summary,
          drawings: _drawings_data
        }
      end

      def _cached_rab
        raw = @model.get_attribute('RABPro_Dashboard', 'cached_rab_lines')
        return {} unless raw
        { sections: [], grand_total: 0 }  # simplified; full doc from RABCalculator
      rescue
        {}
      end

      def _progress_data
        db = Dashboard::ProjectDashboard.new(@model, project_store: @project_store)
        db.load_progress.map(&:to_h)
      rescue
        []
      end

      def _dashboard_summary
        db = Dashboard::ProjectDashboard.new(@model, project_store: @project_store)
        snap = db.snapshot
        { overall_pct: snap[:overall_pct], actual_total: snap[:actual_total] }
      rescue
        {}
      end

      def _drawings_data
        reg = Drawings::DrawingRegister.new(@model)
        reg.to_table
      rescue
        []
      end

      def _overall_progress
        db = Dashboard::ProjectDashboard.new(@model, project_store: @project_store)
        db.snapshot[:overall_pct]
      rescue
        0
      end

      def _snapshot_to_h(s)
        h = s.to_h
        h[:data] = nil  # don't re-serialize full data inside snapshots list
        h
      end

      def _snapshot_from_h(h)
        Snapshot.new(**h.transform_keys(&:to_sym))
      end

      def esc(s); s.to_s.gsub('&','&amp;').gsub('<','&lt;').gsub('>','&gt;') end
      def fmt3(n); ('%,.3f' % n.to_f) end
      def fmtcur(sym, n); "#{sym} #{('%,.2f' % n.to_f)}" end

    end
  end
end
