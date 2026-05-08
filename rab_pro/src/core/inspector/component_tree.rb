# ==============================================================================
# RAB Pro - Component Tree
# Builds a hierarchical JSON-serializable tree of the model structure.
# Used by the UI to render the entity tree view and for AI context.
# ==============================================================================

module RABPro
  module Core
    module Inspector
      class ComponentTree

        TreeNode = Struct.new(
          :id, :type, :name, :layer, :category,
          :bounds, :children, :entity_id,
          keyword_init: true
        )

        MAX_DEPTH     = 8
        MAX_CHILDREN  = 500   # cap per node to avoid browser freeze

        def initialize(model)
          @model = model
          @node_count = 0
        end

        # Returns a hash tree suitable for JSON serialization
        def build
          root_children = _build_children(@model.entities, 0)
          {
            id:         'root',
            type:       'model',
            name:       @model.title.empty? ? 'Untitled Model' : @model.title,
            children:   root_children,
            node_count: @node_count
          }
        end

        # Flat array of all nodes with parent references (for table views)
        def build_flat
          nodes = []
          _flatten(@model.entities, nil, 0, nodes)
          nodes
        end

        private

        def _build_children(entities, depth)
          return [] if depth >= MAX_DEPTH

          children = []
          entities.each do |e|
            break if children.size >= MAX_CHILDREN

            node = case e
                   when Sketchup::ComponentInstance then _comp_node(e, depth)
                   when Sketchup::Group             then _group_node(e, depth)
                   else nil
                   end

            next unless node
            children << node
            @node_count += 1
          end
          children
        end

        def _comp_node(instance, depth)
          defn = instance.definition
          child_entities = defn.entities
          {
            id:         "c_#{instance.entityID}",
            entity_id:  instance.entityID,
            type:       'component',
            name:       instance.name.empty? ? defn.name : instance.name,
            definition: defn.name,
            layer:      instance.layer.name,
            category:   instance.get_attribute('RABPro', 'category'),
            hidden:     instance.hidden?,
            locked:     instance.locked?,
            bounds:     _compact_bounds(instance.bounds),
            children:   _build_children(child_entities, depth + 1)
          }
        end

        def _group_node(group, depth)
          {
            id:        "g_#{group.entityID}",
            entity_id: group.entityID,
            type:      'group',
            name:      group.name.empty? ? "(Group ##{group.entityID})" : group.name,
            layer:     group.layer.name,
            category:  group.get_attribute('RABPro', 'category'),
            hidden:    group.hidden?,
            locked:    group.locked?,
            bounds:    _compact_bounds(group.bounds),
            children:  _build_children(group.entities, depth + 1)
          }
        end

        def _flatten(entities, parent_id, depth, results)
          return if depth >= MAX_DEPTH
          entities.each do |e|
            case e
            when Sketchup::ComponentInstance
              node = _comp_node(e, depth).merge(parent_id: parent_id)
              results << node
              _flatten(e.definition.entities, node[:id], depth + 1, results)
            when Sketchup::Group
              node = _group_node(e, depth).merge(parent_id: parent_id)
              results << node
              _flatten(e.entities, node[:id], depth + 1, results)
            end
          end
        end

        def _compact_bounds(bb)
          {
            w: UnitConverter.inches_to_m(bb.width).round(3),
            h: UnitConverter.inches_to_m(bb.height).round(3),
            d: UnitConverter.inches_to_m(bb.depth).round(3)
          }
        end

      end
    end
  end
end
