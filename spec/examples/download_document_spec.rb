# require "rails_helper"

# module Examples
#   RSpec.describe "Download Document", type: :model do
#     # standard:disable Lint/ConstantDefinitionInBlock
#     class DownloadDocument < Operations::Task
#       data :user
#       validates :user, presence: true
#       data :document
#       validates :document, presence: true
#       data :use_filename_scrambler, :boolean, default: false
#       validates :use_filename_scrambler, presence: true
#       data :filename, :string
#       validates :filename, presence: true

#       starts_with :authorised?

#       decision :authorised? do
#         if_true :within_download_limits?
#         if_false :fail, "unauthorised"
#       end

#       decision :within_download_limits? do
#         if_true :check_filename_scrambler
#         if_false :fail, "download_limit_reached"
#       end

#       decision :use_filename_scrambler? do
#         if_true :scramble_filename
#         if_false :prepare_download
#       end

#       action :scramble_filename

#       completed :prepare_download do |results|
#         results[:filename] = filename || document.filename.to_s
#       end

#       private def authorised? = user.can?(:read, document)
#       private def within_download_limits? = user.within_download_limits?
#       private def scramble_filename
#         self.filename = "#{Faker::Lorem.word}#{File.extname(document.filename.to_s)}"
#         go_to :prepare_download
#       end
#     end
#     # standard:disable Lint/ConstantDefinitionInBlock
#   end
# end
