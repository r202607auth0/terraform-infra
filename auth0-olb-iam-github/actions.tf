##############################################################################
# actions.tf – Auth0 Actions (Pre-User Reg + Post-Login)
#
# UC-01: User Registration – CIF validation, email verify, MFA enroll
# UC-02: New User Login – geo/IP block, risk-based MFA, email verify
# UC-03: Legacy User Login – email collection/validation, MFA enroll
# UC-04: Step-Up Authentication – high-risk action detection
# UC-05: MFA enrollment hierarchy enforcement
# UC-06: Account Lockout – notify on password-failure lock
# UC-09: Session / Device Activity – enrich login event log
# UC-10: Delegated Admin – delegate metadata + role enforcement
# UC-11: User Notifications – event-driven security alerts
#
# ---------------------------------------------------------------------------
# NOTE ON HEREDOC INTERPOLATION (fixes "Extra characters after interpolation
# expression"):
#   Terraform parses ${ ... } inside heredocs as its OWN interpolation. Any
#   JavaScript template literal that needs a runtime ${ ... } must therefore be
#   escaped as $${ ... } so Terraform emits a literal ${ ... } to Auth0.
#   Genuine Terraform interpolations (e.g. ${var.environment}) live OUTSIDE the
#   heredocs, in resource attributes, and remain single-$.
# ---------------------------------------------------------------------------
##############################################################################

# ══════════════════════════════════════════════════════════════════════════
# ACTION 1 – Pre-User Registration: CIF Validation (UC-01)
# ══════════════════════════════════════════════════════════════════════════
resource "auth0_action" "pre_user_registration_cif_validation" {
  name    = "pre-user-reg-cif-validation-${var.environment}"
  runtime = "node18"
  deploy  = true

  code = <<-JS
    /**
     * UC-01: Pre-User Registration Action
     * Validates the CIF (Customer Information File) number provided during signup
     * against the core banking system before creating the Auth0 user record.
     *
     * CIF length rules:
     *   Bank customers  = 5 digits
     *   Trust customers = 6 digits
     */
    const axios = require('axios');

    exports.onExecutePreUserRegistration = async (event, api) => {
      const cif = event.user.user_metadata?.cif_number;

      if (!cif) {
        api.access.deny('CIF number is required to register for Online Banking.');
        return;
      }

      // Determine customer type from CIF length
      const customerType = cif.length === 5 ? 'bank' : cif.length === 6 ? 'trust' : null;
      if (!customerType) {
        api.access.deny('Invalid CIF format. Please check your account number and try again.');
        return;
      }

      try {
        const response = await axios.post(
          event.secrets.CIF_VALIDATION_API_URL,
          { cif, customer_type: customerType },
          {
            headers: {
              'x-api-key': event.secrets.CIF_VALIDATION_API_SECRET,
              'Content-Type': 'application/json',
            },
            timeout: 5000,
          }
        );

        if (!response.data?.valid) {
          api.access.deny('We could not verify your account details. Please contact support.');
          return;
        }

        // Store customer type in app_metadata for downstream use
        api.user.setAppMetadata('customer_type', customerType);
        api.user.setAppMetadata('cif_number', cif);
        api.user.setAppMetadata('require_mfa_enrollment', true);
        api.user.setAppMetadata('dsa_accepted', false);

      } catch (err) {
        console.error('CIF validation error:', err.message);
        // Fail closed: deny registration if validation service is unavailable
        api.access.deny('Account verification is temporarily unavailable. Please try again later.');
      }
    };
  JS

  supported_triggers {
    id      = "pre-user-registration"
    version = "v2"
  }

  dependencies {
    name    = "axios"
    version = "1.6.2"
  }

  secrets {
    name  = "CIF_VALIDATION_API_URL"
    value = var.cif_validation_api_url
  }
  secrets {
    name  = "CIF_VALIDATION_API_SECRET"
    value = var.cif_validation_api_secret
  }
}

