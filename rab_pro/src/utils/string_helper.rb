# ==============================================================================
# RAB Pro - String Helper
# Normalisation, pattern matching, and display utilities
# ==============================================================================

module RABPro
  module StringHelper

    # Strip accents and lowercase — used for fuzzy layer name matching
    def self.normalize(str)
      return '' if str.nil?
      str.to_s.downcase.strip
             .gsub(/[àáâãäå]/, 'a').gsub(/[èéêë]/, 'e')
             .gsub(/[ìíîï]/, 'i').gsub(/[òóôõö]/, 'o')
             .gsub(/[ùúûü]/, 'u').gsub(/[ñ]/, 'n')
             .gsub(/[^a-z0-9\s_\-]/, '')
    end

    # Convert "dinding_bata_merah" → "Dinding Bata Merah"
    def self.humanize(str)
      normalize(str).split(/[\s_\-]+/).map(&:capitalize).join(' ')
    end

    # Truncate for display with ellipsis
    def self.truncate(str, max: 40)
      str = str.to_s
      str.length > max ? "#{str[0, max - 3]}..." : str
    end

    # Format currency
    def self.format_currency(amount, symbol: 'BND$', decimals: 2)
      formatted = '%.2f' % amount.to_f
      # Add thousand separators
      parts = formatted.split('.')
      parts[0] = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      "#{symbol} #{parts.join('.')}"
    end

    # Slugify for use as hash keys / file names
    def self.slugify(str)
      normalize(str).gsub(/\s+/, '_')
    end

    # Check if string matches any pattern in array (supports * wildcard)
    # Fixed: properly escape special regex characters before gsub
    def self.matches_any?(str, patterns)
      s = normalize(str)
      patterns.any? do |pat|
        # Normalize pattern first, then convert * to regex wildcard
        normalized_pattern = normalize(pat).gsub('*', '.*')
        /\A#{normalized_pattern}\z/.match?(s)
      end
    end

  end
end
