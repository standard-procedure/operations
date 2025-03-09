require "graphviz"

module Operations
  module Exporters
    class Graphviz
      attr_reader :task_class

      def self.export(task_class)
        new(task_class).to_dot
      end

      def initialize(task_class)
        @task_class = task_class
      end

      # Generate a DOT representation of the task flow
      def to_dot
        graph.output(dot: String)
      end

      # Generate and save the graph to a file
      # Supported formats: dot, png, svg, pdf, etc.
      def save(filename, format: :png)
        graph.output(format => filename)
      end

      # Generate GraphViz object representing the task flow
      def graph
        @graph ||= build_graph
      end

      private

      def build_graph
        task_hash = task_class.to_h
        g = GraphViz.new(:G, type: :digraph, rankdir: "LR")

        # Set up node styles
        g.node[:shape] = "box"
        g.node[:style] = "rounded"
        g.node[:fontname] = "Arial"
        g.node[:fontsize] = "12"
        g.edge[:fontname] = "Arial"
        g.edge[:fontsize] = "10"

        # Create nodes for each state
        nodes = {}
        task_hash[:states].each do |state_name, state_info|
          node_style = node_style_for(state_info[:type])
          node_label = create_node_label(state_name, state_info)
          nodes[state_name] = g.add_nodes(state_name.to_s, label: node_label, **node_style)
        end

        # Add edges for transitions
        task_hash[:states].each do |state_name, state_info|
          case state_info[:type]
          when :decision
            add_decision_edges(g, nodes, state_name, state_info[:transitions])
          when :action
            if state_info[:next_state]
              g.add_edges(nodes[state_name], nodes[state_info[:next_state]])
            end
          when :wait
            add_wait_edges(g, nodes, state_name, state_info[:transitions])
          end
        end

        # Mark initial state
        if nodes[task_hash[:initial_state]]
          initial_node = g.add_nodes("START", shape: "circle", style: "filled", fillcolor: "#59a14f", fontcolor: "white")
          g.add_edges(initial_node, nodes[task_hash[:initial_state]])
        end

        g
      end

      def node_style_for(type)
        case type
        when :decision
          {shape: "diamond", style: "filled", fillcolor: "#4e79a7", fontcolor: "white"}
        when :action
          {shape: "box", style: "filled", fillcolor: "#f28e2b", fontcolor: "white"}
        when :wait
          {shape: "box", style: "filled,dashed", fillcolor: "#76b7b2", fontcolor: "white"}
        when :result
          {shape: "box", style: "filled", fillcolor: "#59a14f", fontcolor: "white"}
        else
          {shape: "box"}
        end
      end

      def create_node_label(state_name, state_info)
        label = state_name.to_s

        # Add inputs if present
        if state_info[:inputs].present?
          inputs_list = state_info[:inputs].map(&:to_s).join(", ")
          label += "\nInputs: #{inputs_list}"
        end

        # Add optional inputs if present
        if state_info[:optional_inputs].present?
          optional_list = state_info[:optional_inputs].map(&:to_s).join(", ")
          label += "\nOptional: #{optional_list}"
        end

        label
      end

      def add_decision_edges(graph, nodes, state_name, transitions)
        # Get the handler for this state to access condition labels
        task_state = task_class.respond_to?(:states) ? task_class.states[state_name.to_sym] : nil
        handler = task_state[:handler] if task_state

        transitions.each_with_index do |(condition, target), index|
          # Get custom label if available
          label = (handler&.respond_to?(:condition_labels) && handler.condition_labels[index]) ? handler.condition_labels[index] : target.to_s

          if (target.is_a?(Symbol) || target.is_a?(String)) && nodes[target.to_sym]
            graph.add_edges(nodes[state_name], nodes[target.to_sym], label: label)
          elsif target.respond_to?(:call)
            # Create a special node to represent the custom action
            block_node_name = "#{state_name}_#{condition}_block"
            block_node = graph.add_nodes(block_node_name,
              label: "#{condition} Custom Action",
              shape: "note",
              style: "filled",
              fillcolor: "#bab0ab",
              fontcolor: "black")

            graph.add_edges(nodes[state_name], block_node,
              label: label,
              style: "dashed")
          end
        end
      end

      def add_wait_edges(graph, nodes, state_name, transitions)
        # Get the handler for this state to access condition labels
        task_state = task_class.respond_to?(:states) ? task_class.states[state_name.to_sym] : nil
        handler = task_state[:handler] if task_state

        # Add a self-loop for wait condition
        graph.add_edges(nodes[state_name], nodes[state_name],
          label: "waiting",
          style: "dashed",
          constraint: "false",
          dir: "back")

        # Add edges for each transition
        transitions.each_with_index do |(condition, target), index|
          # Get custom label if available
          label = (handler&.respond_to?(:condition_labels) && handler.condition_labels[index]) ? handler.condition_labels[index] : target.to_s

          if (target.is_a?(Symbol) || target.is_a?(String)) && nodes[target.to_sym]
            graph.add_edges(nodes[state_name], nodes[target.to_sym],
              label: label,
              style: "solid")
          end
        end
      end
    end
  end
end
