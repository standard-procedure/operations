require "rails_helper"
require "operations/exporters/graphviz"
require "tempfile"

module Operations
  module Exporters
    RSpec.describe Graphviz do
      # A sample task to use for testing the exporter
      # standard:disable Lint/ConstantDefinitionInBlock
      class GraphvizTestTask < Operations::Task
        inputs :user, :document, :use_filename_scrambler
        starts_with :authorised?

        decision :authorised? do
          inputs :user, :document
          condition { user.can? :read, document }

          if_true :within_download_limits?
          if_false { fail_with "unauthorised" }
        end

        decision :within_download_limits? do
          inputs :user
          condition { user.within_download_limits? }

          if_true :use_filename_scrambler?
          if_false { fail_with "download_limit_reached" }
        end

        decision :use_filename_scrambler? do
          inputs :use_filename_scrambler
          condition { use_filename_scrambler }

          if_true :scramble_filename
          if_false :return_filename
        end

        action :scramble_filename do
          inputs :document
          self.filename = "scrambled_filename"
        end
        goto :return_filename, from: :scramble_filename

        result :return_filename do |results|
          inputs :document
          optional :filename
          results.filename = filename || document.filename.to_s
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      describe "#to_h" do
        it "returns a hash representation of the task structure" do
          task_hash = GraphvizTestTask.to_h

          expect(task_hash[:name]).to eq("Operations::Exporters::GraphvizTestTask")
          expect(task_hash[:initial_state]).to eq(:authorised?)
          expect(task_hash[:states].keys).to include(
            :authorised?,
            :within_download_limits?,
            :use_filename_scrambler?,
            :scramble_filename,
            :return_filename
          )

          # Check decision state
          authorised_state = task_hash[:states][:authorised?]
          expect(authorised_state[:type]).to eq(:decision)
          expect(authorised_state[:transitions]["true"]).to eq(:within_download_limits?)

          # Check action state
          scramble_state = task_hash[:states][:scramble_filename]
          expect(scramble_state[:type]).to eq(:action)
          expect(scramble_state[:next_state]).to eq(:return_filename)

          # Check result state
          result_state = task_hash[:states][:return_filename]
          expect(result_state[:type]).to eq(:result)
        end
      end

      describe "#graph" do
        it "returns a GraphViz object" do
          exporter = Graphviz.new(GraphvizTestTask)
          graph = exporter.graph

          expect(graph).to be_a(GraphViz)
          expect(graph.type).to eq("digraph") # GraphViz returns a string, not a symbol
        end
      end

      # Skip GraphViz output tests if the dot program is not installed
      if system("which dot > /dev/null")
        describe "#to_dot" do
          it "generates a DOT format representation" do
            exporter = Graphviz.new(GraphvizTestTask)
            dot = exporter.to_dot

            expect(dot).to be_a(String)
            expect(dot).to include("digraph G {")
            expect(dot).to include("authorised?")
            expect(dot).to include("within_download_limits?")
            expect(dot).to include("use_filename_scrambler?")
            expect(dot).to include("scramble_filename")
            expect(dot).to include("return_filename")
          end
        end

        describe "#save" do
          it "can generate a PNG file" do
            tempfile = Tempfile.new(["task_graph", ".png"])
            begin
              exporter = Graphviz.new(GraphvizTestTask)
              exporter.save(tempfile.path)

              expect(File.exist?(tempfile.path)).to be true
              expect(File.size(tempfile.path)).to be > 0
            ensure
              tempfile.close
              tempfile.unlink
            end
          end

          it "can generate a SVG file" do
            tempfile = Tempfile.new(["task_graph", ".svg"])
            begin
              exporter = Graphviz.new(GraphvizTestTask)
              exporter.save(tempfile.path, format: :svg)

              expect(File.exist?(tempfile.path)).to be true
              expect(File.size(tempfile.path)).to be > 0

              # SVG file should contain SVG markup
              content = File.read(tempfile.path)
              expect(content).to include("<svg")
              expect(content).to include("</svg>")
            ensure
              tempfile.close
              tempfile.unlink
            end
          end
        end
      else
        # Display warning message
        puts "GraphViz dot command not found in PATH. Skipping GraphViz output tests."
      end
    end
  end
end
