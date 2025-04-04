require "rails_helper"
require "operations/exporters/svg"
require "tempfile"

module Operations
  module Exporters
    RSpec.describe SVG do
      # A sample task to use for testing the exporter
      # standard:disable Lint/ConstantDefinitionInBlock
      class SVGTestTask < Operations::Task
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
        go_to :return_filename

        result :return_filename do |results|
          inputs :document
          optional :filename
          results.filename = filename || document.filename.to_s
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      describe "#to_h" do
        it "returns a hash representation of the task structure" do
          task_hash = SVGTestTask.to_h

          expect(task_hash[:name]).to eq("Operations::Exporters::SVGTestTask")
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

      describe "#to_svg" do
        it "generates an SVG representation" do
          exporter = SVG.new(SVGTestTask)
          svg = exporter.to_svg

          expect(svg).to be_a(String)
          expect(svg).to include("<svg")
          expect(svg).to include("</svg>")
          expect(svg).to include("authorised?")
          expect(svg).to include("within_download_limits?")
          expect(svg).to include("use_filename_scrambler?")
          expect(svg).to include("scramble_filename")
          expect(svg).to include("return_filename")
        end
      end

      describe "#save" do
        it "can generate an SVG file" do
          tempfile = Tempfile.new(["task_graph", ".svg"])
          begin
            exporter = SVG.new(SVGTestTask)
            exporter.save(tempfile.path)

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

        it "raises an error for unsupported formats" do
          exporter = SVG.new(SVGTestTask)
          expect { exporter.save("output.pdf", format: :pdf) }.to raise_error(ArgumentError)
        end

        it "allows PNG as a supported format for backward compatibility" do
          tempfile = Tempfile.new(["task_graph", ".png"])
          begin
            exporter = SVG.new(SVGTestTask)
            exporter.save(tempfile.path, format: :png)

            expect(File.exist?(tempfile.path)).to be true
            expect(File.size(tempfile.path)).to be > 0
          ensure
            tempfile.close
            tempfile.unlink
          end
        end
      end

      describe ".export" do
        it "returns a string representation of the graph" do
          result = Operations::Exporters::SVG.export(SVGTestTask)
          expect(result).to be_a(String)
          expect(result).to include("<svg")
        end
      end
    end
  end
end