# ══════════════════════════════════════════════════════════════════════════
# ACTION 2 – Post-Login: Geo/IP Block + Risk-Based MFA (UC-02, UC-03)
# ══════════════════════════════════════════════════════════════════════════
resource "auth0_action" "post_login_geo_ip_block" {
  name    = "post-login-geo-ip-block-${var.environment}"
  runtime = "node18"
  deploy  = true

  code = <<-JS
    /**
     * UC-02 Req-3 / Req-4 – Post-Login Action
     * 1. Block logins from restricted geographies (DPRK, Iran, Syria, Russia, Myanmar, Crimea)
     * 2. Block logins from banned IP addresses (PM-57775 list)
     * 3. Trigger risk-based MFA (Impossible Travel, New Device, untrusted IP)
     * 4. UC-02 Req-5: Enforce email verification
     * 5. UC-03: Legacy user – collect email if not on file
     */

    exports.onExecutePostLogin = async (event, api) => {
      // ── 1. Geographic Block (UC-02) ──────────────────────────────────
      const BLOCKED_COUNTRIES = JSON.parse(event.secrets.BLOCKED_COUNTRIES_JSON);
      const userCountry = event.request.geoip?.country_code;

      if (userCountry && BLOCKED_COUNTRIES.includes(userCountry)) {
        api.access.deny(
          `Access is not permitted from your location ($${userCountry}). ` +
          'Please contact support if you believe this is an error.'
        );
        return;
      }

      // ── 2. Banned IP Block (UC-02 Req-3) ─────────────────────────────
      const bannedIPs = JSON.parse(event.secrets.BANNED_IPS_JSON || '[]');
      if (bannedIPs.includes(event.request.ip)) {
        api.access.deny('Access from your network has been restricted.');
        return;
      }

      // ── 3. Email Verification Enforcement (UC-02 Req-5) ──────────────
      if (!event.user.email_verified) {
        api.access.deny(
          'Please verify your email address before logging in. ' +
          'Check your inbox for a verification email.'
        );
        return;
      }

      // ── 4. DSA Acceptance Gate (UC-01 – new users) ───────────────────
      const dsaAccepted = event.user.app_metadata?.dsa_accepted;
      if (dsaAccepted === false) {
        api.redirect.sendUserTo('https://olb.example.com/dsa-consent', {
          query: { state: api.redirect.encodeToken({ secret: event.secrets.REDIRECT_SECRET, expiresInSeconds: 300 }) }
        });
        return;
      }

      // ── 5. Risk-Based MFA Trigger (UC-02 Req-3 / Req-4) ─────────────
      const riskFactors = event.authentication?.riskAssessment?.assessments;
      const isRisky = (
        riskFactors?.ImpossibleTravel?.confidence === 'high' ||
        riskFactors?.NewDevice?.confidence === 'high' ||
        riskFactors?.UntrustedIP?.confidence === 'high'
      );

      if (isRisky) {
        // Adaptive MFA – challenge with Email OTP or TOTP
        api.multifactor.enable('any', { allowRememberBrowser: false });
      }

      // ── 6. UC-03: Legacy user – email collection redirect ─────────────
      const isLegacyUser = event.user.app_metadata?.is_legacy_user === true;
      const hasEmail     = !!event.user.email;

      if (isLegacyUser && !hasEmail) {
        api.redirect.sendUserTo('https://olb.example.com/collect-email', {
          query: {
            state: api.redirect.encodeToken({
              secret: event.secrets.REDIRECT_SECRET,
              expiresInSeconds: 300,
              payload: { user_id: event.user.user_id }
            })
          }
        });
        return;
      }

      // ── 7. MFA Enrollment Gate (UC-01 / UC-05) ───────────────────────
      if (event.user.app_metadata?.require_mfa_enrollment === true) {
        api.multifactor.enable('any', { allowRememberBrowser: false });
      }

      // ── 8. Enrich Access Token with roles + customer metadata ─────────
      const roles = event.authorization?.roles || [];
      api.accessToken.setCustomClaim('https://olb.example.com/roles', roles);
      api.accessToken.setCustomClaim('https://olb.example.com/customer_type',
        event.user.app_metadata?.customer_type || 'standard');
      api.accessToken.setCustomClaim('https://olb.example.com/delegate_of',
        event.user.app_metadata?.delegate_of || null);
    };
  JS

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  secrets {
    name  = "BLOCKED_COUNTRIES_JSON"
    value = jsonencode(var.blocked_countries)
  }
  secrets {
    name  = "BANNED_IPS_JSON"
    value = jsonencode([]) # Populated once PM-57775 is completed
  }
  secrets {
    name  = "REDIRECT_SECRET"
    value = random_password.redirect_secret.result
  }
}

