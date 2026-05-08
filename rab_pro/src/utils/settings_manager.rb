# ==============================================================================
# RAB Pro - Settings Manager
# Persists user preferences via Sketchup.read_default / write_default.
# Provides typed accessors with sensible defaults.
# ==============================================================================

module RABPro
  class SettingsManager

    NAMESPACE = 'RABPro'.freeze

    DEFAULTS = {
      # UI
      'panel_width'          => 480,
      'panel_height'         => 700,
      'panel_x'              => 100,
      'panel_y'              => 100,
      'ui_language'          => 'id',          # Indonesian default
      'theme'                => 'auto',        # auto | light | dark

      # Units
      'length_unit'          => 'm',
      'area_unit'            => 'm2',
      'volume_unit'          => 'm3',
      'currency'             => 'BND',         # Brunei Dollar
      'currency_symbol'      => 'BND$',

      # Tagging
      'auto_tag_on_open'     => false,
      'tag_by_layer'         => true,
      'tag_by_name_pattern'  => true,

      # AI
      'ai_enabled'           => true,
      'ai_model'             => 'claude-sonnet-4-20250514',
      'ai_context_depth'     => 3,             # how many tree levels to send

      # Export
      'export_path'          => '',
      'excel_template'       => 'default_rab',
      'pdf_paper_size'       => 'A3',
      'pdf_orientation'      => 'landscape',

      # Logging
      'log_level'            => 'info',
    }.freeze

    def initialize
      _apply_log_level
    end

    # --------------------------------------------------------------------------
    # Generic accessors
    # --------------------------------------------------------------------------

    def get(key, fallback = nil)
      stored = Sketchup.read_default(NAMESPACE, key.to_s)
      stored.nil? ? (fallback || DEFAULTS[key.to_s]) : stored
    end

    def set(key, value)
      Sketchup.write_default(NAMESPACE, key.to_s, value)
      _apply_log_level if key.to_s == 'log_level'
      value
    end

    def reset_to_defaults!
      DEFAULTS.each { |k, v| set(k, v) }
    end

    # --------------------------------------------------------------------------
    # Convenience typed readers
    # --------------------------------------------------------------------------

    def panel_geometry
      {
        width:  get('panel_width').to_i,
        height: get('panel_height').to_i,
        x:      get('panel_x').to_i,
        y:      get('panel_y').to_i
      }
    end

    def currency_symbol; get('currency_symbol') end
    def currency;        get('currency')        end
    def length_unit;     get('length_unit')     end
    def ai_enabled?;     get('ai_enabled') == true || get('ai_enabled') == 'true' end
    def ai_model;        get('ai_model')        end
    def export_path;     p = get('export_path'); p.empty? ? Dir.home : p end

    # --------------------------------------------------------------------------
    # Bulk export / import for settings dialog
    # --------------------------------------------------------------------------

    def to_hash
      DEFAULTS.keys.each_with_object({}) { |k, h| h[k] = get(k) }
    end

    def from_hash(hash)
      hash.each { |k, v| set(k, v) if DEFAULTS.key?(k.to_s) }
    end

    private

    def _apply_log_level
      RABPro::Logger.level = get('log_level', 'info').to_sym
    end

  end
end
