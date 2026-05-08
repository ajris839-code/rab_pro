# ==============================================================================
# RAB Pro - Inspector Panel (stub — content served via main_panel.html)
# Provides Ruby-side logic for the inspector tab in the main panel.
# ==============================================================================

module RABPro
  module UI
    module Panels
      class InspectorPanel
        def initialize(app_controller)
          @app = app_controller
        end

        # Data preparation for inspector tab — called by MainPanel
        def build_data
          model = Sketchup.active_model
          return {} unless model

          reader   = Core::Inspector::EntityReader.new(model)
          analyzer = Core::Inspector::GeometryAnalyzer.new
          tree     = Core::Inspector::ComponentTree.new(model)

          {
            summary:  reader.summary,
            entities: reader.read_top_level,
            tree:     tree.build,
            stats:    reader.stats
          }
        end
      end
    end
  end
end
