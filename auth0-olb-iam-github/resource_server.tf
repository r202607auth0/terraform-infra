##############################################################################
# resource_server.tf – Auth0 Resource Servers (APIs)
# UC-04: Step-Up Auth – scoped API permissions for high-risk actions
# UC-10: Delegated Admin – delegate scopes
# UC-13: Support-Assisted Transaction – agent scoped token
##############################################################################

resource "auth0_resource_server" "olb_api" {
  name                                            = "Online Banking API – ${upper(var.environment)}"
  identifier                                      = "https://api.olb.${var.environment}.example.com"
  signing_alg                                     = "RS256"
  allow_offline_access                            = true
  token_lifetime                                  = 86400     # 24 h
  token_lifetime_for_web                          = 7200      # 2 h for browser sessions
  skip_consent_for_verifiable_first_party_clients = true
  enforce_policies                                = true
  token_dialect                                   = "access_token_authz"   # include permissions in token

  # ── Scopes ─────────────────────────────────────────────────────────────
  scopes {
    value       = "read:accounts"
    description = "View account balances and transactions"
  }
  scopes {
    value       = "write:transactions"
    description = "Initiate transactions (requires step-up for high-risk variants)"
  }
  scopes {
    value       = "manage:profile"
    description = "Update user profile information"
  }

  # UC-04 high-risk action scopes (Fraud Team requirements)
  scopes {
    value       = "step_up:update_profile_email"
    description = "UC-04: Update profile including email – requires step-up"
  }
  scopes {
    value       = "step_up:etransfer_recipients"
    description = "UC-04: Add/manage eTransfer recipients – requires step-up"
  }
  scopes {
    value       = "step_up:interac_profile"
    description = "UC-04: Create/edit Interac profile – requires step-up"
  }
  scopes {
    value       = "step_up:bill_payees"
    description = "UC-04: Add/manage bill payees – requires step-up"
  }
  scopes {
    value       = "step_up:cra_direct_deposit"
    description = "UC-04: CRA direct deposit registration – requires step-up"
  }
  scopes {
    value       = "step_up:manage_delegates"
    description = "UC-04 / UC-10: Add/manage delegates (B2B only) – requires step-up"
  }

  # UC-10: Delegated admin scopes
  scopes {
    value       = "delegate:read"
    description = "UC-10: Delegate read-only access to shared accounts"
  }
  scopes {
    value       = "delegate:initiate"
    description = "UC-10: Delegate can initiate transactions on shared accounts"
  }

  # UC-12 / UC-13: Support agent scopes
  scopes {
    value       = "support:reset_password"
    description = "UC-12: Support agent can trigger password reset for a customer"
  }
  scopes {
    value       = "support:assist_transaction"
    description = "UC-13: Support agent can assist with a verified high-risk transaction"
  }
  scopes {
    value       = "support:lock_account"
    description = "UC-14: Support agent can manually lock a customer account"
  }
  scopes {
    value       = "support:unlock_account"
    description = "UC-15: Support agent can unlock/unblock a customer account"
  }
}
