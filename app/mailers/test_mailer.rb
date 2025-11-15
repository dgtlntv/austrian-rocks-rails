class TestMailer < ApplicationMailer
  def test_email
    mail(to: Rails.application.credentials.dig(:mailer, :contributor_emails), subject: "Test")
  end
end
