##############################################################################
# connection.tf – Database Connection + Password Policy
# UC-01: User Registration (password complexity)
# UC-06: Account Lockout (brute-force via connection settings)
# UC-07: SSPR (password complexity + no reuse)
##############################################################################

resource "auth0_connection" "olb_users" {
  name         = "olb-users-${var.environment}"
  strategy     = "auth0"
  display_name = "Online Banking Users – ${upper(var.environment)}"

  options {
    # ── Password Policy (UC-01, UC-07) ─────────────────────────────────────
    # Requirements: 12+ chars | upper | lower | digit | special char
    password_policy = "excellent"   # Auth0 "excellent" = longest policy baseline

    password_complexity_options {
      min_length = 12
    }

    password_history {
      enable = true
      size   = 5   # UC-07: no reuse of last 5 passwords
    }

    password_no_personal_info {
      enable = true  # Prevent name/email in password
    }

    password_dictionary {
      enable     = true
      dictionary = []
    }

    # ── Brute-Force / Lockout (UC-06) ──────────────────────────────────────
    brute_force_protection = true

    # ── Registration / Login settings (UC-01, UC-02) ───────────────────────
    disable_signup           = true   # Self-registration is gated (CIF validation required)
    requires_username        = false  # Email is primary identifier for new users
    enabled_database_customization = false

    # ── Email verification (UC-02 Req-5) ───────────────────────────────────
    # Email verification is enforced via Post-Login Action (actions.tf)
    # Set_user_root_attributes handles email updates
    set_user_root_attributes     = "on_each_login"
    non_persistent_attrs         = []

    # ── Import mode for legacy users (UC-03) ───────────────────────────────
    import_mode = false   # Legacy users migrated via custom action; not bulk import
  }
}

# Legacy connection – for username-based (non-email) legacy users (UC-03)
resource "auth0_connection" "olb_legacy_users" {
  name         = "olb-legacy-users-${var.environment}"
  strategy     = "auth0"
  display_name = "Online Banking Legacy Users – ${upper(var.environment)}"

  options {
    password_policy = "excellent"
    password_complexity_options {
      min_length = 12
    }
    password_history {
      enable = true
      size   = 5
    }
    password_no_personal_info {
      enable = true
    }
    brute_force_protection   = true
    disable_signup           = true
    requires_username        = true  # Legacy system: username (not email) as identifier
    set_user_root_attributes = "on_each_login"
  }
}
