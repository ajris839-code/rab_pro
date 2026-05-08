# ==============================================================================
# RAB Pro - LayOut Automation
# Generates professional technical drawing sheets via SketchUp LayOut API.
# Creates denah, tampak, potongan sheets with title blocks and annotations.
#
# Requires: SketchUp Pro + LayOut (layout gem available in SU Pro Ruby)
# Fallback: Export high-res PNG images with HTML drawing sheet
# ==============================================================================

module RABPro
  module Drawings
    module Layout
      class LayoutAutomation

        # Check for LayOut API availability
        begin
          require 'layout'
          LAYOUT_AVAILABLE = true
        rescue LoadError
          LAYOUT_AVAILABLE = false
        end

        # Paper sizes in mm [width, height]
        PAPER_SIZES = {
          'A4'  => [297.0,  210.0],
          'A3'  => [420.0,  297.0],
          'A2'  => [594.0,  420.0],
          'A1'  => [841.0,  594.0],
          'A0'  => [1189.0, 841.0]
        }.freeze

        # Drawing scale options
        SCALES = {
          '1:50'   => 50,
          '1:100'  => 100,
          '1:200'  => 200,
          '1:500'  => 500,
          '1:1000' => 1000
        }.freeze

        # Standard drawing types and their LayOut placement config
        SHEET_CONFIG = [
          {
            id:          :cover,
            title:       'COVER',
            description: 'Halaman Cover & Daftar Gambar',
            scene:       nil,
            scale:       nil,
            viewport_rect: nil   # no viewport — cover page only
          },
          {
            id:          :denah_lt1,
            title:       'A-01',
            description: 'Denah Lantai 1',
            scene:       'RAB_Denah_LT1',
            scale:       '1:100',
            viewport_rect: [20, 30, 200, 170]   # x,y,w,h in mm from page edge
          },
          {
            id:          :denah_lt2,
            title:       'A-02',
            description: 'Denah Lantai 2',
            scene:       'RAB_Denah_LT2',
            scale:       '1:100',
            viewport_rect: [20, 30, 200, 170]
          },
          {
            id:          :denah_atap,
            title:       'A-03',
            description: 'Denah Atap',
            scene:       'RAB_Denah_Atap',
            scale:       '1:100',
            viewport_rect: [20, 30, 200, 170]
          },
          {
            id:          :tampak_depan_belakang,
            title:       'A-04',
            description: 'Tampak Depan & Belakang',
            scene:       'RAB_Tampak_Depan',
            scale:       '1:100',
            viewport_rect: [20, 120, 200, 80]
          },
          {
            id:          :tampak_samping,
            title:       'A-05',
            description: 'Tampak Kiri & Kanan',
            scene:       'RAB_Tampak_Kiri',
            scale:       '1:100',
            viewport_rect: [20, 120, 200, 80]
          },
          {
            id:          :potongan,
            title:       'A-06',
            description: 'Potongan A-A & B-B',
            scene:       'RAB_Potongan_AA',
            scale:       '1:100',
            viewport_rect: [20, 120, 200, 80]
          },
          {
            id:          :detail_pondasi,
            title:       'S-01',
            description: 'Detail Pondasi',
            scene:       nil,
            scale:       '1:50',
            viewport_rect: [20, 30, 200, 170]
          },
          {
            id:          :perspektif,
            title:       'A-07',
            description: 'Tampak 3D Perspektif',
            scene:       'RAB_Perspektif',
            scale:       nil,
            viewport_rect: [20, 30, 200, 170]
          }
        ].freeze

        def initialize(model, settings: nil, project_store: nil)
          @model         = model
          @settings      = settings
          @project_store = project_store
          @paper_size    = settings&.get('pdf_paper_size') || 'A3'
          @pi            = project_store&.project_info&.to_h || {}
        end

        # -----------------------------------------------------------------------
        # Generate full drawing set — returns { success:, path:, sheets: }
        # -----------------------------------------------------------------------
        def generate(output_path, sheet_ids: nil, paper_size: nil)
          @paper_size = paper_size || @paper_size
          sheets_to_make = sheet_ids ? SHEET_CONFIG.select { |s| sheet_ids.include?(s[:id]) }
                                     : SHEET_CONFIG

          if LAYOUT_AVAILABLE
            _generate_with_layout(output_path, sheets_to_make)
          else
            _generate_html_fallback(output_path, sheets_to_make)
          end
        end

        # -----------------------------------------------------------------------
        # Export current scene as high-res PNG
        # -----------------------------------------------------------------------
        def export_scene_png(scene_name, output_path, width: 3508, height: 2480)
          page = @model.pages[scene_name]
          unless page
            Logger.warn("Scene '#{scene_name}' not found — using active view")
          else
            @model.pages.selected_page = page
          end

          view = @model.active_view
          opts = {
            'filename'      => output_path,
            'width'         => width,
            'height'        => height,
            'antialias'     => true,
            'transparent'   => false,
            'compression'   => 0.9
          }

          result = view.write_image(opts)
          Logger.info("export_scene_png: #{result} → #{output_path}")
          result
        rescue => e
          Logger.error("export_scene_png: #{e.message}")
          false
        end

        # -----------------------------------------------------------------------
        # Sheet list for UI
        # -----------------------------------------------------------------------
        def self.sheet_list
          SHEET_CONFIG.map do |s|
            { id: s[:id], title: s[:title], description: s[:description] }
          end
        end

        private

        # -----------------------------------------------------------------------
        # Generate using LayOut Ruby API (SketchUp Pro only)
        # -----------------------------------------------------------------------
        def _generate_with_layout(output_path, sheets)
          skp_path = @model.path
          if skp_path.empty?
            raise 'Model belum disimpan. Simpan model SketchUp terlebih dahulu.'
          end

          doc    = Layout::Document.new
          w, h   = PAPER_SIZES[@paper_size] || PAPER_SIZES['A3']
          page_info = doc.page_info
          page_info.width  = w
          page_info.height = h

          created_sheets = []

          sheets.each do |cfg|
            page = (doc.pages.count == 0) ? doc.pages[0] : doc.pages.add(cfg[:description])
            page.name = cfg[:description]

            # Title block
            _add_layout_title_block(doc, page, cfg, w, h)

            # Viewport (SketchUp scene)
            if cfg[:scene] && cfg[:viewport_rect]
              skp_ref = Layout::SketchUpModel.new(skp_path, doc)
              vp_rect = cfg[:viewport_rect]
              bounds  = Layout::AxisAlignedRectangle2D.new(
                Geom::Point2d.new(vp_rect[0], h - vp_rect[1] - vp_rect[3]),
                Geom::Point2d.new(vp_rect[0] + vp_rect[2], h - vp_rect[1])
              )
              skp_ref.current_page = doc.pages.index(page)
              entity = doc.add_sketchup_model(skp_ref, bounds)
              entity.current_scene = cfg[:scene]
              entity.scale = _parse_scale(cfg[:scale])
              entity.preserve_scale_on_resize = true
            end

            created_sheets << cfg[:title]
          end

          # Save as .layout file
          layout_path = output_path.sub(/\.(pdf|png)$/i, '.layout')
          doc.save(layout_path)

          # Export to PDF
          pdf_opts = Layout::Document::ExportOptions.new
          pdf_opts.output_resolution = Layout::Document::ExportOptions::OUTPUT_RESOLUTION_HIGH
          doc.export(output_path, pdf_opts)

          Logger.info("LayoutAutomation: #{created_sheets.size} sheets exported to #{output_path}")
          { success: true, path: output_path, layout_path: layout_path, sheets: created_sheets }

        rescue => e
          Logger.error("_generate_with_layout: #{e.message}")
          { success: false, error: e.message }
        end

        # -----------------------------------------------------------------------
        # Add title block to a LayOut page
        # -----------------------------------------------------------------------
        def _add_layout_title_block(doc, page, cfg, pw, ph)
          tb_h  = 40.0   # title block height in mm
          tb_y  = 0.0

          # Outer border
          border = Layout::Rectangle.new(
            Geom::Point2d.new(10, 10),
            Geom::Point2d.new(pw - 10, ph - 10)
          )
          border.style.stroke_color = Sketchup::Color.new(0, 0, 0)
          border.style.stroke_width = 0.5
          doc.add_entity(border, page)

          # Title block bottom strip
          tb_rect = Layout::Rectangle.new(
            Geom::Point2d.new(10, ph - 10 - tb_h),
            Geom::Point2d.new(pw - 10, ph - 10)
          )
          tb_rect.style.fill_color   = Sketchup::Color.new(31, 56, 100)
          tb_rect.style.stroke_color = Sketchup::Color.new(0, 0, 0)
          tb_rect.style.stroke_width = 0.3
          doc.add_entity(tb_rect, page)

          # Project name
          proj_text = Layout::FormattedText.new(
            @pi[:name] || 'Nama Proyek',
            Geom::Point2d.new(15, ph - 10 - tb_h + 5),
            Geom::Point2d.new(pw * 0.6, ph - 10 - tb_h + 20)
          )
          proj_text.style.font_size  = 10
          proj_text.style.bold       = true
          proj_text.style.text_color = Sketchup::Color.new(255, 255, 255)
          doc.add_entity(proj_text, page)

          # Drawing title
          draw_text = Layout::FormattedText.new(
            cfg[:description],
            Geom::Point2d.new(15, ph - 10 - tb_h + 22),
            Geom::Point2d.new(pw * 0.6, ph - 10 - tb_h + 38)
          )
          draw_text.style.font_size  = 8
          draw_text.style.text_color = Sketchup::Color.new(200, 200, 200)
          doc.add_entity(draw_text, page)

          # Drawing number (right side)
          num_text = Layout::FormattedText.new(
            cfg[:title],
            Geom::Point2d.new(pw - 60, ph - 10 - tb_h + 8),
            Geom::Point2d.new(pw - 12, ph - 10 - tb_h + 38)
          )
          num_text.style.font_size  = 16
          num_text.style.bold       = true
          num_text.style.text_color = Sketchup::Color.new(255, 255, 255)
          num_text.style.text_alignment = Layout::Style::ALIGN_RIGHT
          doc.add_entity(num_text, page)

          # Scale
          if cfg[:scale]
            scale_text = Layout::FormattedText.new(
              "Skala: #{cfg[:scale]}",
              Geom::Point2d.new(pw * 0.6, ph - 10 - tb_h + 5),
              Geom::Point2d.new(pw - 65, ph - 10 - tb_h + 20)
            )
            scale_text.style.font_size  = 7
            scale_text.style.text_color = Sketchup::Color.new(180, 180, 180)
            doc.add_entity(scale_text, page)
          end

          # Date
          date_text = Layout::FormattedText.new(
            Time.now.strftime('%d/%m/%Y'),
            Geom::Point2d.new(pw * 0.6, ph - 10 - tb_h + 22),
            Geom::Point2d.new(pw - 65, ph - 10 - tb_h + 38)
          )
          date_text.style.font_size  = 7
          date_text.style.text_color = Sketchup::Color.new(180, 180, 180)
          doc.add_entity(date_text, page)

        rescue => e
          Logger.warn("_add_layout_title_block: #{e.message}")
        end

        def _parse_scale(scale_str)
          return 1.0 / 100.0 unless scale_str
          parts = scale_str.split(':')
          parts.size == 2 ? parts[0].to_f / parts[1].to_f : 1.0 / 100.0
        end

        # -----------------------------------------------------------------------
        # HTML fallback — generates print-ready HTML drawing sheets
        # -----------------------------------------------------------------------
        def _generate_html_fallback(output_path, sheets)
          pi        = @pi
          html_path = output_path.sub(/\.(pdf|layout)$/i, '_gambar_teknis.html')
          w, h      = PAPER_SIZES[@paper_size] || PAPER_SIZES['A3']

          # Export PNG images for each scene
          img_tags  = {}
          sheets.each do |cfg|
            next unless cfg[:scene]
            png_path = output_path.sub(/\.[^.]+$/, "_#{cfg[:id]}.png")
            success  = export_scene_png(cfg[:scene], png_path, width: 2480, height: 1754)
            img_tags[cfg[:id]] = success ? File.basename(png_path) : nil
          end

          sheets_html = sheets.map do |cfg|
            img_tag = if img_tags[cfg[:id]]
              "<img src='#{img_tags[cfg[:id]]}' style='max-width:100%;max-height:#{h - 55}mm;object-fit:contain'>"
            else
              "<div class='no-img'>#{cfg[:id] == :cover ? '' : 'Export scene "' + cfg[:scene].to_s + '" dari SketchUp terlebih dahulu'}</div>"
            end

            <<~SHEET
              <div class="sheet" id="sheet-#{cfg[:id]}">
                <div class="viewport">
                  #{cfg[:id] == :cover ? _cover_content(pi) : img_tag}
                </div>
                <div class="title-block">
                  <div class="tb-project">
                    <div class="tb-name">#{esc(pi[:name] || 'PROYEK')}</div>
                    <div class="tb-desc">#{esc(pi[:description] || '')}</div>
                    <div class="tb-loc">#{esc(pi[:location] || '')}</div>
                  </div>
                  <div class="tb-drawing">
                    <div class="tb-title">#{esc(cfg[:description])}</div>
                    <div class="tb-scale">#{cfg[:scale] ? "Skala: #{cfg[:scale]}" : ''}</div>
                    <div class="tb-date">#{Time.now.strftime('%d/%m/%Y')}</div>
                  </div>
                  <div class="tb-num">#{esc(cfg[:title])}</div>
                </div>
              </div>
            SHEET
          end.join("\n")

          html = <<~HTML
            <!DOCTYPE html>
            <html lang="id">
            <head>
              <meta charset="UTF-8">
              <title>Gambar Teknis — #{esc(pi[:name] || 'Proyek')}</title>
              <style>
                @page { size: #{@paper_size} landscape; margin: 0; }
                * { box-sizing: border-box; font-family: Arial, sans-serif; }
                body { margin: 0; background: #888; }

                .controls {
                  position: fixed; top: 12px; right: 12px; z-index: 999;
                  display: flex; gap: 8px;
                }
                .controls button {
                  padding: 8px 16px; border-radius: 6px; border: none;
                  background: #0071e3; color: #fff; font-size: 13px; cursor: pointer;
                  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
                }
                .controls button:hover { background: #005bb5; }

                .sheet {
                  width: #{w}mm; height: #{h}mm;
                  background: white;
                  margin: 20mm auto;
                  display: flex; flex-direction: column;
                  box-shadow: 0 4px 20px rgba(0,0,0,0.4);
                  page-break-after: always;
                  position: relative;
                  border: 0.5mm solid #333;
                }

                .viewport {
                  flex: 1;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  padding: 10mm;
                  overflow: hidden;
                  border-bottom: 0.5mm solid #333;
                }

                .no-img {
                  color: #999; font-size: 14px; text-align: center; padding: 20px;
                  border: 2px dashed #ddd; border-radius: 8px; width: 100%;
                }

                .title-block {
                  height: 40mm;
                  display: flex;
                  border-top: 0.5mm solid #333;
                  background: #1F3864;
                  color: white;
                  flex-shrink: 0;
                }

                .tb-project {
                  flex: 3;
                  padding: 4mm 6mm;
                  border-right: 0.3mm solid rgba(255,255,255,0.3);
                  display: flex; flex-direction: column; justify-content: center;
                }

                .tb-name { font-size: 12px; font-weight: bold; margin-bottom: 2mm; }
                .tb-desc { font-size: 8px; color: #aaa; }
                .tb-loc  { font-size: 8px; color: #aaa; margin-top: 1mm; }

                .tb-drawing {
                  flex: 2;
                  padding: 4mm 6mm;
                  border-right: 0.3mm solid rgba(255,255,255,0.3);
                  display: flex; flex-direction: column; justify-content: center;
                }

                .tb-title { font-size: 10px; font-weight: 600; margin-bottom: 2mm; }
                .tb-scale { font-size: 8px; color: #bbb; }
                .tb-date  { font-size: 8px; color: #aaa; margin-top: 1mm; }

                .tb-num {
                  width: 40mm;
                  display: flex; align-items: center; justify-content: center;
                  font-size: 22px; font-weight: bold;
                  color: white;
                }

                /* Cover page */
                .cover-inner {
                  text-align: center; padding: 20mm;
                }
                .cover-logo { font-size: 48px; margin-bottom: 10mm; }
                .cover-title { font-size: 28px; font-weight: bold; color: #1F3864; margin-bottom: 5mm; }
                .cover-sub { font-size: 16px; color: #555; margin-bottom: 15mm; }
                .cover-info { text-align: left; display: inline-block; margin: 0 auto; }
                .cover-info td { padding: 3mm 8mm; font-size: 11px; }
                .cover-info td:first-child { font-weight: bold; color: #555; }
                .drawing-list { margin-top: 15mm; }
                .drawing-list table { width: 100%; border-collapse: collapse; font-size: 10px; }
                .drawing-list th { background: #1F3864; color: white; padding: 3mm 5mm; }
                .drawing-list td { border: 0.2mm solid #ddd; padding: 2mm 5mm; }

                @media print {
                  body { background: white; }
                  .controls { display: none; }
                  .sheet { margin: 0; box-shadow: none; }
                }
              </style>
            </head>
            <body>

            <div class="controls no-print">
              <button onclick="window.print()">🖨️ Cetak / Simpan PDF</button>
              <button onclick="showAll()">Semua Lembar</button>
            </div>

            #{sheets_html}

            <script>
              function showAll() {}
            </script>
            </body>
            </html>
          HTML

          File.write(html_path, html, encoding: 'UTF-8')
          Logger.info("LayoutAutomation HTML fallback: #{html_path}")

          {
            success: true,
            format:  :html,
            path:    html_path,
            sheets:  sheets.map { |s| s[:title] },
            message: 'Buka file HTML di browser → Ctrl+P → Simpan sebagai PDF (pilih ukuran kertas yang sesuai)'
          }
        rescue => e
          Logger.error("_generate_html_fallback: #{e.message}")
          { success: false, error: e.message }
        end

        def _cover_content(pi)
          <<~HTML
            <div class="cover-inner">
              <div class="cover-logo">🏛️</div>
              <div class="cover-title">GAMBAR TEKNIS</div>
              <div class="cover-sub">Rencana Arsitektur & Struktur</div>
              <table class="cover-info">
                <tr><td>Nama Proyek</td><td>#{esc(pi[:name] || '-')}</td></tr>
                <tr><td>Pemilik</td><td>#{esc(pi[:owner] || '-')}</td></tr>
                <tr><td>Lokasi</td><td>#{esc(pi[:location] || '-')}</td></tr>
                <tr><td>Konsultan</td><td>#{esc(pi[:consultant] || '-')}</td></tr>
                <tr><td>Kontraktor</td><td>#{esc(pi[:contractor] || '-')}</td></tr>
                <tr><td>Tanggal</td><td>#{Time.now.strftime('%d %B %Y')}</td></tr>
              </table>
              <div class="drawing-list">
                <table>
                  <thead><tr><th>No Gambar</th><th>Judul Gambar</th><th>Skala</th></tr></thead>
                  <tbody>
                    #{SHEET_CONFIG.reject { |s| s[:id] == :cover }.map { |s|
                        "<tr><td>#{esc(s[:title])}</td><td>#{esc(s[:description])}</td><td>#{esc(s[:scale] || '—')}</td></tr>"
                      }.join}
                  </tbody>
                </table>
              </div>
            </div>
          HTML
        end

        def esc(s)
          s.to_s.gsub('&','&amp;').gsub('<','&lt;').gsub('>','&gt;')
        end

      end
    end
  end
end
