class ApplicationMailer < ActionMailer::Base
  default from: "#{BRAND_CONFIG[:name]} <#{BRAND_CONFIG[:contact][:email]}>"
  layout "mailer"
end
