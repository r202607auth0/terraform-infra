##############################################################################
# tenant.tf – Auth0 Tenant Core Settings
# Covers: Foundation for all UCs | FAPI 2.0 compliance baseline
##############################################################################

resource "auth0_tenant" "olb" {
  friendly_name = "Online Banking Portal – ${upper(var.environment)}"
  support_email = "iam-support@internal.example.com"
  support_url   = "https://support.example.com"

  # Session settings (UC-09 – Session / Device Activity)
  session_lifetime      = 8 # hours
  idle_session_lifetime = 2 # hours
  sandbox_version       = "18"
  enabled_locales       = ["en", "fr-CA"] # UC-01 Acceptance: English + French Canadian

  # Flags
  flags {
    universal_login                        = true
    disable_clickjack_protection_headers   = false
    enable_public_signup_user_exists_error = false # UC-07: no PII reveal
    no_disclose_enterprise_connections     = true
    disable_management_api_sms_obfuscation = false
  }

  # OIDC / session cookie settings
  oidc_logout {
    rp_initiated_logout = true
    backchannel_logout_initiators {
      mode                = "custom"
      selected_initiators = []
    }
  }

  # Universal Login pages (WCAG 2.1AA – UC-01 acceptance criteria)
  universal_login {
    colors {
      primary         = "#0A3D62"
      page_background = "#FFFFFF"
    }
  }
}
