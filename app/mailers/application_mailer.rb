class ApplicationMailer < ActionMailer::Base
  helper EmailEmbedImageHelper

  default from: TeSS::Config.sender_email
  layout 'mailer'
  before_action :set_headers

  private

  def set_headers
    return unless TeSS::Config.mailer
    (TeSS::Config.mailer['headers'] || {}).each do |key, value|
      headers[key] = value
    end
  end
end
