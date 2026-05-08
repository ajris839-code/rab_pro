# ==============================================================================
# RAB Pro - Tagger Panel (stub — content served via main_panel.html)
# ==============================================================================

module RABPro
  module UI
    module Panels
      class TaggerPanel
        def initialize(app_controller)
          @app = app_controller
        end

        def tag_summary
          model = Sketchup.active_model
          return {} unless model
          Core::Tagger::TagEngine.stats(model)
        end
      end
    end
  end
end
