# ==============================================================================
# RAB Pro - Scene Manager
# Creates and manages SketchUp scenes required for technical drawings.
# Each drawing type (denah, tampak, potongan) needs a dedicated scene
# with correct camera, section plane, style, and layer visibility.
# ==============================================================================

module RABPro
  module Drawings
    module Scenes
      class SceneManager

        # Standard scene definitions
        SCENE_DEFINITIONS = {
          # ---- DENAH (Floor Plans) -----------------------------------------
          denah_lt1: {
            name:        'RAB_Denah_LT1',
            description: 'Denah Lantai 1',
            type:        :floor_plan,
            elevation:   1.0,      # metres above ground — section cut height
            style:       :technical,
            section:     true,
            layer_rules: { hide: [:atap, :plafon, :mep_above] }
          },
          denah_lt2: {
            name:        'RAB_Denah_LT2',
            description: 'Denah Lantai 2',
            type:        :floor_plan,
            elevation:   4.0,
            style:       :technical,
            section:     true,
            layer_rules: { hide: [:atap, :plafon] }
          },
          denah_atap: {
            name:        'RAB_Denah_Atap',
            description: 'Denah Atap',
            type:        :roof_plan,
            elevation:   nil,
            style:       :technical,
            section:     false,
            layer_rules: { show: [:atap], hide: [:interior] }
          },

          # ---- TAMPAK (Elevations) -----------------------------------------
          tampak_depan: {
            name:        'RAB_Tampak_Depan',
            description: 'Tampak Depan',
            type:        :elevation,
            direction:   :front,    # camera direction
            style:       :technical,
            section:     false,
            layer_rules: {}
          },
          tampak_belakang: {
            name:        'RAB_Tampak_Belakang',
            description: 'Tampak Belakang',
            type:        :elevation,
            direction:   :back,
            style:       :technical,
            section:     false,
            layer_rules: {}
          },
          tampak_kiri: {
            name:        'RAB_Tampak_Kiri',
            description: 'Tampak Kiri',
            type:        :elevation,
            direction:   :left,
            style:       :technical,
            section:     false,
            layer_rules: {}
          },
          tampak_kanan: {
            name:        'RAB_Tampak_Kanan',
            description: 'Tampak Kanan',
            type:        :elevation,
            direction:   :right,
            style:       :technical,
            section:     false,
            layer_rules: {}
          },

          # ---- POTONGAN (Sections) -----------------------------------------
          potongan_aa: {
            name:        'RAB_Potongan_AA',
            description: 'Potongan A-A (Memanjang)',
            type:        :section,
            cut_axis:    :y,         # cut perpendicular to Y axis (longitudinal)
            cut_position: 0.5,       # 0..1 = normalised position along axis
            style:       :technical,
            section:     true,
            layer_rules: {}
          },
          potongan_bb: {
            name:        'RAB_Potongan_BB',
            description: 'Potongan B-B (Melintang)',
            type:        :section,
            cut_axis:    :x,
            cut_position: 0.5,
            style:       :technical,
            section:     true,
            layer_rules: {}
          },

          # ---- 3D VIEWS -------------------------------------------------------
          perspektif: {
            name:        'RAB_Perspektif',
            description: 'Tampak 3D Perspektif',
            type:        :perspective_3d,
            direction:   :iso_sw,
            style:       :shaded,
            section:     false,
            layer_rules: {}
          },
          wireframe_3d: {
            name:        'RAB_Wireframe_3D',
            description: 'Tampak 3D Wireframe',
            type:        :perspective_3d,
            direction:   :iso_sw,
            style:       :hidden_line,
            section:     false,
            layer_rules: {}
          }
        }.freeze

        def initialize(model)
          @model = model
          @view  = model.active_view
        end

        # -----------------------------------------------------------------------
        # Create all standard scenes for a building model
        # Returns array of created/updated scene names
        # -----------------------------------------------------------------------
        def create_standard_scenes(scene_ids: nil)
          scene_ids ||= SCENE_DEFINITIONS.keys
          created = []

          @model.start_operation('RAB Pro: Create Drawing Scenes', true)

          scene_ids.each do |id|
            defn = SCENE_DEFINITIONS[id]
            next unless defn

            begin
              page = _create_or_update_scene(id, defn)
              created << defn[:name] if page
              Logger.info("SceneManager: created scene '#{defn[:name]}'")
            rescue => e
              Logger.error("SceneManager: failed to create '#{id}': #{e.message}")
            end
          end

          @model.commit_operation
          Logger.info("SceneManager: #{created.size} scenes created/updated")
          created
        end

        # -----------------------------------------------------------------------
        # Create a single scene by id
        # -----------------------------------------------------------------------
        def create_scene(scene_id)
          defn = SCENE_DEFINITIONS[scene_id.to_sym]
          raise ArgumentError, "Unknown scene: #{scene_id}" unless defn

          @model.start_operation("RAB Pro: Create #{defn[:name]}", true)
          page = _create_or_update_scene(scene_id.to_sym, defn)
          @model.commit_operation
          page
        end

        # -----------------------------------------------------------------------
        # List existing RAB Pro scenes in model
        # -----------------------------------------------------------------------
        def existing_rab_scenes
          @model.pages.select { |p| p.name.start_with?('RAB_') }
        end

        # -----------------------------------------------------------------------
        # Delete all RAB Pro scenes
        # -----------------------------------------------------------------------
        def delete_rab_scenes
          @model.start_operation('RAB Pro: Delete Scenes', true)
          existing_rab_scenes.each { |p| @model.pages.erase(p) }
          @model.commit_operation
        end

        # -----------------------------------------------------------------------
        # Activate a scene by name
        # -----------------------------------------------------------------------
        def activate_scene(name)
          page = @model.pages[name]
          @model.pages.selected_page = page if page
          page
        end

        # -----------------------------------------------------------------------
        # Return all scene definitions as array for UI
        # -----------------------------------------------------------------------
        def self.scene_list
          SCENE_DEFINITIONS.map do |id, defn|
            {
              id:          id,
              name:        defn[:name],
              description: defn[:description],
              type:        defn[:type]
            }
          end
        end

        private

        def _create_or_update_scene(id, defn)
          # Find or create page
          page = @model.pages[defn[:name]] || @model.pages.add(defn[:name])
          page.description = defn[:description]

          # Save which properties this page controls
          page.use_camera           = true
          page.use_hidden_layers    = true
          page.use_rendering_options = true
          page.use_section_planes   = defn[:section]
          page.use_style            = true

          # Set camera for this view type
          _set_camera(page, defn)

          # Apply rendering style
          _apply_style(defn[:style])

          # Manage section planes
          _manage_sections(defn) if defn[:section]

          # Update page to snapshot current state
          page.update(255)   # update all flags

          page
        rescue => e
          Logger.error("_create_or_update_scene #{id}: #{e.message}")
          nil
        end

        # -----------------------------------------------------------------------
        # Camera positioning
        # -----------------------------------------------------------------------
        def _set_camera(page, defn)
          bb     = @model.bounds
          center = bb.center
          width  = bb.width   / 39.3701   # inches → m
          height = bb.height  / 39.3701
          depth  = bb.depth   / 39.3701
          diag   = Math.sqrt(width**2 + height**2 + depth**2)

          camera = Sketchup::Camera.new

          case defn[:type]
          when :floor_plan, :roof_plan
            # Top-down orthographic view
            eye_height = (bb.max.z + 200).to_f   # above model (inches)
            eye        = Geom::Point3d.new(center.x, center.y, eye_height)
            target     = Geom::Point3d.new(center.x, center.y, center.z)
            up         = Geom::Vector3d.new(0, 1, 0)
            camera.set(eye, target, up)
            camera.perspective = false
            camera.height      = [bb.width, bb.depth].max * 1.3

          when :elevation
            dist = (diag * 60).to_f   # step back in inches

            case defn[:direction]
            when :front
              eye    = Geom::Point3d.new(center.x, center.y - dist, center.z)
              target = center
              up     = Geom::Vector3d.new(0, 0, 1)
            when :back
              eye    = Geom::Point3d.new(center.x, center.y + dist, center.z)
              target = center
              up     = Geom::Vector3d.new(0, 0, 1)
            when :left
              eye    = Geom::Point3d.new(center.x - dist, center.y, center.z)
              target = center
              up     = Geom::Vector3d.new(0, 0, 1)
            when :right
              eye    = Geom::Point3d.new(center.x + dist, center.y, center.z)
              target = center
              up     = Geom::Vector3d.new(0, 0, 1)
            end

            camera.set(eye, target, up)
            camera.perspective = false
            camera.height      = bb.height * 1.3

          when :section
            # Section cut — same as elevation but with section plane active
            dist = (diag * 60).to_f
            eye    = Geom::Point3d.new(center.x, center.y - dist, center.z)
            target = center
            up     = Geom::Vector3d.new(0, 0, 1)
            camera.set(eye, target, up)
            camera.perspective = false
            camera.height      = bb.height * 1.4

          when :perspective_3d
            dist = (diag * 55).to_f
            case defn[:direction]
            when :iso_sw
              eye = Geom::Point3d.new(
                center.x - dist * 0.7,
                center.y - dist * 0.7,
                center.z + dist * 0.5
              )
            else
              eye = Geom::Point3d.new(center.x - dist, center.y - dist, center.z + dist * 0.5)
            end
            camera.set(eye, center, Geom::Vector3d.new(0, 0, 1))
            camera.perspective = true
            camera.fov         = 35.0
          end

          @model.active_view.camera = camera
        end

        # -----------------------------------------------------------------------
        # Rendering style
        # -----------------------------------------------------------------------
        def _apply_style(style_type)
          styles = @model.styles
          target_style = case style_type
                         when :technical    then 'Hidden Line'
                         when :hidden_line  then 'Hidden Line'
                         when :shaded       then 'Shaded with Textures'
                         else 'Hidden Line'
                         end

          found = styles.find { |s| s.name.include?(target_style) }
          styles.selected_style = found if found
        rescue => e
          Logger.warn("_apply_style: #{e.message}")
        end

        # -----------------------------------------------------------------------
        # Section plane management
        # -----------------------------------------------------------------------
        def _manage_sections(defn)
          # Remove existing RAB section planes
          @model.entities.grep(Sketchup::SectionPlane).each do |sp|
            @model.entities.erase_entities(sp) if sp.name.to_s.start_with?('RAB_')
          end

          bb = @model.bounds

          case defn[:type]
          when :floor_plan
            elev_m   = defn[:elevation] || 1.0
            elev_in  = elev_m * 39.3701
            cut_z    = bb.min.z + elev_in

            sp = @model.entities.add_section_plane(
              [Geom::Point3d.new(0, 0, cut_z), Geom::Vector3d.new(0, 0, -1)]
            )
            sp.name = "RAB_#{defn[:name]}_Cut"
            sp.activate

          when :section
            axis     = defn[:cut_axis] || :y
            position = defn[:cut_position] || 0.5

            case axis
            when :y
              cut_y = bb.min.y + (bb.height * position)
              sp = @model.entities.add_section_plane(
                [Geom::Point3d.new(0, cut_y, 0), Geom::Vector3d.new(0, -1, 0)]
              )
            when :x
              cut_x = bb.min.x + (bb.width * position)
              sp = @model.entities.add_section_plane(
                [Geom::Point3d.new(cut_x, 0, 0), Geom::Vector3d.new(-1, 0, 0)]
              )
            end

            sp.name = "RAB_#{defn[:name]}_Cut" if sp
            sp.activate if sp
          end
        rescue => e
          Logger.warn("_manage_sections: #{e.message}")
        end

      end
    end
  end
end
