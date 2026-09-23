# Who may sign in, and who is an admin. For now only the admins may: the
# addresses in ADMIN_EMAILS (comma separated). Anyone else is turned away before
# anything about them is stored. OPEN_LOGIN=1 lets everyone sign in, for when
# signing in is opened to all visitors (they sign in as ordinary users).
#
# The address must be one the provider has verified, so no one can sign in with
# an admin's address they don't own.
module LoginPolicy
  module_function

  def admin_emails
    ENV.fetch("ADMIN_EMAILS", "").split(",").map { |email| normalize(email) }.reject(&:empty?)
  end

  def admin?(email)
    admin_emails.include?(normalize(email))
  end

  def open?
    ENV["OPEN_LOGIN"] == "1"
  end

  def allowed?(email, verified:)
    verified && email.present? && (open? || admin?(email))
  end

  def normalize(email)
    email.to_s.strip.downcase
  end
end
