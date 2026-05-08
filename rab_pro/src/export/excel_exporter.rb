# ==============================================================================
# RAB Pro - Excel Exporter
# Generates a professional multi-sheet RAB workbook (.xlsx).
# Uses the 'write_xlsx' gem (bundled in the .rbz) which is pure Ruby
# and does not require Office/Excel installed.
#
# Sheets produced:
#   1. Cover      — project info, logo placeholder
#   2. RAB        — full bill of quantities with section headers
#   3. Rekapitulasi — summary sheet
#   4. Analisa HS — unit price analysis per category
#   5. QTO Detail — raw quantity takeoff table
# ==============================================================================

module RABPro
  module Export
    class ExcelExporter

      # Attempt to load write_xlsx gem bundled in extension
      begin
        require 'write_xlsx'
        GEM_AVAILABLE = true
      rescue LoadError
        GEM_AVAILABLE = false
      end

      CURRENCY_FMT   = '#,##0.00'
      QUANTITY_FMT   = '#,##0.000'
      HEADER_COLOR   = '1F3864'   # dark navy
      SUBHEAD_COLOR  = '2E75B6'   # medium blue
      GROUP_COLOR    = 'D6E4F0'   # light blue
      ALT_ROW_COLOR  = 'F5F9FF'   # very light blue
      SUCCESS_COLOR  = '2E7D32'
      WARNING_COLOR  = 'E65100'

      def initialize(rab_document, settings: nil, project_store: nil)
        @doc           = rab_document
        @settings      = settings
        @project_store = project_store
        @currency      = settings&.currency_symbol || 'BND$'
      end

      # -----------------------------------------------------------------------
      # Generate .xlsx and write to output_path
      # Returns true on success
      # -----------------------------------------------------------------------
      def export(output_path)
        unless GEM_AVAILABLE
          _export_csv_fallback(output_path)
          return { success: true, format: :csv, path: output_path.sub('.xlsx', '.csv') }
        end

        workbook = WriteXLSX.new(output_path)
        _define_formats(workbook)

        _write_cover_sheet(workbook)
        _write_rab_sheet(workbook)
        _write_rekap_sheet(workbook)
        _write_analisa_sheet(workbook)
        _write_qto_sheet(workbook)

        workbook.close
        Logger.info("ExcelExporter: saved → #{output_path}")
        { success: true, format: :xlsx, path: output_path }

      rescue => e
        Logger.error("ExcelExporter: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
        { success: false, error: e.message }
      end

      private

      # -----------------------------------------------------------------------
      # Format definitions
      # -----------------------------------------------------------------------
      def _define_formats(wb)
        @fmt = {}

        @fmt[:title] = wb.add_format(
          bold: 1, font_size: 16, color: 'white',
          bg_color: HEADER_COLOR, align: 'center', valign: 'vcenter',
          border: 1
        )
        @fmt[:subtitle] = wb.add_format(
          bold: 1, font_size: 12, color: 'white',
          bg_color: SUBHEAD_COLOR, align: 'center', valign: 'vcenter'
        )
        @fmt[:section_header] = wb.add_format(
          bold: 1, font_size: 11, bg_color: GROUP_COLOR,
          border: 1, align: 'left', valign: 'vcenter'
        )
        @fmt[:col_header] = wb.add_format(
          bold: 1, font_size: 10, color: 'white',
          bg_color: HEADER_COLOR, border: 1,
          align: 'center', valign: 'vcenter', text_wrap: 1
        )
        @fmt[:normal] = wb.add_format(
          font_size: 10, border: 1, valign: 'vcenter'
        )
        @fmt[:normal_alt] = wb.add_format(
          font_size: 10, border: 1, valign: 'vcenter',
          bg_color: ALT_ROW_COLOR
        )
        @fmt[:number] = wb.add_format(
          font_size: 10, border: 1, align: 'right',
          num_format: QUANTITY_FMT
        )
        @fmt[:number_alt] = wb.add_format(
          font_size: 10, border: 1, align: 'right',
          num_format: QUANTITY_FMT, bg_color: ALT_ROW_COLOR
        )
        @fmt[:currency] = wb.add_format(
          font_size: 10, border: 1, align: 'right',
          num_format: "\"#{@currency} \"#,##0.00"
        )
        @fmt[:currency_alt] = wb.add_format(
          font_size: 10, border: 1, align: 'right',
          num_format: "\"#{@currency} \"#,##0.00", bg_color: ALT_ROW_COLOR
        )
        @fmt[:currency_bold] = wb.add_format(
          bold: 1, font_size: 10, border: 2, align: 'right',
          num_format: "\"#{@currency} \"#,##0.00", bg_color: GROUP_COLOR
        )
        @fmt[:grand_total] = wb.add_format(
          bold: 1, font_size: 12, border: 2, align: 'right',
          num_format: "\"#{@currency} \"#,##0.00",
          bg_color: HEADER_COLOR, color: 'white'
        )
        @fmt[:center] = wb.add_format(
          font_size: 10, border: 1, align: 'center', valign: 'vcenter'
        )
        @fmt[:label_bold] = wb.add_format(
          bold: 1, font_size: 10, border: 1
        )
        @fmt[:terbilang] = wb.add_format(
          italic: 1, font_size: 10, border: 1,
          bg_color: 'FFF9C4', text_wrap: 1
        )
      end

      # -----------------------------------------------------------------------
      # Sheet 1: Cover
      # -----------------------------------------------------------------------
      def _write_cover_sheet(wb)
        ws = wb.add_worksheet('Cover')
        ws.set_column(0, 0, 30)
        ws.set_column(1, 1, 50)
        ws.set_row(0, 60)

        pi = @doc.project_info || {}

        ws.merge_range(0, 0, 0, 1, 'RENCANA ANGGARAN BIAYA', @fmt[:title])
        ws.merge_range(1, 0, 1, 1, 'RAB Pro — Generated by SketchUp Extension', @fmt[:subtitle])

        row = 3
        {
          'Nama Proyek'    => pi[:name]        || '-',
          'Pemilik'        => pi[:owner]       || '-',
          'Lokasi'         => pi[:location]    || '-',
          'Konsultan'      => pi[:consultant]  || '-',
          'Kontraktor'     => pi[:contractor]  || '-',
          'Tanggal Mulai'  => pi[:start_date]  || '-',
          'Tanggal Selesai'=> pi[:end_date]    || '-',
        }.each do |k, v|
          ws.write(row, 0, k, @fmt[:label_bold])
          ws.write(row, 1, v, @fmt[:normal])
          row += 1
        end

        row += 1
        ws.merge_range(row, 0, row, 1, 'RINGKASAN BIAYA', @fmt[:section_header])
        row += 1

        ws.write(row, 0, 'Sub Total Pekerjaan', @fmt[:label_bold])
        ws.write(row, 1, @doc.subtotal, @fmt[:currency_bold])
        row += 1
        ws.write(row, 0, "Overhead (#{@doc.overhead_pct}%)", @fmt[:normal])
        ws.write(row, 1, @doc.overhead, @fmt[:currency])
        row += 1
        ws.write(row, 0, "Profit (#{@doc.profit_pct}%)", @fmt[:normal])
        ws.write(row, 1, @doc.profit, @fmt[:currency])
        row += 1
        ws.write(row, 0, "PPN (#{@doc.ppn_pct}%)", @fmt[:normal])
        ws.write(row, 1, @doc.ppn, @fmt[:currency])
        row += 1
        ws.merge_range(row, 0, row, 0, 'TOTAL BIAYA PROYEK', @fmt[:grand_total])
        ws.write(row, 1, @doc.grand_total, @fmt[:grand_total])
        row += 1
        ws.merge_range(row, 0, row, 1, "Terbilang: #{@doc.terbilang}", @fmt[:terbilang])

        row += 2
        ws.write(row, 0, "Dibuat oleh: RAB Pro v#{EXTENSION_VERSION}", @fmt[:normal])
        ws.write(row, 1, "Tanggal: #{Time.now.strftime('%d %B %Y %H:%M')}", @fmt[:normal])
      end

      # -----------------------------------------------------------------------
      # Sheet 2: RAB (full BOQ)
      # -----------------------------------------------------------------------
      def _write_rab_sheet(wb)
        ws = wb.add_worksheet('RAB')

        # Column widths
        ws.set_column(0, 0, 5)    # No
        ws.set_column(1, 1, 8)    # Kode
        ws.set_column(2, 2, 40)   # Uraian Pekerjaan
        ws.set_column(3, 3, 8)    # Sat
        ws.set_column(4, 4, 12)   # Volume
        ws.set_column(5, 5, 18)   # Harga Satuan
        ws.set_column(6, 6, 20)   # Jumlah Harga
        ws.set_row(0, 45)

        ws.merge_range(0, 0, 0, 6, 'RENCANA ANGGARAN BIAYA', @fmt[:title])

        pi = @doc.project_info || {}
        ws.merge_range(1, 0, 1, 6,
          "Proyek: #{pi[:name] || '-'} | Lokasi: #{pi[:location] || '-'}",
          @fmt[:subtitle]
        )

        # Column headers
        row = 3
        ws.set_row(row, 30)
        headers = ['No', 'Kode', 'Uraian Pekerjaan', 'Sat', 'Volume', "Harga Satuan\n(#{@currency})", "Jumlah Harga\n(#{@currency})"]
        headers.each_with_index { |h, c| ws.write(row, c, h, @fmt[:col_header]) }
        row += 1

        # Data rows
        @doc.sections.each do |section|
          # Section header row
          ws.merge_range(row, 0, row, 6, section.group_label.upcase, @fmt[:section_header])
          row += 1

          alt = false
          section.items.each do |item|
            fmt_n = alt ? @fmt[:normal_alt]   : @fmt[:normal]
            fmt_r = alt ? @fmt[:number_alt]   : @fmt[:number]
            fmt_c = alt ? @fmt[:currency_alt] : @fmt[:currency]

            ws.write(row, 0, item.no,            fmt_n)
            ws.write(row, 1, item.category_code, fmt_n)
            ws.write(row, 2, item.category_name, fmt_n)
            ws.write(row, 3, item.unit,          @fmt[:center])
            ws.write(row, 4, item.quantity,      fmt_r)
            ws.write(row, 5, item.unit_price,    fmt_c)
            ws.write(row, 6, item.total_price,   fmt_c)

            alt = !alt
            row += 1
          end

          # Section subtotal
          ws.write(row, 0, '',  @fmt[:normal])
          ws.merge_range(row, 1, row, 5, "Sub Total #{section.group_label}", @fmt[:currency_bold])
          ws.write(row, 6, section.section_total, @fmt[:currency_bold])
          row += 2
        end

        # Grand total block
        row += 1
        [
          ["Sub Total Pekerjaan", @doc.subtotal],
          ["Overhead (#{@doc.overhead_pct}%)", @doc.overhead],
          ["Profit / Keuntungan (#{@doc.profit_pct}%)", @doc.profit],
          ["PPN (#{@doc.ppn_pct}%)", @doc.ppn],
        ].each do |label, val|
          ws.merge_range(row, 0, row, 5, label, @fmt[:label_bold])
          ws.write(row, 6, val, @fmt[:currency_bold])
          row += 1
        end

        ws.merge_range(row, 0, row, 5, 'TOTAL RENCANA ANGGARAN BIAYA', @fmt[:grand_total])
        ws.write(row, 6, @doc.grand_total, @fmt[:grand_total])
        row += 1
        ws.merge_range(row, 0, row, 6, "Terbilang: #{@doc.terbilang}", @fmt[:terbilang])
      end

      # -----------------------------------------------------------------------
      # Sheet 3: Rekapitulasi
      # -----------------------------------------------------------------------
      def _write_rekap_sheet(wb)
        ws = wb.add_worksheet('Rekapitulasi')
        ws.set_column(0, 0, 5)
        ws.set_column(1, 1, 50)
        ws.set_column(2, 2, 22)
        ws.set_row(0, 40)

        ws.merge_range(0, 0, 0, 2, 'REKAPITULASI RENCANA ANGGARAN BIAYA', @fmt[:title])

        row = 2
        ws.write(row, 0, 'No',          @fmt[:col_header])
        ws.write(row, 1, 'Uraian Pekerjaan', @fmt[:col_header])
        ws.write(row, 2, "Jumlah Harga (#{@currency})", @fmt[:col_header])
        row += 1

        @doc.rekapitulasi.each do |r|
          ws.write(row, 0, r[:no],          @fmt[:center])
          ws.write(row, 1, r[:group_label], @fmt[:normal])
          ws.write(row, 2, r[:total],       @fmt[:currency])
          row += 1
        end

        row += 1
        ws.write(row, 0, '', @fmt[:normal])
        ws.write(row, 1, "Sub Total Pekerjaan",      @fmt[:label_bold])
        ws.write(row, 2, @doc.subtotal,              @fmt[:currency_bold])
        row += 1
        ws.write(row, 1, "Overhead (#{@doc.overhead_pct}%)", @fmt[:normal])
        ws.write(row, 2, @doc.overhead,              @fmt[:currency])
        row += 1
        ws.write(row, 1, "Profit (#{@doc.profit_pct}%)", @fmt[:normal])
        ws.write(row, 2, @doc.profit,                @fmt[:currency])
        row += 1
        ws.write(row, 1, "PPN (#{@doc.ppn_pct}%)",  @fmt[:normal])
        ws.write(row, 2, @doc.ppn,                  @fmt[:currency])
        row += 1
        ws.write(row, 1, 'TOTAL',                   @fmt[:grand_total])
        ws.write(row, 2, @doc.grand_total,           @fmt[:grand_total])
        row += 1
        ws.merge_range(row, 0, row, 2, "Terbilang: #{@doc.terbilang}", @fmt[:terbilang])
      end

      # -----------------------------------------------------------------------
      # Sheet 4: Analisa Harga Satuan
      # -----------------------------------------------------------------------
      def _write_analisa_sheet(wb)
        ws = wb.add_worksheet('Analisa Harga Satuan')
        ws.set_column(0, 0, 30)
        ws.set_column(1, 1, 8)
        ws.set_column(2, 2, 10)
        ws.set_column(3, 3, 16)
        ws.set_column(4, 4, 16)
        ws.set_row(0, 40)

        ws.merge_range(0, 0, 0, 4, 'ANALISA HARGA SATUAN PEKERJAAN', @fmt[:title])
        row = 2

        @doc.sections.each do |section|
          section.items.each do |item|
            next unless item.analisa

            a = item.analisa

            ws.merge_range(row, 0, row, 4,
              "#{a[:code]} — #{a[:name]} (per #{a[:unit]})",
              @fmt[:section_header]
            )
            row += 1

            ws.write(row, 0, 'Uraian',         @fmt[:col_header])
            ws.write(row, 1, 'Sat',            @fmt[:col_header])
            ws.write(row, 2, 'Koefisien',      @fmt[:col_header])
            ws.write(row, 3, "Harga (#{@currency})", @fmt[:col_header])
            ws.write(row, 4, "Jumlah (#{@currency})", @fmt[:col_header])
            row += 1

            # Group by type
            [:material, :upah, :alat].each do |type|
              items_of_type = a[:line_items].select { |li| li[:type] == type }
              next if items_of_type.empty?

              label = { material: 'Material', upah: 'Upah Tenaga', alat: 'Peralatan' }[type]
              ws.merge_range(row, 0, row, 4, label, @fmt[:subtitle])
              row += 1

              items_of_type.each do |li|
                ws.write(row, 0, li[:item].to_s.tr('_', ' ').capitalize, @fmt[:normal])
                ws.write(row, 1, li[:satuan], @fmt[:center])
                ws.write(row, 2, li[:koef],   @fmt[:number])
                ws.write(row, 3, li[:harga],  @fmt[:currency])
                ws.write(row, 4, li[:jumlah], @fmt[:currency])
                row += 1
              end
            end

            # Totals
            [
              ['Jumlah Material',    a[:material_total]],
              ['Jumlah Upah',        a[:labor_total]],
              ['Jumlah Peralatan',   a[:equipment_total]],
              ['Sub Total',          a[:subtotal]],
              ["Overhead (#{a[:overhead_pct]}%)", a[:overhead]],
              ["Profit (#{a[:profit_pct]}%)",     a[:profit]],
              ['Harga Satuan Pekerjaan', a[:grand_total]],
            ].each do |label, val|
              bold = label.start_with?('Harga Satuan')
              ws.write(row, 3, label, bold ? @fmt[:label_bold] : @fmt[:normal])
              ws.write(row, 4, val,   bold ? @fmt[:currency_bold] : @fmt[:currency])
              row += 1
            end

            row += 1
          end
        end
      end

      # -----------------------------------------------------------------------
      # Sheet 5: QTO Detail
      # -----------------------------------------------------------------------
      def _write_qto_sheet(wb)
        ws = wb.add_worksheet('Detail QTO')
        ws.set_column(0, 0, 8)
        ws.set_column(1, 1, 35)
        ws.set_column(2, 2, 25)
        ws.set_column(3, 3, 15)
        ws.set_column(4, 4, 12)
        ws.set_column(5, 5, 12)
        ws.set_column(6, 6, 12)
        ws.set_column(7, 7, 12)
        ws.set_column(8, 8, 10)
        ws.set_row(0, 40)

        ws.merge_range(0, 0, 0, 8, 'DETAIL QUANTITY TAKE-OFF', @fmt[:title])

        row = 2
        headers = ['Kode', 'Nama Entitas', 'Layer', 'Kategori Pekerjaan',
                   'Vol (m³)', 'Luas (m²)', 'Qty', 'Satuan', 'Override?']
        headers.each_with_index { |h, c| ws.write(row, c, h, @fmt[:col_header]) }
        row += 1

        @doc.sections.each do |section|
          section.items.each do |item|
            next unless item.analisa

            # We don't store individual QTO items in RABDocument, so just show summary
            ws.write(row, 0, item.category_code, @fmt[:normal])
            ws.write(row, 1, item.category_name, @fmt[:normal])
            ws.write(row, 2, '',                 @fmt[:normal])
            ws.write(row, 3, item.category_name, @fmt[:normal])
            ws.write(row, 4, '',                 @fmt[:number])
            ws.write(row, 5, '',                 @fmt[:number])
            ws.write(row, 6, item.quantity,      @fmt[:number])
            ws.write(row, 7, item.unit,          @fmt[:center])
            ws.write(row, 8, '',                 @fmt[:center])
            row += 1
          end
        end

        # Stats
        row += 2
        if @doc.qto_stats
          ws.write(row, 0, 'Generated at',  @fmt[:label_bold])
          ws.write(row, 1, @doc.generated_at, @fmt[:normal])
          row += 1
          ws.write(row, 0, 'Items',         @fmt[:label_bold])
          ws.write(row, 1, @doc.qto_stats[:total_items].to_s, @fmt[:normal])
          row += 1
          ws.write(row, 0, 'Categories',    @fmt[:label_bold])
          ws.write(row, 1, @doc.qto_stats[:categories_hit].to_s, @fmt[:normal])
        end
      end

      # -----------------------------------------------------------------------
      # CSV fallback when write_xlsx gem is not available
      # -----------------------------------------------------------------------
      def _export_csv_fallback(output_path)
        csv_path = output_path.sub('.xlsx', '_rab.csv')
        require 'csv'

        CSV.open(csv_path, 'w', encoding: 'UTF-8') do |csv|
          csv << ['No', 'Kode', 'Uraian Pekerjaan', 'Satuan', 'Volume', 'Harga Satuan', 'Jumlah Harga']

          @doc.sections.each do |section|
            csv << ['', '', section.group_label.upcase, '', '', '', '']
            section.items.each do |item|
              csv << [item.no, item.category_code, item.category_name,
                      item.unit, item.quantity, item.unit_price, item.total_price]
            end
            csv << ['', '', "Sub Total #{section.group_label}", '', '', '', section.section_total]
          end

          csv << []
          csv << ['', '', 'Sub Total', '', '', '', @doc.subtotal]
          csv << ['', '', "Overhead #{@doc.overhead_pct}%", '', '', '', @doc.overhead]
          csv << ['', '', "Profit #{@doc.profit_pct}%", '', '', '', @doc.profit]
          csv << ['', '', "PPN #{@doc.ppn_pct}%", '', '', '', @doc.ppn]
          csv << ['', '', 'TOTAL', '', '', '', @doc.grand_total]
          csv << ['', '', @doc.terbilang]
        end

        Logger.info("ExcelExporter: CSV fallback saved → #{csv_path}")
        csv_path
      end

    end
  end
end
