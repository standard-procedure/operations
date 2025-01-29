require "rails_helper"

module Examples
  RSpec.describe "README - Document Download example", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class PrepareDocumentForDownload < Operations::Task
      starts_with :authorised?

      decision :authorised? do
        if_true :within_download_limits?
        if_false { fail_with "unauthorised" }
      end

      decision :within_download_limits? do
        if_true :use_filename_scrambler?
        if_false { fail_with "download_limit_reached" }
      end

      decision :use_filename_scrambler? do
        condition { use_filename_scrambler }
        if_true :scramble_filename
        if_false :return_filename
      end

      action :scramble_filename do
        self.filename = "#{Faker::Lorem.word}#{File.extname(document.filename.to_s)}"
        go_to :return_filename
      end

      result :return_filename do |results|
        results.filename = filename || document.filename.to_s
      end

      private def authorised?(data) = data.user.can?(:read, data.document)
      private def within_download_limits?(data) = data.user.within_download_limits?
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "returns the original filename" do
      user = User.create! name: "Alice", has_permission: true, within_download_limits: true
      document = Document.create! filename: "document.pdf"

      task = PrepareDocumentForDownload.call user: user, document: document, use_filename_scrambler: false

      expect(task).to be_completed
      expect(task.results.filename).to eq "document.pdf"
    end

    it "scrambles the original filename" do
      user = User.create! name: "Alice", has_permission: true, within_download_limits: true
      document = Document.create! filename: "document.pdf"

      task = PrepareDocumentForDownload.call user: user, document: document, use_filename_scrambler: true

      expect(task).to be_completed
      expect(task.results.filename).to include ".pdf"
      expect(task.results.filename).to_not include "document"
    end

    it "fails if not authorised" do
      user = User.create! name: "Alice", has_permission: false, within_download_limits: true
      document = Document.create! filename: "document.pdf"

      task = PrepareDocumentForDownload.call user: user, document: document, use_filename_scrambler: false

      expect(task).to be_failed
      expect(task.results.failure_message).to eq "unauthorised"
    end

    it "fails if download limits have been reached" do
      user = User.create! name: "Alice", has_permission: true, within_download_limits: false
      document = Document.create! filename: "document.pdf"

      task = PrepareDocumentForDownload.call user: user, document: document, use_filename_scrambler: false

      expect(task).to be_failed
      expect(task.results.failure_message).to eq "download_limit_reached"
    end
  end
end