# ══════════════════════════════════════════════════════════════════════════
# ACTION 3 – Post-Login: Step-Up Authentication (UC-04)
# ══════════════════════════════════════════════════════════════════════════
resource "auth0_action" "post_login_step_up" {
  name    = "post-login-step-up-${var.environment}"
  runtime = "node18"
  deploy  = true

  code = <<-JS
    /**
     * UC-04: Step-Up Authentication
     *
     * Triggered when the online banking portal signals a high-risk action via
     * the acr_values or a custom claim in the authorization request.
     *
     * High-risk actions (Fraud Team requirements):
     *   1. Update profile including email
     *   2. Add/manage eTransfer recipients
     *   3. Create/edit Interac Profile
     *   4. Add/manage bill payees
     *   5. CRA Direct Deposit Registration
     *   6. Add/manage Delegates (B2B only)
     *
     * Option 1: Always challenge with specific MFA factor for high-risk actions
     * Option 2: Only challenge if MFA not already completed at login (conditional)
     */

    exports.onExecutePostLogin = async (event, api) => {
      // Detect high-risk action intent from the authorization request
      const requestedAcr    = event.transaction?.requested_authorization_details;
      const highRiskScope   = event.transaction?.requested_scopes?.find(s => s.startsWith('step_up:'));
      const acr             = event.transaction?.acr_values;

      const HIGH_RISK_SCOPES = [
        'step_up:update_profile_email',
        'step_up:etransfer_recipients',
        'step_up:interac_profile',
        'step_up:bill_payees',
        'step_up:cra_direct_deposit',
        'step_up:manage_delegates',
      ];

      const isHighRiskRequest = HIGH_RISK_SCOPES.some(s =>
        (event.transaction?.requested_scopes || []).includes(s)
      );

      if (!isHighRiskRequest) return;  // No step-up needed

      const completedMFAAt = event.authentication?.methods?.find(m => m.name === 'mfa');

      // Option 2: Conditional – only challenge if MFA not done in this session
      const STEP_UP_OPTION = event.secrets.STEP_UP_OPTION || 'option2';

      if (STEP_UP_OPTION === 'option1') {
        // Always challenge, regardless of prior MFA in session
        api.multifactor.enable('any', { allowRememberBrowser: false });
      } else {
        // Option 2: Only if MFA was not completed during current login
        if (!completedMFAAt) {
          api.multifactor.enable('any', { allowRememberBrowser: false });
        }
      }

      // UC-04 Acceptance Criteria: Log attempt for auditing
      console.log(JSON.stringify({
        event_type: 'step_up_triggered',
        user_id:    event.user.user_id,
        scopes:     event.transaction?.requested_scopes,
        ip:         event.request.ip,
        timestamp:  new Date().toISOString(),
      }));

      // UC-04 Acceptance Criteria: Notify user of the high-risk action attempt
      // Notification is handled by UC-11 Notification Action (runs after this)
    };
  JS

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  secrets {
    name  = "STEP_UP_OPTION"
    value = "option2" # Change to "option1" if always-challenge is preferred
  }
}

