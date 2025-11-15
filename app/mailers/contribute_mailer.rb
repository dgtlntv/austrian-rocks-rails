class ContributeMailer < ApplicationMailer
  def new_contribution_email
    @contribution = params[:contribution]
    mail(to: Rails.application.credentials.dig(:mailer, :contributor_emails), subject: "New contribution")
  end
end
