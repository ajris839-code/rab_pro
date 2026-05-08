# ==============================================================================
# RAB Pro - Project Store
# Manages per-project data: project info, custom harga satuan,
# and serialization to/from model attribute dictionaries.
# ==============================================================================

module RABPro
  class ProjectStore

    DICT = 'RABPro_Project'.freeze

    ProjectInfo = Struct.new(
      :name, :owner, :location, :consultant, :contractor,
      :start_date, :end_date, :description, :created_at,
      keyword_init: true
    )

    def initialize(settings)
      @settings = settings
      @model    = nil
    end

    # Attach to a new SketchUp model
    def attach(model)
      @model = model
      Logger.info("ProjectStore: attached to '#{model.path}'")
    end

    # --------------------------------------------------------------------------
    # Project Info
    # --------------------------------------------------------------------------

    def project_info
      return nil unless @model
      raw = @model.get_attribute(DICT, 'info')
      return nil unless raw
      begin
        data = JSON.parse(raw)
        ProjectInfo.new(**data.transform_keys(&:to_sym))
      rescue => e
        Logger.warn("ProjectStore: could not parse project info: #{e.message}")
        nil
      end
    end

    def save_project_info(attrs)
      return unless @model
      info = {
        name:        attrs[:name]       || 'Proyek Baru',
        owner:       attrs[:owner]      || '',
        location:    attrs[:location]   || '',
        consultant:  attrs[:consultant] || '',
        contractor:  attrs[:contractor] || '',
        start_date:  attrs[:start_date] || '',
        end_date:    attrs[:end_date]   || '',
        description: attrs[:description] || '',
        created_at:  attrs[:created_at] || Time.now.iso8601
      }
      @model.set_attribute(DICT, 'info', JSON.generate(info))
      Logger.info("ProjectStore: project info saved for '#{info[:name]}'")
    end

    # --------------------------------------------------------------------------
    # Harga Satuan (unit prices) — stored per model
    # Overrides the global price database for this specific project
    # --------------------------------------------------------------------------

    def price_for(category_id)
      return nil unless @model
      raw = @model.get_attribute(DICT, "price_#{category_id}")
      raw ? raw.to_f : nil
    end

    def set_price(category_id, price)
      return unless @model
      @model.set_attribute(DICT, "price_#{category_id}", price.to_f)
    end

    def all_custom_prices
      return {} unless @model
      dict = @model.attribute_dictionary(DICT)
      return {} unless dict

      prices = {}
      dict.each do |key, val|
        prices[$1.to_sym] = val.to_f if key =~ /\Aprice_(.+)\z/
      end
      prices
    end

    # --------------------------------------------------------------------------
    # Overhead & Profit settings (per project)
    # --------------------------------------------------------------------------

    def overhead_pct
      return 10.0 unless @model
      (@model.get_attribute(DICT, 'overhead_pct') || 10.0).to_f
    end

    def profit_pct
      return 10.0 unless @model
      (@model.get_attribute(DICT, 'profit_pct') || 10.0).to_f
    end

    def ppn_pct
      return 11.0 unless @model
      (@model.get_attribute(DICT, 'ppn_pct') || 11.0).to_f
    end

    def save_financial_settings(overhead:, profit:, ppn:)
      return unless @model
      @model.set_attribute(DICT, 'overhead_pct', overhead.to_f)
      @model.set_attribute(DICT, 'profit_pct',   profit.to_f)
      @model.set_attribute(DICT, 'ppn_pct',      ppn.to_f)
    end

    # --------------------------------------------------------------------------
    # Export full project data as hash (for JSON / backup)
    # --------------------------------------------------------------------------

    def to_hash
      {
        project_info:      project_info&.to_h,
        custom_prices:     all_custom_prices,
        overhead_pct:      overhead_pct,
        profit_pct:        profit_pct,
        ppn_pct:           ppn_pct,
        tag_export:        Tagger::TagEngine.export_tags(@model),
        exported_at:       Time.now.iso8601,
        rab_pro_version:   EXTENSION_VERSION
      }
    rescue => e
      Logger.error("ProjectStore.to_hash: #{e.message}")
      {}
    end

    private

    def _require_model!
      raise 'No model attached to ProjectStore' unless @model
    end

  end
end
