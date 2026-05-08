# ==============================================================================
# RAB Pro - Unit Converter
# Converts between SketchUp native inches and construction units (SI/Imperial)
# ==============================================================================

module RABPro
  module UnitConverter

    # SketchUp stores everything in inches internally
    INCH_TO_MM    = 25.4
    INCH_TO_CM    = 2.54
    INCH_TO_M     = 0.0254
    INCH_TO_FEET  = 1.0 / 12.0

    SQ_INCH_TO_M2 = INCH_TO_M ** 2
    CU_INCH_TO_M3 = INCH_TO_M ** 3

    class << self

      # ---- Linear ------------------------------------------------------------

      def inches_to_m(val);    (val * INCH_TO_M).round(4)   end
      def inches_to_cm(val);   (val * INCH_TO_CM).round(3)  end
      def inches_to_mm(val);   (val * INCH_TO_MM).round(2)  end
      def inches_to_feet(val); (val * INCH_TO_FEET).round(4) end

      def m_to_inches(val);    val / INCH_TO_M  end

      # ---- Area --------------------------------------------------------------

      def sq_inches_to_m2(val); (val * SQ_INCH_TO_M2).round(4) end
      def sq_inches_to_cm2(val); (val * SQ_INCH_TO_M2 * 10_000).round(2) end

      # ---- Volume ------------------------------------------------------------

      def cu_inches_to_m3(val); (val * CU_INCH_TO_M3).round(5) end
      def cu_inches_to_liters(val); cu_inches_to_m3(val) * 1_000 end

      # ---- Format display strings --------------------------------------------

      # Returns human-readable string with unit label
      def format_length(inches, unit: :m)
        case unit
        when :m   then "#{'%.3f' % inches_to_m(inches)} m"
        when :cm  then "#{'%.2f' % inches_to_cm(inches)} cm"
        when :mm  then "#{'%.1f' % inches_to_mm(inches)} mm"
        when :ft  then "#{'%.2f' % inches_to_feet(inches)} ft"
        else "#{'%.3f' % inches_to_m(inches)} m"
        end
      end

      def format_area(sq_inches, unit: :m2)
        "#{'%.3f' % sq_inches_to_m2(sq_inches)} m²"
      end

      def format_volume(cu_inches, unit: :m3)
        "#{'%.4f' % cu_inches_to_m3(cu_inches)} m³"
      end

      # ---- Unit symbol lookup ------------------------------------------------

      def symbol_for(quantity)
        { linear: 'm', area: 'm²', volume: 'm³', count: 'unit', weight: 'kg' }[quantity.to_sym] || '-'
      end

    end
  end
end
