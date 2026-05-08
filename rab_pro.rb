# ==============================================================================
# RAB Pro - Rencana Anggaran Biaya Professional Extension for SketchUp
# Version: 1.0.0
# ==============================================================================

require 'sketchup.rb'
require 'extensions.rb'

module RABPro
  EXTENSION_ID      = 'rab_pro'.freeze
  EXTENSION_VERSION = '1.0.0'.freeze
  EXTENSION_NAME    = 'RAB Pro - Estimasi & Gambar Teknis'.freeze
  EXTENSION_AUTHOR  = 'RAB Pro Team'.freeze

  # Root path = the rab_pro/ subfolder next to this file
  EXTENSION_ROOT = File.join(File.dirname(__FILE__), 'rab_pro').freeze
  SRC_PATH       = File.join(EXTENSION_ROOT, 'src').freeze
  RESOURCES_PATH = File.join(EXTENSION_ROOT, 'resources').freeze

  loader = SketchupExtension.new(EXTENSION_NAME,
             File.join(EXTENSION_ROOT, 'src', 'bootstrap.rb'))

  loader.description = 'Extension profesional untuk RAB dan gambar teknis dari SketchUp. ' \
                       'Dilengkapi AI assistant, quantity takeoff otomatis, dan export ke Excel/PDF.'
  loader.version     = EXTENSION_VERSION
  loader.copyright   = "#{Time.now.year} #{EXTENSION_AUTHOR}"
  loader.creator     = EXTENSION_AUTHOR

  Sketchup.register_extension(loader, true)
end