# ══════════════════════════════════════════════════════════════════════════
# ACTION 4 – Post-Login: Account Lockout Email Notification (UC-06)
# ══════════════════════════════════════════════════════════════════════════
resource "auth0_action" "post_login_lockout_notify" {
  name    = "post-login-lockout-notify-${var.environment}"
  runtime = "node18"
  deploy  = true

  code = <<-JS
    /**
     * UC-06: Account Lockout – Email notification on password-failure lock
     *
     * Auth0 OOTB brute-force sends a notification; this action fills the gap
     * identified in the current-state assessment (gap #1):
     * "No email notification is sent when account locks due to failed password attempts."
     *
     * This action fires on the login event that triggers the lockout.
     */
    const axios = require('axios');

    exports.onExecutePostLogin = async (event, api) => {
      // Auth0 sets stats.loginsCount; failed attempt count tracked via OOTB brute-force
      // This action specifically handles: send notification email when account is now blocked
      if (!event.user.blocked) return;

      const emailPayload = {
        to:       event.user.email,
        template: 'account_locked',
        dynamic_template_data: {
          first_name: event.user.given_name || 'Customer',
          ip_address: event.request.ip,
          timestamp:  new Date().toLocaleString('en-CA', { timeZone: 'America/Toronto' }),
          support_url: 'https://olb.example.com/support',
        }
      };

      try {
        await axios.post(
          event.secrets.NOTIFICATION_SERVICE_URL + '/send-email',
          emailPayload,
          { headers: { 'x-api-key': event.secrets.NOTIFICATION_SERVICE_KEY }, timeout: 3000 }
        );
      } catch (err) {
        // Non-blocking: log failure but do not interrupt auth flow
        console.error('Lockout notification failed:', err.message);
      }
    };
  JS

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  dependencies {
    name    = "axios"
    version = "1.6.2"
  }

  secrets {
    name  = "NOTIFICATION_SERVICE_URL"
    value = "https://notifications.olb.${var.environment}.example.com"
  }
  secrets {
    name  = "NOTIFICATION_SERVICE_KEY"
    value = var.sendgrid_api_key
  }
}

# ══════════════════════════════════════════════════════════════════════════
# ACTION 5 – Post-Login: Security Event Notifications (UC-11)
# ══════════════════════════════════════════════════════════════════════════
resource "auth0_action" "post_login_security_notifications" {
  name    = "post-login-security-notifications-${var.environment}"
  runtime = "node18"
  deploy  = true

  code = <<-JS
    /**
     * UC-11: User Notifications
     * Event-driven email notifications for security-sensitive actions:
     *   - Login from new device
     *   - Successful step-up for high-risk action
     *   - Profile change detected
     *   - Login from unusual location
     */
    const axios = require('axios');

    exports.onExecutePostLogin = async (event, api) => {
      const notifications = [];
      const riskFactors   = event.authentication?.riskAssessment?.assessments;

      // New device login alert
      if (riskFactors?.NewDevice?.confidence === 'high') {
        notifications.push({
          type: 'new_device_login',
          message: `Your account was accessed from a new device on $${new Date().toLocaleString('en-CA', { timeZone: 'America/Toronto' })}.`,
        });
      }

      // Unusual location alert
      if (riskFactors?.ImpossibleTravel?.confidence === 'high') {
        notifications.push({
          type: 'unusual_location',
          message: 'Your account was accessed from an unusual location.',
        });
      }

      // Step-up high-risk action notification
      const highRiskScope = (event.transaction?.requested_scopes || []).find(s => s.startsWith('step_up:'));
      if (highRiskScope) {
        notifications.push({
          type: 'high_risk_action_attempted',
          message: `A sensitive action ($${highRiskScope.replace('step_up:', '')}) was attempted on your account.`,
        });
      }

      if (notifications.length === 0) return;

      try {
        await axios.post(
          event.secrets.NOTIFICATION_SERVICE_URL + '/security-alert',
          {
            user_id:       event.user.user_id,
            email:         event.user.email,
            notifications,
            ip:            event.request.ip,
            country:       event.request.geoip?.country_name,
            timestamp:     new Date().toISOString(),
          },
          { headers: { 'x-api-key': event.secrets.NOTIFICATION_SERVICE_KEY }, timeout: 3000 }
        );
      } catch (err) {
        console.error('Security notification failed:', err.message);
      }
    };
  JS

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  dependencies {
    name    = "axios"
    version = "1.6.2"
  }

  secrets {
    name  = "NOTIFICATION_SERVICE_URL"
    value = "https://notifications.olb.${var.environment}.example.com"
  }
  secrets {
    name  = "NOTIFICATION_SERVICE_KEY"
    value = var.sendgrid_api_key
  }
}

