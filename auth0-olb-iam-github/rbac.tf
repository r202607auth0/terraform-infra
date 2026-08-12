##############################################################################
# rbac.tf – Roles & Permissions (RBAC)
# UC-10: Delegated Admin (delegate-readonly, delegate-initiator roles)
# UC-12–15: Support agent roles
##############################################################################

# ── Banking Customer role ───────────────────────────────────────────────────
resource "auth0_role" "banking_customer" {
  name        = "banking-customer"
  description = "Standard online banking customer – read accounts, initiate transactions"
}

resource "auth0_role_permissions" "banking_customer_perms" {
  role_id = auth0_role.banking_customer.id

  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "read:accounts"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "write:transactions"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "manage:profile"
  }
}

# ── Delegate – Read Only (UC-10) ───────────────────────────────────────────
resource "auth0_role" "delegate_readonly" {
  name        = "delegate-readonly"
  description = "UC-10: Delegate can VIEW accounts and balances only. Cannot move money."
}

resource "auth0_role_permissions" "delegate_readonly_perms" {
  role_id = auth0_role.delegate_readonly.id

  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "read:accounts"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "delegate:read"
  }
}

# ── Delegate – Initiator (UC-10) ──────────────────────────────────────────
resource "auth0_role" "delegate_initiator" {
  name        = "delegate-initiator"
  description = "UC-10: Delegate can VIEW accounts AND INITIATE transactions (dual-sig where applicable)"
}

resource "auth0_role_permissions" "delegate_initiator_perms" {
  role_id = auth0_role.delegate_initiator.id

  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "read:accounts"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "write:transactions"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "delegate:read"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "delegate:initiate"
  }
}

# ── Business / Signing Officer role (UC-10) ────────────────────────────────
resource "auth0_role" "signing_officer" {
  name        = "signing-officer"
  description = "UC-10: Business owner / signing officer who can create and manage delegates"
}

resource "auth0_role_permissions" "signing_officer_perms" {
  role_id = auth0_role.signing_officer.id

  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "read:accounts"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "write:transactions"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "manage:profile"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "step_up:manage_delegates"
  }
}

# ── Support Agent role (UC-12 to UC-15) ───────────────────────────────────
resource "auth0_role" "support_agent" {
  name        = "support-agent"
  description = "UC-12–15: CS agent – password reset, assisted transaction, lockout, unblock"
}

resource "auth0_role_permissions" "support_agent_perms" {
  role_id = auth0_role.support_agent.id

  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "support:reset_password"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "support:assist_transaction"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "support:lock_account"
  }
  permissions {
    resource_server_identifier = auth0_resource_server.olb_api.identifier
    name                       = "support:unlock_account"
  }
}
