require "rails_helper"

module Examples
  RSpec.describe "Downloads Task Examples", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock

    # Simple download preparation task
    class PrepareDownload < Operations::Task
      inputs :account, :project_member, :revision
      optional :folder, :document

      starts_with :use_filename_scrambler?

      decision :use_filename_scrambler? do
        condition { project_member.scramble_downloaded_filenames? }

        if_true :generate_scrambled_filename
        if_false :use_original_filename
      end

      action :generate_scrambled_filename do
        self.filename = "#{task.random_name}.#{revision.file_extension}"
      end
      go_to :use_dynamic_document_generator?

      action :use_original_filename do
        self.filename = revision.name_with_extension
      end
      go_to :use_dynamic_document_generator?

      decision :use_dynamic_document_generator? do
        condition { project_member.dynamic_document_generator? && project_member.has_dynamic_document_generator_field_mapping? }

        if_true :generate_dynamic_document
        if_false :use_revision
      end

      action :generate_dynamic_document do
        call Document::Revision::GenerateDynamicDocumentTask, account: account, project_member: project_member, revision: revision do |results|
          self.variation = results[:variation]
        end
      end
      go_to :has_variation?

      decision :has_variation? do
        condition { variation.nil? }

        if_true :use_revision
        if_false :use_variation
      end

      action :use_revision do
        self.download = revision
      end
      go_to :record_download

      action :use_variation do
        self.download = variation
      end
      go_to :record_download

      action :record_download do
        self.document ||= revision.document
        self.folder ||= document.folder
        folder.record_download_by project_member.user, revisions: [revision], completed: true
      end
      go_to :return_document_details

      result :return_document_details do |result|
        result.filename = filename
        result.download = download
      end

      def random_name = [Faker::Lorem.word, Time.now.to_i.to_s, Faker::Lorem.word].join("-")

      def url_for(attachment) = self.class.url_for(attachment)

      def self.url_for(attachment) = Rails.application.routes.url_helpers.rails_blob_url(attachment)
    end

    # Task with multiple conditions in a decision
    class PrepareDocumentForInlineViewerTask < Operations::Task
      inputs :account, :project_member, :revision
      optional :folder, :document
      starts_with :prepare_document

      decision :prepare_document do
        condition { revision.has_pdf? }
        go_to :return_document_details
        condition { revision.is_docx? }
        go_to :use_dynamic_document_generator?
        condition { revision.is_forge_document? }
        go_to :generate_3d_file
      end

      decision :use_dynamic_document_generator? do
        condition { project_member.project.dynamic_document_generator? && !project_member.project.dynamic_document_generator_field_mapping.empty? }

        if_true :generate_dynamic_document
        if_false :has_generated_pdf?
      end

      action :generate_dynamic_document do
        Document::Revision::GenerateDynamicDocumentTask.call account: account, project_member: project_member, revision: revision do |results|
          self.variation = results[:variation]
        end
      end
      go_to :generate_dynamic_pdf

      action :generate_dynamic_pdf do
        Document::Revision::ConvertToPdfTask.call account: account, project_member: project_member, revision: revision, variation: variation do |results|
          self.filepath = results[:filepath]
        end
      end
      go_to :upload_dynamic_pdf

      action :upload_dynamic_pdf do
        pdf = revision.upload_variation filepath, name: "generated_dynamic_document_pdf_conversion", user: project_member.user
        self.url = Document::Revision::PrepareDocumentForInlineViewerTask.get_url_for(pdf.file)
      end
      go_to :return_document_details

      decision :has_generated_pdf? do
        condition { revision.variation("pdf_conversion").present? }

        if_true :set_generated_pdf_details
        if_false :generate_pdf
      end

      action :set_generated_pdf_details do
        pdf = revision.variation("pdf_conversion")
        self.url = Document::Revision::PrepareDocumentForInlineViewerTask.get_url_for(pdf.file)
      end
      go_to :return_document_details

      action :generate_pdf do
        Document::Revision::ConvertToPdfTask.call project_member: project_member, revision: revision do |results|
          self.filepath = results[:filepath]
        end
      end
      go_to :upload_pdf

      action :upload_pdf do
        attachment = revision.upload_variation filepath, name: "pdf_conversion"
        self.url = Document::Revision::PrepareDocumentForInlineViewerTask.get_url_for(attachment)
      end
      go_to :return_document_details

      result :return_document_details do |result|
        result.user = project_member.user
        result.revision = revision
        result.document = document || revision.document
        result.folder = folder || result.document.folder
        result.url = url || Document::Revision::PrepareDocumentForInlineViewerTask.get_url_for(revision.file)
      end

      def self.get_url_for(attachment) = Rails.application.routes.url_helpers.rails_storage_proxy_path(attachment)
    end

    class GenerateDynamicDocumentTask < Operations::Task
      inputs :project_member, :revision
      starts_with :is_docx?

      decision :is_docx? do
        condition { revision.is_docx? }
        if_true :has_cached_document?
        if_false :no_document_to_generate
      end

      decision :has_cached_document? do
        condition { revision.variation("generated_dynamic_document", user: project_member.user).present? }
        if_true :get_variation_details
        if_false :generate_dynamic_document
      end

      action :generate_dynamic_document do
        self.filepath = revision.merge_with(field_data: project_member.dynamic_document_field_data).to_s
      end
      go_to :upload_generated_document

      action :upload_generated_document do
        self.variation = revision.upload_variation(filepath.to_s, name: "generated_dynamic_document", user: project_member.user)
      end
      go_to :return_document_details

      action :get_variation_details do
        self.variation = revision.variation("generated_dynamic_document", user: project_member.user)
      end
      go_to :return_document_details

      result :return_document_details do |results|
        results.variation = variation
      end

      result :no_document_to_generate
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    # Export tests to generate SVG visualizations
    describe "SVG Exports" do
      it "exports PrepareDownload task visualization to SVG" do
        exporter = Operations::Exporters::SVG.new(PrepareDownload)
        svg_path = File.join(File.dirname(__FILE__), "..", "..", "tmp", "prepare_download.svg")
        exporter.save(svg_path)
        expect(File.exist?(svg_path)).to be true
        puts "PrepareDownload SVG exported to: #{svg_path}"
      end

      it "exports PrepareDocumentForInlineViewerTask task visualization to SVG" do
        exporter = Operations::Exporters::SVG.new(PrepareDocumentForInlineViewerTask)
        svg_path = File.join(File.dirname(__FILE__), "..", "..", "tmp", "prepare_document_for_inline_viewer.svg")
        exporter.save(svg_path)
        expect(File.exist?(svg_path)).to be true
        puts "PrepareDocumentForInlineViewerTask SVG exported to: #{svg_path}"
      end

      it "exports GenerateDynamicDocumentTask task visualization to SVG" do
        exporter = Operations::Exporters::SVG.new(GenerateDynamicDocumentTask)
        svg_path = File.join(File.dirname(__FILE__), "..", "..", "tmp", "generate_dynamic_document.svg")
        exporter.save(svg_path)
        expect(File.exist?(svg_path)).to be true
        puts "GenerateDynamicDocumentTask SVG exported to: #{svg_path}"
      end
    end
  end
end
