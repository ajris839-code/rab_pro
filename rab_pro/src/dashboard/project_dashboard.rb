# ==============================================================================
# RAB Pro - Project Dashboard
# Tracks real-time project metrics:
#   - Budget vs actual spending
#   - Work progress per category (% complete)
#   - Material schedule (BOM)
#   - S-curve progress data
#   - Milestone tracking
# Data persisted in model attribute dictionary.
# ==============================================================================

module RABPro
  module Dashboard
    class ProjectDashboard

      DICT = 'RABPro_Dashboard'.freeze

      ProgressEntry = Struct.new(
        :category_id,
        :category_name,
        :planned_qty,
        :actual_qty,
        :unit,
        :planned_cost,
        :actual_cost,
        :pct_complete,
        :last_updated,
        keyword_init: true
      )

      Milestone = Struct.new(
        :id, :name, :planned_date, :actual_date, :status,
        keyword_init: true
      )

      def initialize(model, project_store: nil)
        @model         = model
        @project_store = project_store
      end

      # -----------------------------------------------------------------------
      # Build full dashboard snapshot
      # -----------------------------------------------------------------------
      def snapshot
        progress   = load_progress
        milestones = load_milestones
        rab_lines  = _load_rab_lines

        budget_total   = rab_lines.sum { |l| l[:total_price].to_f }
        actual_total   = progress.sum(&:actual_cost)
        pct_budget     = budget_total > 0 ? (actual_total / budget_total * 100).round(1) : 0

        overall_pct = progress.empty? ? 0 :
          (progress.sum(&:pct_complete) / progress.size).round(1)

        {
          project_info:   @project_store&.project_info&.to_h,
          generated_at:   Time.now.iso8601,

          # Financial summary
          budget_total:   budget_total.round(2),
          actual_total:   actual_total.round(2),
          remaining:      (budget_total - actual_total).round(2),
          pct_spent:      pct_budget,

          # Progress
          overall_pct:    overall_pct,
          progress:       progress.map(&:to_h),

          # S-curve data (weekly buckets)
          scurve:         _build_scurve(progress, budget_total),

          # Milestones
          milestones:     milestones.map(&:to_h),

          # Material schedule (BOM)
          bom:            _build_bom,

          # Category breakdown for pie chart
          category_breakdown: _category_breakdown(rab_lines, progress),

          # Alerts
          alerts:         _build_alerts(progress, milestones, budget_total, actual_total)
        }
      end

      # -----------------------------------------------------------------------
      # Progress tracking
      # -----------------------------------------------------------------------
      def load_progress
        dict = @model.attribute_dictionary(DICT)
        return [] unless dict

        entries = []
        dict.each do |key, val|
          next unless key.start_with?('progress_')
          begin
            h = JSON.parse(val)
            entries << ProgressEntry.new(**h.transform_keys(&:to_sym))
          rescue => e
            Logger.warn("Dashboard.load_progress #{key}: #{e.message}")
          end
        end
        entries.sort_by(&:category_id)
      end

      def update_progress(category_id, actual_qty:, actual_cost:, pct_complete:)
        rab_lines = _load_rab_lines
        rab_line  = rab_lines.find { |l| l[:category_id].to_s == category_id.to_s }

        entry = ProgressEntry.new(
          category_id:   category_id.to_s,
          category_name: rab_line&.dig(:category_name) || category_id.to_s,
          planned_qty:   rab_line&.dig(:quantity).to_f,
          actual_qty:    actual_qty.to_f,
          unit:          rab_line&.dig(:unit) || '-',
          planned_cost:  rab_line&.dig(:total_price).to_f,
          actual_cost:   actual_cost.to_f,
          pct_complete:  [[pct_complete.to_f, 0].max, 100].min,
          last_updated:  Time.now.iso8601
        )

        key = "progress_#{category_id}"
        @model.set_attribute(DICT, key, JSON.generate(entry.to_h))
        entry
      end

      def initialize_progress_from_rab
        rab_lines = _load_rab_lines
        rab_lines.each do |line|
          key = "progress_#{line[:category_id]}"
          next if @model.get_attribute(DICT, key)   # don't overwrite existing

          entry = ProgressEntry.new(
            category_id:   line[:category_id].to_s,
            category_name: line[:category_name],
            planned_qty:   line[:quantity].to_f,
            actual_qty:    0.0,
            unit:          line[:unit],
            planned_cost:  line[:total_price].to_f,
            actual_cost:   0.0,
            pct_complete:  0.0,
            last_updated:  Time.now.iso8601
          )
          @model.set_attribute(DICT, key, JSON.generate(entry.to_h))
        end
      end

      # -----------------------------------------------------------------------
      # Milestones
      # -----------------------------------------------------------------------
      def load_milestones
        raw = @model.get_attribute(DICT, 'milestones')
        return _default_milestones unless raw

        JSON.parse(raw).map do |m|
          Milestone.new(**m.transform_keys(&:to_sym))
        end
      rescue
        _default_milestones
      end

      def save_milestones(milestones)
        data = milestones.map do |m|
          m.is_a?(Hash) ? m : m.to_h
        end
        @model.set_attribute(DICT, 'milestones', JSON.generate(data))
      end

      def update_milestone(id, actual_date: nil, status: nil)
        milestones = load_milestones
        ms = milestones.find { |m| m.id == id }
        return nil unless ms

        ms.actual_date = actual_date if actual_date
        ms.status      = status      if status
        save_milestones(milestones)
        ms
      end

      private

      # -----------------------------------------------------------------------
      # S-Curve: build weekly cumulative progress data
      # -----------------------------------------------------------------------
      def _build_scurve(progress, budget_total)
        pi = @project_store&.project_info&.to_h || {}
        start_str = pi[:start_date]
        end_str   = pi[:end_date]

        # Generate 12-week buckets
        weeks   = 12
        planned = []
        actual  = []

        weeks.times do |i|
          pct_plan = _scurve_pct(i + 1, weeks)   # S-curve formula
          planned << {
            week:   i + 1,
            label:  "Minggu #{i + 1}",
            value:  (pct_plan * budget_total / 100).round(2),
            pct:    pct_plan.round(1)
          }
        end

        # Actual: distribute based on progress entries with last_updated dates
        current_week = _current_week(start_str)
        cumulative   = 0.0

        weeks.times do |i|
          if i < current_week
            # Proportional fill of actual spending
            week_actual = (actual_total_spent(progress) / [current_week, 1].max).round(2)
            cumulative  += week_actual
          end
          actual << {
            week:  i + 1,
            value: [cumulative, budget_total].min.round(2),
            pct:   budget_total > 0 ? (cumulative / budget_total * 100).round(1) : 0
          }
        end

        { planned: planned, actual: actual, weeks: weeks }
      end

      # Classic S-curve formula: cumulative Beta distribution approximation
      def _scurve_pct(week, total_weeks)
        x = week.to_f / total_weeks
        # Logistic S-curve
        100.0 / (1 + Math.exp(-10 * (x - 0.5)))
      end

      def _current_week(start_str)
        return 0 unless start_str && !start_str.empty?
        start_date = Date.parse(start_str) rescue Date.today
        ((Date.today - start_date) / 7).to_i.clamp(0, 12)
      rescue
        0
      end

      def actual_total_spent(progress)
        progress.sum(&:actual_cost)
      end

      # -----------------------------------------------------------------------
      # Bill of Materials
      # -----------------------------------------------------------------------
      def _build_bom
        rab_lines = _load_rab_lines
        hs_db     = RAB::HargaSatuanDatabase

        material_totals = Hash.new(0.0)
        material_info   = {}

        rab_lines.each do |line|
          hs = hs_db.find(line[:category_id])
          next unless hs

          qty = line[:quantity].to_f
          hs.koefisien.select { |k| k[:type] == :material }.each do |k|
            key = k[:item]
            material_totals[key] += k[:koef] * qty
            material_info[key]   ||= {
              name:   key.to_s.tr('_', ' ').split.map(&:capitalize).join(' '),
              satuan: k[:satuan],
              price:  RAB::HargaSatuanDatabase.price_for_item(key)
            }
          end
        end

        material_totals.map do |key, total_qty|
          info  = material_info[key]
          price = info[:price]
          {
            item:       key,
            name:       info[:name],
            satuan:     info[:satuan],
            quantity:   total_qty.round(3),
            unit_price: price,
            total:      (total_qty * price).round(2)
          }
        end.sort_by { |m| -m[:total] }
      end

      # -----------------------------------------------------------------------
      # Category breakdown for charts
      # -----------------------------------------------------------------------
      def _category_breakdown(rab_lines, progress)
        groups = Data::CategoryLibrary.groups

        by_group = rab_lines.group_by { |l| l[:group] }
        by_group.map do |grp, lines|
          actual_cost = progress
            .select { |p| lines.map { |l| l[:category_id].to_s }.include?(p.category_id) }
            .sum(&:actual_cost)

          {
            group:        grp,
            group_label:  groups[grp] || grp.to_s,
            planned:      lines.sum { |l| l[:total_price].to_f }.round(2),
            actual:       actual_cost.round(2),
            item_count:   lines.size
          }
        end.sort_by { |g| -g[:planned] }
      end

      # -----------------------------------------------------------------------
      # Build alerts / warnings
      # -----------------------------------------------------------------------
      def _build_alerts(progress, milestones, budget, actual)
        alerts = []

        # Over budget warning
        if budget > 0 && actual > budget * 0.85
          pct = (actual / budget * 100).round(1)
          alerts << {
            level:   :warning,
            title:   'Anggaran Mendekati Batas',
            message: "Pengeluaran aktual #{pct}% dari anggaran total",
            icon:    '⚠️'
          }
        end

        # Over budget
        if actual > budget
          alerts << {
            level:   :danger,
            title:   'Melebihi Anggaran!',
            message: "Pengeluaran aktual melebihi RAB sebesar #{_fmt_currency(actual - budget)}",
            icon:    '🚨'
          }
        end

        # Overdue milestones
        overdue = milestones.select do |m|
          m.status != :completed &&
          m.planned_date && !m.planned_date.empty? &&
          (Date.parse(m.planned_date) rescue nil)&.<(Date.today)
        end
        overdue.each do |m|
          alerts << {
            level:   :warning,
            title:   "Milestone Terlambat",
            message: "#{m.name} seharusnya selesai #{m.planned_date}",
            icon:    '📅'
          }
        end

        # Zero progress on started project
        if progress.any? && progress.all? { |p| p.pct_complete == 0 }
          alerts << {
            level:   :info,
            title:   'Progress Belum Diisi',
            message: 'Update progress pekerjaan untuk melihat laporan aktual',
            icon:    'ℹ️'
          }
        end

        alerts
      end

      # -----------------------------------------------------------------------
      # Default milestones
      # -----------------------------------------------------------------------
      def _default_milestones
        [
          Milestone.new(id: 'ms1', name: 'Kick-off Proyek',        planned_date: '', actual_date: nil, status: 'pending'),
          Milestone.new(id: 'ms2', name: 'Selesai Pekerjaan Tanah', planned_date: '', actual_date: nil, status: 'pending'),
          Milestone.new(id: 'ms3', name: 'Selesai Pondasi',         planned_date: '', actual_date: nil, status: 'pending'),
          Milestone.new(id: 'ms4', name: 'Selesai Struktur',        planned_date: '', actual_date: nil, status: 'pending'),
          Milestone.new(id: 'ms5', name: 'Selesai Atap',            planned_date: '', actual_date: nil, status: 'pending'),
          Milestone.new(id: 'ms6', name: 'Selesai Finishing',       planned_date: '', actual_date: nil, status: 'pending'),
          Milestone.new(id: 'ms7', name: 'Serah Terima (PHO)',       planned_date: '', actual_date: nil, status: 'pending'),
        ]
      end

      def _load_rab_lines
        raw = @model.get_attribute(DICT, 'cached_rab_lines')
        return [] unless raw
        JSON.parse(raw).map { |l| l.transform_keys(&:to_sym) }
      rescue
        []
      end

      def _fmt_currency(val)
        "BND$ #{('%.2f' % val.to_f).reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      end

    end
  end
end
