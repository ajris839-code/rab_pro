# ==============================================================================
# RAB Pro - Drawing Register
# Manages the full drawing register: numbering, revisions, status tracking.
# Data persisted in model attribute dictionary so it travels with the .skp file.
# ==============================================================================

module RABPro
  module Drawings
    class DrawingRegister

      DICT = 'RABPro_Drawings'.freeze

      DrawingEntry = Struct.new(
        :drawing_no,      # e.g. "A-01"
        :discipline,      # :architecture | :structure | :mep
        :title,           # drawing title
        :scale,           # e.g. "1:100"
        :scene_name,      # linked SketchUp scene
        :status,          # :draft | :issued_for_review | :issued_for_construction | :superseded
        :revision,        # current revision letter: 'A', 'B', ...
        :revisions,       # array of { rev:, date:, description:, issued_by: }
        :created_at,
        :updated_at,
        keyword_init: true
      )

      DISCIPLINES = {
        architecture: { prefix: 'A', label: 'Arsitektur' },
        structure:    { prefix: 'S', label: 'Struktur' },
        mep:          { prefix: 'M', label: 'MEP' },
        landscape:    { prefix: 'L', label: 'Landscape' },
        civil:        { prefix: 'C', label: 'Sipil' }
      }.freeze

      STATUS_LABELS = {
        draft:                    'Draft',
        issued_for_review:        'For Review (FR)',
        issued_for_construction:  'For Construction (FC)',
        superseded:               'Superseded'
      }.freeze

      def initialize(model)
        @model = model
      end

      # -----------------------------------------------------------------------
      # Add a new drawing entry
      # -----------------------------------------------------------------------
      def add(title:, discipline: :architecture, scale: '1:100', scene_name: nil)
        no    = _next_drawing_no(discipline)
        entry = DrawingEntry.new(
          drawing_no:  no,
          discipline:  discipline,
          title:       title,
          scale:       scale,
          scene_name:  scene_name,
          status:      :draft,
          revision:    nil,
          revisions:   [],
          created_at:  Time.now.iso8601,
          updated_at:  Time.now.iso8601
        )
        _save(entry)
        entry
      end

      # -----------------------------------------------------------------------
      # Issue a revision for a drawing
      # -----------------------------------------------------------------------
      def issue_revision(drawing_no, description:, issued_by:, status: :issued_for_review)
        entry = find(drawing_no)
        raise "Drawing #{drawing_no} not found" unless entry

        # Next revision letter
        next_rev = entry.revision ? (entry.revision.ord + 1).chr : 'A'

        rev_record = {
          rev:         next_rev,
          date:        Time.now.strftime('%d/%m/%Y'),
          description: description,
          issued_by:   issued_by,
          status:      status
        }

        entry.revisions  << rev_record
        entry.revision    = next_rev
        entry.status      = status
        entry.updated_at  = Time.now.iso8601

        _save(entry)
        entry
      end

      # -----------------------------------------------------------------------
      # Find a drawing by number
      # -----------------------------------------------------------------------
      def find(drawing_no)
        key = "drawing_#{drawing_no.gsub('-', '_')}"
        raw = @model.get_attribute(DICT, key)
        return nil unless raw
        _deserialize(JSON.parse(raw))
      rescue => e
        Logger.warn("DrawingRegister.find: #{e.message}")
        nil
      end

      # -----------------------------------------------------------------------
      # All drawings
      # -----------------------------------------------------------------------
      def all
        dict = @model.attribute_dictionary(DICT)
        return [] unless dict

        dict.each_with_object([]) do |(key, val), arr|
          next unless key.start_with?('drawing_')
          begin
            arr << _deserialize(JSON.parse(val))
          rescue => e
            Logger.warn("DrawingRegister.all: #{key} — #{e.message}")
          end
        end.sort_by(&:drawing_no)
      end

      # -----------------------------------------------------------------------
      # Group by discipline
      # -----------------------------------------------------------------------
      def by_discipline
        all.group_by(&:discipline)
      end

      # -----------------------------------------------------------------------
      # Update status
      # -----------------------------------------------------------------------
      def update_status(drawing_no, status)
        entry = find(drawing_no)
        return nil unless entry
        entry.status     = status.to_sym
        entry.updated_at = Time.now.iso8601
        _save(entry)
        entry
      end

      # -----------------------------------------------------------------------
      # Delete a drawing record
      # -----------------------------------------------------------------------
      def delete(drawing_no)
        key = "drawing_#{drawing_no.gsub('-', '_')}"
        @model.delete_attribute(DICT, key)
      end

      # -----------------------------------------------------------------------
      # Export register as hash array (for UI / Excel)
      # -----------------------------------------------------------------------
      def to_table
        all.map do |e|
          {
            drawing_no:  e.drawing_no,
            discipline:  DISCIPLINES[e.discipline]&.fetch(:label, e.discipline.to_s),
            title:       e.title,
            scale:       e.scale,
            scene:       e.scene_name,
            revision:    e.revision || '—',
            status:      STATUS_LABELS[e.status] || e.status.to_s,
            updated_at:  e.updated_at
          }
        end
      end

      # -----------------------------------------------------------------------
      # Initialise register from LayoutAutomation::SHEET_CONFIG
      # -----------------------------------------------------------------------
      def populate_from_sheet_config
        require_relative '../layout/layout_automation'
        Layout::LayoutAutomation::SHEET_CONFIG.each do |cfg|
          next if cfg[:id] == :cover
          next if find(cfg[:title])

          disc = cfg[:title].start_with?('S') ? :structure :
                 cfg[:title].start_with?('M') ? :mep : :architecture

          add(
            title:      cfg[:description],
            discipline: disc,
            scale:      cfg[:scale] || '1:100',
            scene_name: cfg[:scene]
          )
        end
      end

      private

      def _next_drawing_no(discipline)
        prefix  = DISCIPLINES[discipline]&.fetch(:prefix, 'X') || 'X'
        existing = all.select { |e| e.discipline == discipline }
        seq      = (existing.size + 1).to_s.rjust(2, '0')
        "#{prefix}-#{seq}"
      end

      def _save(entry)
        key = "drawing_#{entry.drawing_no.gsub('-', '_')}"
        @model.set_attribute(DICT, key, JSON.generate(_serialize(entry)))
      end

      def _serialize(entry)
        entry.to_h.transform_values do |v|
          v.is_a?(Symbol) ? v.to_s : v
        end
      end

      def _deserialize(hash)
        DrawingEntry.new(
          drawing_no:  hash['drawing_no'],
          discipline:  hash['discipline']&.to_sym || :architecture,
          title:       hash['title'],
          scale:       hash['scale'],
          scene_name:  hash['scene_name'],
          status:      hash['status']&.to_sym || :draft,
          revision:    hash['revision'],
          revisions:   hash['revisions'] || [],
          created_at:  hash['created_at'],
          updated_at:  hash['updated_at']
        )
      end

    end
  end
end
