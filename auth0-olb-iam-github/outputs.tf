##############################################################################
# outputs.tf – Exported Values for CI/CD and Downstream Consumption
##############################################################################

output "olb_portal_client_id" {
  description = "Client ID for the Online Banking Portal application"
  value       = auth0_client.olb_portal.client_id
}

output "support_portal_client_id" {
  description = "Client ID for the Support Portal application (UC-12–15)"
  value       = auth0_client.support_portal.client_id
  sensitive   = true
}

output "olb_api_identifier" {
  description = "Identifier (audience) for the Online Banking API resource server"
  value       = auth0_resource_server.olb_api.identifier
}

output "olb_connection_id" {
  description = "Auth0 connection ID for the main OLB user database"
  value       = auth0_connection.olb_users.id
}

output "legacy_connection_id" {
  description = "Auth0 connection ID for legacy username-based users (UC-03)"
  value       = auth0_connection.olb_legacy_users.id
}

output "role_banking_customer_id" {
  description = "Role ID for standard banking customers"
  value       = auth0_role.banking_customer.id
}

output "role_delegate_readonly_id" {
  description = "Role ID for read-only delegates (UC-10)"
  value       = auth0_role.delegate_readonly.id
}

output "role_delegate_initiator_id" {
  description = "Role ID for initiator delegates (UC-10)"
  value       = auth0_role.delegate_initiator.id
}

output "role_signing_officer_id" {
  description = "Role ID for business signing officers (UC-10)"
  value       = auth0_role.signing_officer.id
}

output "role_support_agent_id" {
  description = "Role ID for support agents (UC-12–15)"
  value       = auth0_role.support_agent.id
}

output "pre_user_reg_action_id" {
  description = "Action ID for Pre-User Registration CIF validation (UC-01)"
  value       = auth0_action.pre_user_registration_cif_validation.id
}

output "post_login_geo_block_action_id" {
  description = "Action ID for Post-Login Geo/IP Block (UC-02)"
  value       = auth0_action.post_login_geo_ip_block.id
}
