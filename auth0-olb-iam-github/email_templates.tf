##############################################################################
# email_templates.tf – Transactional Email Templates
# UC-01: Welcome / email verification
# UC-06: Account lockout notification
# UC-07: SSPR password reset (15-min TTL)
# UC-11: Security event notifications
##############################################################################

resource "auth0_email_provider" "sendgrid" {
  name         = "sendgrid"
  enabled      = true
  default_from_address = "noreply@olb.example.com"

  credentials {
    api_key = var.sendgrid_api_key
  }
}

# UC-01 / UC-02 Req-5 – Email Verification
resource "auth0_email_template" "verify_email" {
  template  = "verify_email"
  enabled   = true
  from      = "noreply@olb.example.com"
  subject   = "Verify your email address – Online Banking"
  syntax    = "liquid"
  url_lifetime_in_seconds = 86400

  body = <<-HTML
    <html>
      <body>
        <p>Please verify your email address by clicking the link below.</p>
        <p><a href="{{ url }}">Verify Email Address</a></p>
        <p>This link expires in 24 hours.</p>
        <p>If you did not request this, please contact support immediately.</p>
        <hr/>
        <p><em>Ne partagez ce lien avec personne / Do not share this link with anyone.</em></p>
      </body>
    </html>
  HTML
}

# UC-07 – Self-Service Password Reset (15-min TTL)
resource "auth0_email_template" "reset_email" {
  template  = "reset_email"
  enabled   = true
  from      = "noreply@olb.example.com"
  subject   = "Reset your Online Banking password"
  syntax    = "liquid"
  url_lifetime_in_seconds = var.sspr_link_ttl_seconds   # 900 seconds = 15 min

  body = <<-HTML
    <html>
      <body>
        <p>You requested a password reset for your Online Banking account.</p>
        <p><a href="{{ url }}">Reset Password</a></p>
        <p><strong>This link expires in 15 minutes.</strong></p>
        <p>If you did not request this, your account may be at risk – contact support immediately.</p>
      </body>
    </html>
  HTML
}

# UC-06 – Account Locked notification (password failure)
resource "auth0_email_template" "blocked_account" {
  template  = "blocked_account"
  enabled   = true
  from      = "noreply@olb.example.com"
  subject   = "Your Online Banking account has been locked"
  syntax    = "liquid"
  url_lifetime_in_seconds = 432000

  body = <<-HTML
    <html>
      <body>
        <p>Your account has been locked due to multiple failed login attempts.</p>
        <p>To unlock your account, click the link below or contact our support team.</p>
        <p><a href="{{ url }}">Unlock Account / Reset Password</a></p>
        <p>If you did not attempt to log in, please contact support immediately.</p>
      </body>
    </html>
  HTML
}

# UC-11 – Stolen Credentials warning
resource "auth0_email_template" "stolen_credentials" {
  template  = "stolen_credentials"
  enabled   = true
  from      = "noreply@olb.example.com"
  subject   = "Security Alert – Online Banking"
  syntax    = "liquid"
  url_lifetime_in_seconds = 432000

  body = <<-HTML
    <html>
      <body>
        <p>We detected a security concern with your Online Banking account.</p>
        <p>Please reset your password immediately and contact our support team.</p>
        <p><a href="{{ url }}">Reset Password Now</a></p>
      </body>
    </html>
  HTML
}

# UC-01 – Welcome email (sent by Action after successful registration)
resource "auth0_email_template" "welcome_email" {
  template  = "welcome_email"
  enabled   = true
  from      = "noreply@olb.example.com"
  subject   = "Welcome to Online Banking"
  syntax    = "liquid"
  url_lifetime_in_seconds = 432000

  body = <<-HTML
    <html>
      <body>
        <p>Welcome, {{ user.given_name }}!</p>
        <p>Your Online Banking account has been successfully registered.</p>
        <p>If you did not register, please contact support immediately.</p>
      </body>
    </html>
  HTML
}

# UC-01 – Change password (forced on first login / support-initiated reset)
resource "auth0_email_template" "change_password" {
  template  = "change_password"
  enabled   = true
  from      = "noreply@olb.example.com"
  subject   = "Change your Online Banking password"
  syntax    = "liquid"
  url_lifetime_in_seconds = var.sspr_link_ttl_seconds

  body = <<-HTML
    <html>
      <body>
        <p>A password change has been requested for your Online Banking account.</p>
        <p><a href="{{ url }}">Change Password</a></p>
        <p>This link expires in 15 minutes.</p>
      </body>
    </html>
  HTML
}
