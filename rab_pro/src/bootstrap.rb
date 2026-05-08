# ==============================================================================
# RAB Pro - Bootstrap v4 (Fase 1 + 2 + 3 + 4 - COMPLETE)
# Loads all modules in correct dependency order
# ==============================================================================

module RABPro

  BOOTSTRAP_PATH = File.dirname(__FILE__).freeze unless defined?(BOOTSTRAP_PATH)

  def self.src_path(*parts)
    File.join(BOOTSTRAP_PATH, *parts)
  end

  require 'time'

  # 1. Utilities
  require src_path('utils', 'logger.rb')
  require src_path('utils', 'geometry_helper.rb')
  require src_path('utils', 'unit_converter.rb')
  require src_path('utils', 'string_helper.rb')
  require src_path('utils', 'settings_manager.rb')

  # 2. Data layer
  require src_path('data', 'category_library.rb')
  require src_path('data', 'material_database.rb')
  require src_path('data', 'project_store.rb')

  # 3. Core — Fase 1
  require src_path('core', 'inspector', 'entity_reader.rb')
  require src_path('core', 'inspector', 'geometry_analyzer.rb')
  require src_path('core', 'inspector', 'component_tree.rb')
  require src_path('core', 'tagger',    'tag_engine.rb')
  require src_path('core', 'tagger',    'auto_tagger.rb')
  require src_path('core', 'classifier', 'work_classifier.rb')
  require src_path('core', 'classifier', 'ifc_mapper.rb')

  # 4. RAB Engine — Fase 2
  require src_path('rab', 'harga_satuan_database.rb')
  require src_path('rab', 'quantity_takeoff_engine.rb')
  require src_path('rab', 'rab_calculator.rb')

  # 5. Export — Fase 2
  require src_path('export', 'excel_exporter.rb')
  require src_path('export', 'pdf_exporter.rb')

  # 6. AI Engine — Fase 2 + 4
  require src_path('ai', 'ai_engine.rb')
  require src_path('ai', 'chat', 'chat_manager.rb')

  # 7. Drawings — Fase 3
  require src_path('drawings', 'scenes',       'scene_manager.rb')
  require src_path('drawings', 'annotations',  'auto_dimensioner.rb')
  require src_path('drawings', 'layout',       'layout_automation.rb')
  require src_path('drawings', 'drawing_register.rb')
  require src_path('drawings', 'drawing_export_manager.rb')

  # 8. Dashboard, Templates, Collaboration — Fase 4
  require src_path('dashboard',     'project_dashboard.rb')
  require src_path('templates',     'template_engine.rb')
  require src_path('collaboration', 'cloud_sync.rb')

  # 9. UI layer
  require src_path('ui', 'toolbar', 'main_toolbar.rb')
  require src_path('ui', 'dialogs', 'settings_dialog.rb')
  require src_path('ui', 'dialogs', 'category_editor.rb')
  require src_path('ui', 'panels',  'main_panel.rb')
  require src_path('ui', 'panels',  'inspector_panel.rb')
  require src_path('ui', 'panels',  'tagger_panel.rb')
  require src_path('ui', 'panels',  'rab_panel.rb')
  require src_path('ui', 'panels',  'drawings_panel.rb')
  require src_path('ui', 'panels',  'fase4_panel.rb')

  # 10. App controller
  require src_path('app_controller.rb')

  unless file_loaded?(__FILE__)
    Logger.info('RAB Pro bootstrap v4 COMPLETE (Fase 1-4) — initialising')
    AppController.instance.boot!
    file_loaded(__FILE__)
  end

end
