# ==============================================================================
# RAB Pro - RAB Calculator
# Takes QTO lines + harga satuan → full RAB document structure.
# Handles grouping by pekerjaan, rekapitulasi, overhead, profit, PPN.
# ==============================================================================

module RABPro
  module RAB
    class RABCalculator

      RABDocument = Struct.new(
        :project_info,
        :sections,          # Array of RABSection (grouped by pekerjaan)
        :rekapitulasi,      # summary per group
        :subtotal,
        :overhead,
        :overhead_pct,
        :profit,
        :profit_pct,
        :ppn,
        :ppn_pct,
        :grand_total,
        :terbilang,         # grand total in words (Indonesian)
        :generated_at,
        :qto_stats,
        keyword_init: true
      )

      RABSection = Struct.new(
        :group,
        :group_label,
        :items,             # Array of RABLineItem
        :section_total,
        keyword_init: true
      )

      RABLineItem = Struct.new(
        :no,
        :category_code,
        :category_name,
        :unit,
        :quantity,
        :unit_price,
        :total_price,
        :analisa,           # full analisa harga satuan breakdown
        :item_count,        # how many SketchUp entities contributed
        keyword_init: true
      )

      def initialize(model, project_store: nil, settings: nil)
        @model         = model
        @project_store = project_store
        @settings      = settings
      end

      # -----------------------------------------------------------------------
      # Generate complete RAB document
      # -----------------------------------------------------------------------
      def generate(overhead_pct: nil, profit_pct: nil, ppn_pct: nil)
        # Use project store values if available, else defaults
        ovh = overhead_pct || @project_store&.overhead_pct || 10.0
        pft = profit_pct   || @project_store&.profit_pct   || 10.0
        ppn = ppn_pct      || @project_store&.ppn_pct      || 11.0

        custom_prices = @project_store&.all_custom_prices || {}

        Logger.info("RABCalculator: generating with O=#{ovh}% P=#{pft}% PPN=#{ppn}%")

        # Step 1: Run QTO
        qto_engine = QuantityTakeoffEngine.new(
          @model,
          settings:      @settings,
          project_store: @project_store
        )

        rab_lines = qto_engine.build_rab_lines(
          custom_prices: custom_prices,
          overhead_pct:  ovh,
          profit_pct:    pft
        )

        qto_result = qto_engine.run

        # Step 2: Build sections grouped by pekerjaan group
        sections = _build_sections(rab_lines)

        # Step 3: Rekapitulasi
        rekap = _build_rekapitulasi(sections)

        # Step 4: Financial totals
        subtotal    = sections.sum(&:section_total)
        overhead    = subtotal * (ovh  / 100.0)
        profit_val  = subtotal * (pft  / 100.0)
        before_ppn  = subtotal + overhead + profit_val
        ppn_val     = before_ppn * (ppn / 100.0)
        grand_total = before_ppn + ppn_val

        RABDocument.new(
          project_info:   @project_store&.project_info&.to_h,
          sections:       sections,
          rekapitulasi:   rekap,
          subtotal:       subtotal.round(2),
          overhead:       overhead.round(2),
          overhead_pct:   ovh,
          profit:         profit_val.round(2),
          profit_pct:     pft,
          ppn:            ppn_val.round(2),
          ppn_pct:        ppn,
          grand_total:    grand_total.round(2),
          terbilang:      _terbilang(grand_total),
          generated_at:   Time.now.iso8601,
          qto_stats:      qto_result[:stats]
        )
      end

      # -----------------------------------------------------------------------
      # Serialise RAB document to a plain hash (for JSON / UI consumption)
      # -----------------------------------------------------------------------
      def self.document_to_hash(doc)
        {
          project_info:  doc.project_info,
          sections:      doc.sections.map { |s|
            {
              group:         s.group,
              group_label:   s.group_label,
              section_total: s.section_total,
              items: s.items.map { |i|
                {
                  no:            i.no,
                  category_code: i.category_code,
                  category_name: i.category_name,
                  unit:          i.unit,
                  quantity:      i.quantity,
                  unit_price:    i.unit_price,
                  total_price:   i.total_price,
                  item_count:    i.item_count
                }
              }
            }
          },
          rekapitulasi:  doc.rekapitulasi,
          subtotal:      doc.subtotal,
          overhead:      doc.overhead,
          overhead_pct:  doc.overhead_pct,
          profit:        doc.profit,
          profit_pct:    doc.profit_pct,
          ppn:           doc.ppn,
          ppn_pct:       doc.ppn_pct,
          grand_total:   doc.grand_total,
          terbilang:     doc.terbilang,
          generated_at:  doc.generated_at,
          qto_stats:     doc.qto_stats
        }
      end

      private

      # Group RAB lines by pekerjaan group in SNI order
      GROUP_ORDER = %i[
        persiapan tanah pondasi struktur dinding lantai
        atap plafon kusen finishing mep landscape lain
      ].freeze

      def _build_sections(rab_lines)
        grouped = rab_lines.group_by { |l| l[:group] }
        item_no  = 0
        sections = []

        GROUP_ORDER.each do |grp|
          lines = grouped[grp]
          next unless lines&.any?

          label = Data::CategoryLibrary.groups[grp] || grp.to_s.capitalize

          items = lines.map do |l|
            item_no += 1
            RABLineItem.new(
              no:            item_no,
              category_code: l[:category_code],
              category_name: l[:category_name],
              unit:          l[:unit],
              quantity:      l[:quantity],
              unit_price:    l[:unit_price],
              total_price:   l[:total_price],
              analisa:       l[:analisa],
              item_count:    l[:item_count]
            )
          end

          section_total = items.sum(&:total_price)
          sections << RABSection.new(
            group:         grp,
            group_label:   label,
            items:         items,
            section_total: section_total.round(2)
          )
        end

        # Append any remaining groups not in GROUP_ORDER
        remaining = grouped.reject { |k, _| GROUP_ORDER.include?(k) }
        remaining.each do |grp, lines|
          items = lines.map do |l|
            item_no += 1
            RABLineItem.new(
              no: item_no, category_code: l[:category_code],
              category_name: l[:category_name], unit: l[:unit],
              quantity: l[:quantity], unit_price: l[:unit_price],
              total_price: l[:total_price], analisa: l[:analisa],
              item_count: l[:item_count]
            )
          end
          sections << RABSection.new(
            group: grp, group_label: grp.to_s,
            items: items, section_total: items.sum(&:total_price).round(2)
          )
        end

        sections
      end

      def _build_rekapitulasi(sections)
        sections.map.with_index(1) do |s, i|
          {
            no:          i,
            group:       s.group,
            group_label: s.group_label,
            total:       s.section_total
          }
        end
      end

      # -----------------------------------------------------------------------
      # Terbilang — convert number to Indonesian words
      # Supports up to billions
      # -----------------------------------------------------------------------
      ONES = %w[nol satu dua tiga empat lima enam tujuh delapan sembilan
                sepuluh sebelas dua\ belas tiga\ belas empat\ belas lima\ belas
                enam\ belas tujuh\ belas delapan\ belas sembilan\ belas].freeze

      def _terbilang(amount)
        n = amount.to_i
        return 'nol' if n == 0

        words = ''
        words += _terbilang_group(n / 1_000_000_000) + ' miliar '  if n >= 1_000_000_000
        words += _terbilang_group((n % 1_000_000_000) / 1_000_000) + ' juta '  if n >= 1_000_000
        words += _terbilang_group((n % 1_000_000) / 1_000) + ' ribu '          if n >= 1_000
        words += _terbilang_group(n % 1_000)

        # Append cents
        cents = ((amount - n) * 100).round
        words += " dan #{cents} sen" if cents > 0

        "#{words.strip} #{@settings&.currency_symbol || 'BND$'}".strip
      end

      def _terbilang_group(n)
        return '' if n == 0
        if n < 20
          ONES[n]
        elsif n < 100
          tens = %w[_ _ dua\ puluh tiga\ puluh empat\ puluh lima\ puluh
                     enam\ puluh tujuh\ puluh delapan\ puluh sembilan\ puluh]
          "#{tens[n / 10]} #{ONES[n % 10]}".strip
        else
          h = n / 100 == 1 ? 'seratus' : "#{ONES[n / 100]} ratus"
          r = _terbilang_group(n % 100)
          r.empty? ? h : "#{h} #{r}"
        end
      end

    end
  end
end
