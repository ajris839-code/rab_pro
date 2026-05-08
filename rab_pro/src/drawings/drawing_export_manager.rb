# ==============================================================================
# RAB Pro - Drawing Export Manager
# Coordinates export of technical drawings to PDF, PNG, and DWG formats.
# Handles batch export, format conversion, and file naming conventions.
# ==============================================================================

module RABPro
  module Drawings
    class DrawingExportManager

      SUPPORTED_FORMATS = %i[pdf png dwg layout html].freeze

      def initialize(model, settings: nil, project_store: nil)
        @model         = model
        @settings      = settings
        @project_store = project_store
        @pi            = project_store&.project_info&.to_h || {}
        @paper_size    = settings&.get('pdf_paper_size') || 'A3'
        @export_path   = settings&.export_path || Dir.home
      end

      # -----------------------------------------------------------------------
      # Export all drawings to selected format
      # -----------------------------------------------------------------------
      def export_all(format: :pdf, output_dir: nil, sheet_ids: nil)
        dir = output_dir || @export_path
        FileUtils.mkdir_p(dir)

        case format.to_sym
        when :pdf, :html
          _export_drawing_set(dir, sheet_ids: sheet_ids)
        when :png
          _export_all_png(dir, sheet_ids: sheet_ids)
        when :dwg
          _export_dwg(dir)
        else
          { success: false, error: "Format '#{format}' tidak didukung" }
        end
      end

      # -----------------------------------------------------------------------
      # Export single scene to PNG
      # -----------------------------------------------------------------------
      def export_scene(scene_name, format: :png, output_dir: nil)
        dir      = output_dir || @export_path
        filename = _safe_filename(scene_name, format.to_s)
        path     = File.join(dir, filename)

        layout = Layout::LayoutAutomation.new(
          @model, settings: @settings, project_store: @project_store
        )

        case format.to_sym
        when :png
          success = layout.export_scene_png(scene_name, path)
          success ? { success: true, path: path } : { success: false, error: 'PNG export gagal' }
        else
          { success: false, error: "Format tidak didukung untuk single scene" }
        end
      end

      # -----------------------------------------------------------------------
      # Batch export all scenes as individual PNGs
      # -----------------------------------------------------------------------
      def batch_export_scenes(scene_names: nil, format: :png, output_dir: nil)
        dir     = output_dir || @export_path
        FileUtils.mkdir_p(dir)
        results = []

        scenes = scene_names || _rab_scene_names

        scenes.each do |name|
          r = export_scene(name, format: format, output_dir: dir)
          results << { scene: name, **r }
        end

        {
          success: results.all? { |r| r[:success] },
          results: results,
          output_dir: dir
        }
      end

      # -----------------------------------------------------------------------
      # Export DWG via SketchUp's built-in DWG exporter
      # -----------------------------------------------------------------------
      def export_current_view_dwg(output_path)
        opts = Sketchup::DwgOptions.new rescue nil

        if opts
          opts.options = {
            'ExportArcs'            => true,
            'ExportDimensions'      => true,
            'ExportText'            => true,
            'ExportEdges'           => true,
            'ExportFaces'           => false,
            'ExportLineWeights'     => true,
            'ExportSectionLines'    => true,
            'ExportGuides'          => false,
          }
        end

        success = @model.export(output_path, opts)
        success ? { success: true, path: output_path }
                : { success: false, error: 'DWG export gagal' }
      rescue => e
        Logger.error("export_current_view_dwg: #{e.message}")
        { success: false, error: e.message }
      end

      # -----------------------------------------------------------------------
      # Create a zip archive of all exported files
      # -----------------------------------------------------------------------
      def create_drawing_package(output_dir, zip_path: nil)
        require 'zip' rescue nil

        files = Dir.glob(File.join(output_dir, '*.{pdf,png,dwg,html}'))
        return { success: false, error: 'Tidak ada file untuk di-zip' } if files.empty?

        zip_out = zip_path || File.join(output_dir, _package_name)

        if defined?(Zip)
          Zip::File.open(zip_out, Zip::File::CREATE) do |zf|
            files.each do |f|
              zf.add(File.basename(f), f)
            end
          end
          { success: true, path: zip_out, file_count: files.size }
        else
          # Fallback: list the files
          { success: true, files: files, note: 'Zip gem tidak tersedia; file ada di folder output' }
        end
      rescue => e
        Logger.error("create_drawing_package: #{e.message}")
        { success: false, error: e.message }
      end

      private

      def _export_drawing_set(dir, sheet_ids: nil)
        filename = _safe_filename("gambar_teknis_#{_project_slug}", 'html')
        path     = File.join(dir, filename)

        layout = Layout::LayoutAutomation.new(
          @model, settings: @settings, project_store: @project_store
        )
        layout.generate(path, sheet_ids: sheet_ids)
      end

      def _export_all_png(dir, sheet_ids: nil)
        layout = Layout::LayoutAutomation.new(
          @model, settings: @settings, project_store: @project_store
        )

        scenes = sheet_ids ?
          Layout::LayoutAutomation::SHEET_CONFIG
            .select { |s| sheet_ids.include?(s[:id]) && s[:scene] }
            .map { |s| s[:scene] } :
          _rab_scene_names

        results = scenes.map do |scene|
          filename = _safe_filename(scene, 'png')
          path     = File.join(dir, filename)
          success  = layout.export_scene_png(scene, path)
          { scene: scene, success: success, path: path }
        end

        { success: results.all? { |r| r[:success] }, results: results, output_dir: dir }
      end

      def _export_dwg(dir)
        # Activate each RAB scene and export DWG for each
        scene_manager = Scenes::SceneManager.new(@model)
        rab_scenes    = scene_manager.existing_rab_scenes
        results       = []

        rab_scenes.each do |page|
          @model.pages.selected_page = page
          filename = _safe_filename(page.name, 'dwg')
          path     = File.join(dir, filename)
          r        = export_current_view_dwg(path)
          results << { scene: page.name, **r }
        end

        { success: results.all? { |r| r[:success] }, results: results, output_dir: dir }
      end

      def _rab_scene_names
        @model.pages.select { |p| p.name.start_with?('RAB_') }.map(&:name)
      end

      def _safe_filename(name, ext)
        slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/_+/, '_').strip
        "#{_project_slug}_#{slug}.#{ext}"
      end

      def _project_slug
        name = @pi[:name] || 'proyek'
        name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/_+/, '_').strip[0, 30]
      end

      def _package_name
        "#{_project_slug}_gambar_teknis_#{Time.now.strftime('%Y%m%d')}.zip"
      end

    end
  end
end
