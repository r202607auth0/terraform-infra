##############################################################################
# attack_protection.tf – Attack Protection
# UC-06: Automatic Account Lockout (brute-force protection)
# UC-02 Req-3: Suspicious IP / impossible travel detection
##############################################################################

resource "auth0_attack_protection" "olb" {

  # ── Brute-Force Protection (UC-06) ─────────────────────────────────────
  # Lock account after [var.lockout_threshold] failed password attempts
  brute_force_protection {
    enabled      = true
    shields      = ["block", "user_notification"]
    allowlist    = []
    mode         = "count_per_identifier_and_ip"
    max_attempts = var.lockout_threshold # default 3 (UC-06)
    flags        = ["enroll_on_first_login"]
  }

  # ── Suspicious IP Throttling (UC-02 Req-3) ─────────────────────────────
  suspicious_ip_throttling {
    enabled   = true
    shields   = ["block", "admin_notification"]
    allowlist = []
    pre_login {
      max_attempts = 100
      rate         = 864000 # attempts per day
    }
    pre_user_registration {
      max_attempts = 50
      rate         = 1200
    }
  }

  # ── Breached Password Detection ─────────────────────────────────────────
  breached_password_detection {
    enabled                      = true
    shields                      = ["admin_notification", "block"]
    admin_notification_frequency = ["immediately"]
    method                       = "standard"
    pre_user_registration {
      shields = ["block"]
    }
  }
}
