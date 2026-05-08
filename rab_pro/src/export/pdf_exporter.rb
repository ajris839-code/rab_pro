# ==============================================================================
# RAB Pro - PDF Exporter
# Generates a professional RAB PDF document using pure Ruby.
# Primary: Prawn gem (bundled). Fallback: HTML→PDF via SketchUp browser.
# ==============================================================================

module RABPro
  module Export
    class PDFExporter

      begin
        require 'prawn'
        require 'prawn/table'
        GEM_AVAILABLE = true
      rescue LoadError
        GEM_AVAILABLE = false
      end

      PAGE_SIZE       = 'A4'
      MARGIN          = [40, 40, 40, 40]   # top, right, bottom, left
      HEADER_COLOR    = '1F3864'
      SUBHEAD_COLOR   = '2E75B6'
      GROUP_COLOR     = 'D6E4F0'
      ALT_ROW_COLOR   = 'F5F9FF'
      TEXT_COLOR      = '1A1A1A'
      MUTED_COLOR     = '666666'

      def initialize(rab_document, settings: nil)
        @doc      = rab_document
        @settings = settings
        @currency = settings&.currency_symbol || 'BND$'
      end

      # -----------------------------------------------------------------------
      # Export to PDF — returns { success:, path: }
      # -----------------------------------------------------------------------
      def export(output_path)
        unless GEM_AVAILABLE
          return _export_html_fallback(output_path)
        end

        Prawn::Document.generate(
          output_path,
          page_size:   PAGE_SIZE,
          page_layout: :portrait,
          margin:      MARGIN,
          info: {
            Title:    'Rencana Anggaran Biaya',
            Author:   'RAB Pro SketchUp Extension',
            Creator:  "RAB Pro v#{RABPro::EXTENSION_VERSION}",
            CreationDate: Time.now
          }
        ) do |pdf|
          _setup_fonts(pdf)
          _draw_cover(pdf)
          pdf.start_new_page
          _draw_rab_table(pdf)
          pdf.start_new_page
          _draw_rekap(pdf)
          _draw_footer(pdf)
        end

        Logger.info("PDFExporter: saved → #{output_path}")
        { success: true, path: output_path }

      rescue => e
        Logger.error("PDFExporter: #{e.message}")
        { success: false, error: e.message }
      end

      private

      # -----------------------------------------------------------------------
      # Font setup
      # -----------------------------------------------------------------------
      def _setup_fonts(pdf)
        # Use built-in Helvetica (always available)
        pdf.font 'Helvetica'
      rescue
        # Keep default
      end

      # -----------------------------------------------------------------------
      # Cover page
      # -----------------------------------------------------------------------
      def _draw_cover(pdf)
        pi = @doc.project_info || {}

        # Header banner
        pdf.fill_color HEADER_COLOR
        pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, 80
        pdf.fill_color 'FFFFFF'
        pdf.text_box 'RENCANA ANGGARAN BIAYA',
          at:     [0, pdf.bounds.top - 10],
          width:  pdf.bounds.width,
          align:  :center,
          size:   24,
          style:  :bold
        pdf.text_box 'RAB Pro — SketchUp Extension',
          at:     [0, pdf.bounds.top - 45],
          width:  pdf.bounds.width,
          align:  :center,
          size:   11

        pdf.fill_color TEXT_COLOR
        pdf.move_down 100

        # Project info table
        info_data = [
          ['Nama Proyek',     pi[:name]        || '-'],
          ['Pemilik / Owner', pi[:owner]       || '-'],
          ['Lokasi',          pi[:location]    || '-'],
          ['Konsultan',       pi[:consultant]  || '-'],
          ['Kontraktor',      pi[:contractor]  || '-'],
          ['Tanggal Mulai',   pi[:start_date]  || '-'],
          ['Tanggal Selesai', pi[:end_date]    || '-'],
          ['Deskripsi',       pi[:description] || '-'],
        ]

        pdf.table info_data,
          width:       pdf.bounds.width,
          cell_style:  { size: 10, padding: [6, 8] },
          column_widths: [150, pdf.bounds.width - 150] do |t|
            t.column(0).font_style = :bold
            t.column(0).background_color = GROUP_COLOR
            t.row(0).background_color = GROUP_COLOR
          end

        pdf.move_down 20

        # Financial summary box
        pdf.fill_color SUBHEAD_COLOR
        pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 20
        pdf.fill_color 'FFFFFF'
        pdf.text_box 'RINGKASAN BIAYA',
          at:    [0, pdf.cursor - 3],
          width: pdf.bounds.width,
          align: :center, size: 11, style: :bold
        pdf.fill_color TEXT_COLOR
        pdf.move_down 25

        summary_data = [
          ['Sub Total Pekerjaan',             _fmt_currency(@doc.subtotal)],
          ["Overhead (#{@doc.overhead_pct}%)", _fmt_currency(@doc.overhead)],
          ["Profit (#{@doc.profit_pct}%)",     _fmt_currency(@doc.profit)],
          ["PPN (#{@doc.ppn_pct}%)",          _fmt_currency(@doc.ppn)],
          ['TOTAL BIAYA PROYEK',              _fmt_currency(@doc.grand_total)],
        ]

        pdf.table summary_data,
          width:      pdf.bounds.width,
          cell_style: { size: 10, padding: [6, 8] },
          column_widths: [300, pdf.bounds.width - 300] do |t|
            t.row(-1).font_style = :bold
            t.row(-1).size = 12
            t.row(-1).background_color = HEADER_COLOR
            t.row(-1).text_color = 'FFFFFF'
            t.column(1).align = :right
          end

        pdf.move_down 10
        pdf.fill_color 'AA8800'
        pdf.text "Terbilang: #{@doc.terbilang}", size: 9, style: :italic
        pdf.fill_color TEXT_COLOR

        # Footer on cover
        pdf.move_down 30
        pdf.text "Dibuat: #{Time.now.strftime('%d %B %Y %H:%M')} | RAB Pro v#{RABPro::EXTENSION_VERSION}",
          size: 8, align: :center, color: MUTED_COLOR
      end

      # -----------------------------------------------------------------------
      # RAB Table
      # -----------------------------------------------------------------------
      def _draw_rab_table(pdf)
        _section_title(pdf, 'RENCANA ANGGARAN BIAYA — DETAIL')

        col_widths = [22, 35, 160, 30, 55, 70, 75]
        headers    = ['No', 'Kode', 'Uraian Pekerjaan', 'Sat', 'Volume',
                      "Harga Satuan\n(#{@currency})", "Jumlah Harga\n(#{@currency})"]

        all_rows = [headers]

        @doc.sections.each do |section|
          # Section header row
          all_rows << [{ content: section.group_label.upcase, colspan: 7 }]

          section.items.each_with_index do |item, idx|
            all_rows << [
              item.no.to_s,
              item.category_code,
              item.category_name,
              item.unit,
              _fmt_qty(item.quantity),
              _fmt_currency(item.unit_price),
              _fmt_currency(item.total_price)
            ]
          end

          # Subtotal row
          all_rows << [
            { content: "Sub Total #{section.group_label}", colspan: 6 },
            _fmt_currency(section.section_total)
          ]
        end

        pdf.table all_rows,
          width:       pdf.bounds.width,
          header:      true,
          cell_style:  { size: 8, padding: [4, 4] } do |t|

          # Header row
          t.row(0).background_color = HEADER_COLOR
          t.row(0).text_color       = 'FFFFFF'
          t.row(0).font_style       = :bold
          t.row(0).align            = :center

          t.columns(4..6).align = :right
          t.column(0).align     = :center
          t.column(3).align     = :center

          # Color section headers and subtotals dynamically
          idx = 0
          @doc.sections.each do |section|
            idx += 1  # header row offset
            section_start = idx
            t.row(section_start).background_color = GROUP_COLOR
            t.row(section_start).font_style       = :bold
            idx += section.items.size + 1

            t.row(idx).background_color = GROUP_COLOR
            t.row(idx).font_style       = :bold
            idx += 1
          end

          # Alternating row colors for data rows
          t.rows(1..-1).each_with_index do |row, i|
            # Skip — handled above for section rows
          end
        end

        # Grand total block
        pdf.move_down 10
        total_data = [
          ['Sub Total Pekerjaan',              _fmt_currency(@doc.subtotal)],
          ["Overhead (#{@doc.overhead_pct}%)", _fmt_currency(@doc.overhead)],
          ["Profit (#{@doc.profit_pct}%)",      _fmt_currency(@doc.profit)],
          ["PPN (#{@doc.ppn_pct}%)",           _fmt_currency(@doc.ppn)],
          ['TOTAL RENCANA ANGGARAN BIAYA',     _fmt_currency(@doc.grand_total)],
        ]

        pdf.table total_data,
          width:       pdf.bounds.width,
          cell_style:  { size: 9, padding: [5, 6] },
          column_widths: [pdf.bounds.width - 120, 120] do |t|
            t.column(1).align = :right
            t.row(-1).background_color = HEADER_COLOR
            t.row(-1).text_color       = 'FFFFFF'
            t.row(-1).font_style       = :bold
            t.row(-1).size             = 10
          end

        pdf.move_down 6
        pdf.text "Terbilang: #{@doc.terbilang}", size: 8, style: :italic, color: 'AA8800'
      end

      # -----------------------------------------------------------------------
      # Rekapitulasi page
      # -----------------------------------------------------------------------
      def _draw_rekap(pdf)
        _section_title(pdf, 'REKAPITULASI RENCANA ANGGARAN BIAYA')

        rekap_data = [['No', 'Uraian Pekerjaan', "Jumlah (#{@currency})"]]

        @doc.rekapitulasi.each do |r|
          rekap_data << [r[:no].to_s, r[:group_label], _fmt_currency(r[:total])]
        end

        rekap_data << ['', 'Sub Total', _fmt_currency(@doc.subtotal)]
        rekap_data << ['', "Overhead (#{@doc.overhead_pct}%)", _fmt_currency(@doc.overhead)]
        rekap_data << ['', "Profit (#{@doc.profit_pct}%)", _fmt_currency(@doc.profit)]
        rekap_data << ['', "PPN (#{@doc.ppn_pct}%)", _fmt_currency(@doc.ppn)]
        rekap_data << ['', 'TOTAL', _fmt_currency(@doc.grand_total)]

        pdf.table rekap_data,
          width:       pdf.bounds.width,
          header:      true,
          cell_style:  { size: 9, padding: [5, 6] },
          column_widths: [30, pdf.bounds.width - 150, 120] do |t|
            t.row(0).background_color = HEADER_COLOR
            t.row(0).text_color       = 'FFFFFF'
            t.row(0).font_style       = :bold
            t.column(2).align         = :right
            t.column(0).align         = :center

            # Last row = grand total
            t.row(-1).background_color = HEADER_COLOR
            t.row(-1).text_color       = 'FFFFFF'
            t.row(-1).font_style       = :bold
          end

        pdf.move_down 6
        pdf.text "Terbilang: #{@doc.terbilang}", size: 8, style: :italic, color: 'AA8800'

        # Signature block
        pdf.move_down 40
        sig_data = [
          ['Disetujui Oleh', 'Diperiksa Oleh', 'Dibuat Oleh'],
          [' ', ' ', ' '],
          [' ', ' ', ' '],
          [' ', ' ', ' '],
          ['(________________________)', '(________________________)', '(________________________)'],
          ['Pemilik Proyek', 'Konsultan / MK', "RAB Pro v#{RABPro::EXTENSION_VERSION}"],
        ]
        pdf.table sig_data,
          width:      pdf.bounds.width,
          cell_style: { size: 9, align: :center, padding: [4, 4], border_width: 0 } do |t|
            t.row(0).font_style = :bold
          end
      end

      # -----------------------------------------------------------------------
      # Running footer on all pages
      # -----------------------------------------------------------------------
      def _draw_footer(pdf)
        pi = @doc.project_info || {}
        pdf.repeat(:all, dynamic: true) do
          pdf.draw_text(
            "RAB Pro | #{pi[:name] || 'Proyek'} | Hal. #{pdf.page_number}",
            at:   [pdf.bounds.left, pdf.bounds.bottom - 20],
            size: 7,
            color: MUTED_COLOR
          )
          pdf.draw_text(
            Time.now.strftime('%d/%m/%Y'),
            at:   [pdf.bounds.right - 50, pdf.bounds.bottom - 20],
            size: 7,
            color: MUTED_COLOR
          )
        end
      end

      # -----------------------------------------------------------------------
      # Helpers
      # -----------------------------------------------------------------------
      def _section_title(pdf, text)
        pdf.fill_color HEADER_COLOR
        pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 24
        pdf.fill_color 'FFFFFF'
        pdf.text_box text,
          at:    [4, pdf.cursor - 5],
          width: pdf.bounds.width,
          size:  12, style: :bold
        pdf.fill_color TEXT_COLOR
        pdf.move_down 30
      end

      def _fmt_currency(val)
        "#{@currency} #{'%,.2f' % val.to_f}"
      rescue
        val.to_s
      end

      def _fmt_qty(val)
        '#,.3f' % val.to_f
      rescue
        val.to_s
      end

      # -----------------------------------------------------------------------
      # HTML fallback — generates a self-contained HTML file printable to PDF
      # -----------------------------------------------------------------------
      def _export_html_fallback(output_path)
        html_path = output_path.sub('.pdf', '_rab.html')
        pi        = @doc.project_info || {}

        rows_html = @doc.sections.map do |section|
          items_html = section.items.map.with_index do |item, i|
            bg = i.odd? ? "background:#f5f9ff" : ''
            <<~ROW
              <tr style="#{bg}">
                <td class="c">#{item.no}</td>
                <td class="c">#{item.category_code}</td>
                <td>#{item.category_name}</td>
                <td class="c">#{item.unit}</td>
                <td class="r">#{_fmt_qty(item.quantity)}</td>
                <td class="r">#{_fmt_currency(item.unit_price)}</td>
                <td class="r">#{_fmt_currency(item.total_price)}</td>
              </tr>
            ROW
          end.join

          <<~SEC
            <tr class="section-hdr"><td colspan="7">#{section.group_label.upcase}</td></tr>
            #{items_html}
            <tr class="subtotal">
              <td colspan="6" class="r"><strong>Sub Total #{section.group_label}</strong></td>
              <td class="r"><strong>#{_fmt_currency(section.section_total)}</strong></td>
            </tr>
          SEC
        end.join

        html = <<~HTML
          <!DOCTYPE html><html lang="id"><head><meta charset="UTF-8">
          <title>RAB — #{pi[:name]}</title>
          <style>
            @page { size: A4; margin: 20mm 15mm; }
            * { box-sizing: border-box; font-family: Arial, sans-serif; }
            body { font-size: 10px; color: #1a1a1a; }
            h1 { font-size: 16px; text-align: center; margin: 0; color: #fff; background: #1F3864; padding: 12px; }
            h2 { font-size: 11px; text-align: center; background: #2E75B6; color: #fff; padding: 6px; margin: 0; }
            .info-table { width: 100%; border-collapse: collapse; margin: 12px 0; }
            .info-table td { padding: 4px 8px; border: 1px solid #ddd; }
            .info-table td:first-child { font-weight: bold; background: #D6E4F0; width: 150px; }
            table.rab { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 9px; }
            table.rab th { background: #1F3864; color: #fff; padding: 5px 4px; border: 1px solid #ccc; text-align: center; }
            table.rab td { padding: 4px; border: 1px solid #ddd; vertical-align: middle; }
            .section-hdr td { background: #D6E4F0; font-weight: bold; padding: 5px 8px; font-size: 10px; }
            .subtotal td { background: #e8f0ff; font-size: 9px; }
            .c { text-align: center; }
            .r { text-align: right; }
            .grand { background: #1F3864; color: #fff; font-weight: bold; font-size: 11px; }
            .terbilang { font-style: italic; font-size: 9px; color: #aa8800; padding: 6px; border: 1px dashed #ddd; margin-top: 6px; }
            @media print { .no-print { display: none; } }
          </style></head><body>
          <h1>RENCANA ANGGARAN BIAYA</h1>
          <h2>RAB Pro — SketchUp Extension</h2>
          <table class="info-table">
            <tr><td>Nama Proyek</td><td>#{pi[:name] || '-'}</td></tr>
            <tr><td>Pemilik</td><td>#{pi[:owner] || '-'}</td></tr>
            <tr><td>Lokasi</td><td>#{pi[:location] || '-'}</td></tr>
            <tr><td>Konsultan</td><td>#{pi[:consultant] || '-'}</td></tr>
            <tr><td>Tanggal</td><td>#{Time.now.strftime('%d %B %Y')}</td></tr>
          </table>
          <table class="rab">
            <thead><tr>
              <th>No</th><th>Kode</th><th>Uraian Pekerjaan</th><th>Sat</th>
              <th>Volume</th><th>Harga Satuan</th><th>Jumlah Harga</th>
            </tr></thead>
            <tbody>#{rows_html}
              <tr><td colspan="6" class="r grand">Sub Total Pekerjaan</td><td class="r grand">#{_fmt_currency(@doc.subtotal)}</td></tr>
              <tr><td colspan="6" class="r">Overhead (#{@doc.overhead_pct}%)</td><td class="r">#{_fmt_currency(@doc.overhead)}</td></tr>
              <tr><td colspan="6" class="r">Profit (#{@doc.profit_pct}%)</td><td class="r">#{_fmt_currency(@doc.profit)}</td></tr>
              <tr><td colspan="6" class="r">PPN (#{@doc.ppn_pct}%)</td><td class="r">#{_fmt_currency(@doc.ppn)}</td></tr>
              <tr><td colspan="6" class="r grand">TOTAL RENCANA ANGGARAN BIAYA</td><td class="r grand">#{_fmt_currency(@doc.grand_total)}</td></tr>
            </tbody>
          </table>
          <div class="terbilang">Terbilang: #{@doc.terbilang}</div>
          <p style="font-size:8px;color:#999;margin-top:20px;text-align:center">
            Dibuat oleh RAB Pro v#{RABPro::EXTENSION_VERSION} | #{Time.now.strftime('%d %B %Y %H:%M')}
          </p>
          <div class="no-print" style="margin-top:20px;text-align:center">
            <button onclick="window.print()" style="padding:8px 20px;background:#0071e3;color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:12px">
              🖨️ Cetak / Simpan sebagai PDF
            </button>
          </div>
          </body></html>
        HTML

        File.write(html_path, html, encoding: 'UTF-8')
        Logger.info("PDFExporter: HTML fallback saved → #{html_path}")
        { success: true, format: :html, path: html_path,
          message: 'Buka file HTML di browser dan gunakan Ctrl+P untuk simpan sebagai PDF.' }
      end

    end
  end
end
