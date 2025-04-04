module Operations
  module Exporters
    # A pure Ruby SVG exporter for task visualization with no external dependencies
    class SVG
      attr_reader :task_class

      COLORS = {
        decision: "#4e79a7",  # Blue
        action: "#f28e2b",    # Orange
        wait: "#76b7b2",      # Teal
        result: "#59a14f",    # Green
        start: "#59a14f",     # Green
        block: "#bab0ab"      # Grey
      }

      def self.export(task_class)
        new(task_class).to_svg
      end

      def initialize(task_class)
        @task_class = task_class
        @node_positions = {}
        @next_id = 0
      end

      # Generate SVG representation of the task flow
      def to_svg
        task_hash = task_class.to_h

        # Calculate node positions using simple layout algorithm
        calculate_node_positions(task_hash)

        # Generate SVG
        generate_svg(task_hash)
      end

      # Save the SVG to a file
      def save(filename, format: :svg)
        if format != :svg && format != :png
          raise ArgumentError, "Only SVG format is supported without GraphViz"
        end

        File.write(filename, to_svg)
      end

      private

      def generate_id
        id = "node_#{@next_id}"
        @next_id += 1
        id
      end

      def calculate_node_positions(task_hash)
        # Simple layout algorithm that positions nodes in columns by state type
        # This is a minimal implementation; a real layout algorithm would be more complex

        # Group nodes by type for column-based layout
        nodes_by_type = {decision: [], action: [], wait: [], result: []}

        task_hash[:states].each do |state_name, state_info|
          nodes_by_type[state_info[:type]] << state_name if nodes_by_type.key?(state_info[:type])
        end

        # Calculate positions (this is simplified - a real algorithm would handle edge crossings better)
        x_offset = 100
        column_width = 200
        row_height = 150

        # Position initial state (usually a decision)
        task_hash[:initial_state]
        @node_positions["START"] = [50, 100]

        # Position nodes by type in columns
        [:decision, :action, :wait, :result].each_with_index do |type, col_idx|
          nodes_by_type[type].each_with_index do |node_name, row_idx|
            # Position nodes in a grid layout
            x = x_offset + (col_idx * column_width)
            y = 100 + (row_idx * row_height)
            @node_positions[node_name] = [x, y]
          end
        end
      end

      def generate_svg(task_hash)
        # SVG dimensions based on node positions
        max_x = @node_positions.values.map(&:first).max + 150
        max_y = @node_positions.values.map(&:last).max + 150

        # Start SVG document
        svg = <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" width="#{max_x}" height="#{max_y}" viewBox="0 0 #{max_x} #{max_y}">
            <defs>
              <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
                <polygon points="0 0, 10 3.5, 0 7" fill="#333" />
              </marker>
            </defs>
        SVG

        # Draw edges (connections between nodes)
        svg += draw_edges(task_hash)

        # Draw all nodes
        svg += draw_nodes(task_hash)

        # Close SVG document
        svg += "</svg>"

        svg
      end

      def draw_nodes(task_hash)
        svg = ""

        # Add starting node
        if task_hash[:initial_state] && @node_positions[task_hash[:initial_state]]
          svg += draw_circle(
            @node_positions["START"][0],
            @node_positions["START"][1],
            20,
            COLORS[:start],
            "START"
          )
        end

        # Add nodes for each state
        task_hash[:states].each do |state_name, state_info|
          next unless @node_positions[state_name]

          x, y = @node_positions[state_name]
          node_label = create_node_label(state_name, state_info)

          svg += case state_info[:type]
          when :decision
            draw_diamond(x, y, 120, 80, COLORS[:decision], node_label)
          when :action
            draw_rectangle(x, y, 160, 80, COLORS[:action], node_label)
          when :wait
            draw_rectangle(x, y, 160, 80, COLORS[:wait], node_label, dashed: true)
          when :result
            draw_rectangle(x, y, 160, 80, COLORS[:result], node_label)
          else
            draw_rectangle(x, y, 160, 80, "#cccccc", node_label)
          end
        end

        svg
      end

      def draw_edges(task_hash)
        svg = ""

        # Add edge from START to initial state
        if task_hash[:initial_state] && @node_positions[task_hash[:initial_state]]
          start_x, start_y = @node_positions["START"]
          end_x, end_y = @node_positions[task_hash[:initial_state]]
          svg += draw_arrow(start_x + 20, start_y, end_x - 60, end_y, "")
        end

        # Add edges for transitions
        task_hash[:states].each do |state_name, state_info|
          case state_info[:type]
          when :decision
            state_info[:transitions]&.each do |condition, target|
              # Skip Proc targets as they're custom actions
              next if target.is_a?(Proc)

              if @node_positions[state_name] && @node_positions[target.to_sym]
                start_x, start_y = @node_positions[state_name]
                end_x, end_y = @node_positions[target.to_sym]
                label = condition.to_s
                svg += draw_arrow(start_x + 60, start_y, end_x - 80, end_y, label)
              end
            end
          when :action
            if state_info[:next_state] && @node_positions[state_name] && @node_positions[state_info[:next_state]]
              start_x, start_y = @node_positions[state_name]
              end_x, end_y = @node_positions[state_info[:next_state]]
              svg += draw_arrow(start_x + 80, start_y, end_x - 80, end_y, "")
            end
          when :wait
            # Add a self-loop for wait condition
            if @node_positions[state_name]
              x, y = @node_positions[state_name]
              svg += draw_self_loop(x, y, 160, 80, "waiting")

              # Add transitions
              state_info[:transitions]&.each do |condition, target|
                # Skip Proc targets
                next if target.is_a?(Proc)

                if @node_positions[target.to_sym]
                  start_x, start_y = @node_positions[state_name]
                  end_x, end_y = @node_positions[target.to_sym]
                  label = condition.to_s
                  svg += draw_arrow(start_x + 80, start_y, end_x - 80, end_y, label)
                end
              end
            end
          end
        end

        svg
      end

      # Helper methods for drawing SVG elements

      def draw_rectangle(x, y, width, height, color, text, dashed: false)
        style = dashed ? "fill:#{color};stroke:#333;stroke-width:2;stroke-dasharray:5,5;" : "fill:#{color};stroke:#333;stroke-width:2;"

        <<~SVG
          <rect x="#{x - width / 2}" y="#{y - height / 2}" width="#{width}" height="#{height}" rx="10" ry="10" style="#{style}" />
          <text x="#{x}" y="#{y}" dominant-baseline="middle" text-anchor="middle" fill="white" font-family="Arial" font-size="12px">#{escape_text(text)}</text>
        SVG
      end

      def draw_diamond(x, y, width, height, color, text)
        points = [
          [x, y - height / 2],
          [x + width / 2, y],
          [x, y + height / 2],
          [x - width / 2, y]
        ].map { |px, py| "#{px},#{py}" }.join(" ")

        <<~SVG
          <polygon points="#{points}" style="fill:#{color};stroke:#333;stroke-width:2;" />
          <text x="#{x}" y="#{y}" dominant-baseline="middle" text-anchor="middle" fill="white" font-family="Arial" font-size="12px">#{escape_text(text)}</text>
        SVG
      end

      def draw_circle(x, y, radius, color, text)
        <<~SVG
          <circle cx="#{x}" cy="#{y}" r="#{radius}" style="fill:#{color};stroke:#333;stroke-width:2;" />
          <text x="#{x}" y="#{y}" dominant-baseline="middle" text-anchor="middle" fill="white" font-family="Arial" font-size="12px">#{escape_text(text)}</text>
        SVG
      end

      def draw_arrow(x1, y1, x2, y2, label, dashed: false)
        # Calculate the line and add an offset to avoid overlap with nodes
        dx = x2 - x1
        dy = y2 - y1
        length = Math.sqrt(dx * dx + dy * dy)

        # Make sure we don't divide by zero
        if length.zero?
          return ""
        end

        # Calculate control points for a slight curve
        # This helps when there are multiple edges between the same nodes
        mx = (x1 + x2) / 2
        my = (y1 + y2) / 2

        # Add slight curve for better visualization
        cx = mx + dy * 0.2
        cy = my - dx * 0.2

        style = dashed ? "stroke:#333;stroke-width:2;fill:none;stroke-dasharray:5,5;" : "stroke:#333;stroke-width:2;fill:none;"
        marker = "marker-end=\"url(#arrowhead)\""

        svg = <<~SVG
          <path d="M#{x1},#{y1} Q#{cx},#{cy} #{x2},#{y2}" style="#{style}" #{marker} />
        SVG

        # Add label if provided
        if label && !label.empty?
          svg += <<~SVG
            <text x="#{mx + dy * 0.1}" y="#{my - dx * 0.1}" dominant-baseline="middle" text-anchor="middle" fill="#333" font-family="Arial" font-size="10px">#{escape_text(label)}</text>
          SVG
        end

        svg
      end

      def draw_self_loop(x, y, width, height, label)
        # Create a self-loop arrow (circle with an arrow)

        style = "stroke:#333;stroke-width:2;fill:none;stroke-dasharray:5,5;"

        svg = <<~SVG
          <ellipse cx="#{x - width / 2}" cy="#{y}" rx="20" ry="30" style="#{style}" />
          <path d="M#{x - width / 2 - 10},#{y - 10} L#{x - width / 2 - 20},#{y} L#{x - width / 2 - 10},#{y + 10}" style="stroke:#333;stroke-width:2;fill:none;" />
        SVG

        # Add label
        svg += <<~SVG
          <text x="#{x - width / 2 - 30}" y="#{y - 25}" dominant-baseline="middle" text-anchor="middle" fill="#333" font-family="Arial" font-size="10px">#{escape_text(label)}</text>
        SVG

        svg
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

      def escape_text(text)
        # Split the text into lines for multi-line support
        lines = text.to_s.split("\n")

        # Escape XML special characters and add tspan elements for multi-line text
        result = lines.map.with_index do |line, index|
          dy = (index == 0) ? "0" : "1.2em"
          line = line.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;")
          "<tspan x=\"0\" dy=\"#{dy}\" text-anchor=\"middle\">#{line}</tspan>"
        end.join("")

        "<tspan x=\"0\" dy=\"-#{(lines.length - 1) * 0.6}em\">#{result}</tspan>"
      end
    end
  end
end
