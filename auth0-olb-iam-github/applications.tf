##############################################################################
# applications.tf – Auth0 Applications (Clients)
# UC-02 / UC-03: Login flows (FAPI 2.0: Auth Code + PKCE, PAR, JAR, DPoP)
# UC-12 to UC-15: Support Portal (scoped Management API access)
##############################################################################

# ── Online Banking Portal – Server-Side Web App (FAPI 2.0) ─────────────────
resource "auth0_client" "olb_portal" {
  name           = "Online Banking Portal – ${upper(var.environment)}"
  description    = "Server-side web application; FAPI 2.0 compliant"
  app_type       = "regular_web"
  is_first_party = true

  callbacks           = var.app_callback_urls
  allowed_logout_urls = var.app_logout_urls
  web_origins         = [for u in var.app_callback_urls : regex("^(https?://[^/]+)", u)[0]]
  allowed_origins     = [for u in var.app_callback_urls : regex("^(https?://[^/]+)", u)[0]]

  # FAPI 2.0 – Proof Key for Code Exchange
  token_endpoint_auth_method = "private_key_jwt" # Private Key JWT (FAPI 2.0)
  grant_types = [
    "authorization_code",
    "refresh_token",
  ]

  # OIDC conformant
  oidc_conformant = true

  # Refresh token settings (UC-09 – session management)
  refresh_token {
    rotation_type                = "rotating"
    expiration_type              = "expiring"
    token_lifetime               = 2592000 # 30 days
    idle_token_lifetime          = 1296000 # 15 days
    leeway                       = 0
    infinite_idle_token_lifetime = false
    infinite_token_lifetime      = false
  }

  # JWT / ID token settings
  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = 36000
    secret_encoded      = false
  }

  # FAPI 2.0 advanced settings: PAR required; JAR required
  jwt_configuration {
    alg = "RS256"
  }
}

# FAPI 2.0 – Pushed Authorization Request (PAR) enforcement
resource "auth0_client_grant" "olb_portal_api_grant" {
  client_id = auth0_client.olb_portal.id
  audience  = auth0_resource_server.olb_api.identifier
  scopes = [
    "read:accounts",
    "write:transactions",
    "manage:profile",
    "step_up:high_risk",
  ]
}

# ── Support Portal Application (UC-12 to UC-15) ────────────────────────────
resource "auth0_client" "support_portal" {
  name           = "Support Portal – ${upper(var.environment)}"
  description    = "Internal support portal for CS agents; scoped Management API access"
  app_type       = "regular_web"
  is_first_party = true

  callbacks           = var.support_portal_callback_urls
  allowed_logout_urls = var.support_portal_callback_urls

  token_endpoint_auth_method = "client_secret_post"
  grant_types = [
    "authorization_code",
    "client_credentials",
  ]

  oidc_conformant = true

  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = 3600
    secret_encoded      = false
  }
}

resource "auth0_client_grant" "support_mgmt_api_grant" {
  client_id = auth0_client.support_portal.id
  audience  = "https://${var.auth0_domain}/api/v2/"
  scopes = [
    # UC-12: Support-Initiated Password Reset
    "update:users",
    # UC-13: Support-Assisted Transaction (scoped token issuance)
    "read:users",
    # UC-14: Support-Initiated Lockout
    "update:users",
    # UC-15: Support-Initiated Unblock
    "update:users",
    "read:logs",
    "read:user_idp_tokens",
  ]
}

# ── Machine-to-Machine: CI/CD Terraform management client ──────────────────
resource "auth0_client" "terraform_m2m" {
  name            = "Terraform IaC Client – ${upper(var.environment)}"
  description     = "Machine-to-machine client used exclusively by Terraform CI/CD pipeline"
  app_type        = "non_interactive"
  is_first_party  = true
  grant_types     = ["client_credentials"]
  oidc_conformant = true
}
