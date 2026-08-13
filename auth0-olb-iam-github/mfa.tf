##############################################################################
# mfa.tf – MFA Policy (UC-05 MFA Factor Matrix)
#
# Factor Matrix:
#   Email OTP  – Out-of-Band  | Low      | AAL2   | Phase 1 ✓
#   TOTP       – In-Band      | Medium   | AAL2   | Phase 1 ✓
#   Push/Guardian – OOB       | High     | AAL2+  | Later phase (config only)
#   Passkeys   – N/A          | Very High| AAL3   | Later phase (config only)
#   SMS OTP    – EXCLUDED (struck through in requirements)
##############################################################################

resource "auth0_guardian" "mfa" {
  policy = "all-applications" # MFA required for all OLB sessions

  # ── Email OTP (UC-05 – Low strength / AAL2 / Phase 1) ──────────────────
  email = true

  # ── TOTP (UC-05 – Medium strength / AAL2 / Phase 1) ────────────────────
  otp = true

  # ── Push / Guardian SDK (UC-05 – High strength / AAL2+ / Later phase) ──
  push {
    amazon_sns {
      aws_access_key_id                 = "" # populate in later phase
      aws_region                        = ""
      aws_secret_access_key             = ""
      sns_apns_platform_application_arn = ""
      sns_gcm_platform_application_arn  = ""
    }
    custom_app {
      app_name        = ""
      apple_app_link  = ""
      google_app_link = ""
    }
  }

  # ── WebAuthn / Passkeys (UC-05 – Very High / AAL3 / Later phase) ────────
  webauthn_platform {
    # Enabled in later phase when mobile app is available
  }

  webauthn_roaming {
    # Passkeys config – later phase
  }

  # SMS OTP is intentionally NOT enabled (deprecated per UC-05 requirements)
  # sms is omitted
}

# MFA enrollment policy – enforced via Post-Login Action (see actions.tf)
# Logic summary:
#   - New user: mandatory enrollment in Email OTP AND TOTP at registration
#   - TOTP upgrade requires 2 lower factors (Email OTP + prior factor) OR low-risk account
#   - Push / Passkeys: enrollment gate = 2 lower factors OR low-risk account (later phase)
#   - Higher factor enrolled → only combination of lower factors usable at login (per UC-05)