# ══════════════════════════════════════════════════════════════════════════
# ACTION 6 – Post-Login: Delegated Admin Token Enrichment (UC-10)
# ══════════════════════════════════════════════════════════════════════════
resource "auth0_action" "post_login_delegate_enrichment" {
  name    = "post-login-delegate-enrichment-${var.environment}"
  runtime = "node18"
  deploy  = true

  code = <<-JS
    /**
     * UC-10: Delegated Admin Management
     * Enriches the access token with delegate context:
     *   - Marks token as delegate session
     *   - Embeds shared account access list
     *   - Applies role-scoped access level (read-only vs initiator)
     *   - Enforces time-bound access if configured
     */
    exports.onExecutePostLogin = async (event, api) => {
      const isDelegate   = event.user.app_metadata?.user_type === 'delegate';
      if (!isDelegate) return;

      const delegateOf     = event.user.app_metadata?.delegate_of;        // parent signing officer ID
      const accessLevel    = event.user.app_metadata?.access_level;       // 'readonly' | 'initiator'
      const sharedAccounts = event.user.app_metadata?.shared_accounts || [];
      const expiresAt      = event.user.app_metadata?.delegate_expires_at;

      // Time-bound access enforcement
      if (expiresAt && new Date() > new Date(expiresAt)) {
        api.access.deny('Your delegate access has expired. Please contact your account administrator.');
        return;
      }

      // Enrich token with delegate context
      api.accessToken.setCustomClaim('https://olb.example.com/is_delegate', true);
      api.accessToken.setCustomClaim('https://olb.example.com/delegate_of', delegateOf);
      api.accessToken.setCustomClaim('https://olb.example.com/delegate_access_level', accessLevel);
      api.accessToken.setCustomClaim('https://olb.example.com/shared_accounts', sharedAccounts);

      // Log delegate session for audit (UC-10: time-bound + audited)
      console.log(JSON.stringify({
        event_type:    'delegate_session_started',
        delegate_id:   event.user.user_id,
        delegate_of:   delegateOf,
        access_level:  accessLevel,
        shared_accounts: sharedAccounts,
        ip:            event.request.ip,
        timestamp:     new Date().toISOString(),
      }));
    };
  JS

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }
}

# ══════════════════════════════════════════════════════════════════════════
# Random secret for redirect token signing
# ══════════════════════════════════════════════════════════════════════════
resource "random_password" "redirect_secret" {
  length  = 64
  special = false
}

# ══════════════════════════════════════════════════════════════════════════
# ACTION FLOW – Attach Actions to Post-Login trigger in correct order
# ══════════════════════════════════════════════════════════════════════════
resource "auth0_trigger_actions" "post_login_flow" {
  trigger = "post-login"

  actions {
    id           = auth0_action.post_login_geo_ip_block.id
    display_name = "1. Geo-IP Block + Email Verify + Legacy Email Collect"
  }
  actions {
    id           = auth0_action.post_login_step_up.id
    display_name = "2. Step-Up Authentication (UC-04)"
  }
  actions {
    id           = auth0_action.post_login_delegate_enrichment.id
    display_name = "3. Delegate Token Enrichment (UC-10)"
  }
  actions {
    id           = auth0_action.post_login_lockout_notify.id
    display_name = "4. Lockout Email Notification (UC-06)"
  }
  actions {
    id           = auth0_action.post_login_security_notifications.id
    display_name = "5. Security Event Notifications (UC-11)"
  }
}

# Pre-User Registration flow
resource "auth0_trigger_actions" "pre_user_registration_flow" {
  trigger = "pre-user-registration"

  actions {
    id           = auth0_action.pre_user_registration_cif_validation.id
    display_name = "1. CIF Validation (UC-01)"
  }
}
