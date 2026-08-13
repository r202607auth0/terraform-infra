##############################################################################
# terraform.prod.tfvars – PROD environment values
#
# NON-SECRET VALUES ONLY. This file is committed to source control.
#
# The GitHub Actions workflow injects the remaining values as TF_VAR_*
# environment variables.
#
# From repository VARIABLES (non-sensitive):
#   AUTH0_DOMAIN_PROD              -> TF_VAR_auth0_domain
#   AUTH0_CLIENT_ID_PROD           -> TF_VAR_auth0_mgmt_client_id
#   AWS_ACCOUNT_ID_PROD            -> TF_VAR_aws_account_id
#   AWS_REGION                      -> TF_VAR_aws_region
#
# From repository SECRETS (sensitive, masked in logs):
#   AUTH0_CLIENT_SECRET_PROD       -> TF_VAR_auth0_mgmt_client_secret
#   SENDGRID_API_KEY_PROD          -> TF_VAR_sendgrid_api_key
#   CIF_VALIDATION_API_SECRET_PROD -> TF_VAR_cif_validation_api_secret
#
# For a local run, export those TF_VAR_* variables in your shell first.
##############################################################################

environment = "prod"

app_callback_urls = [
  "https://olb.example.com/callback",
]

app_logout_urls = [
  "https://olb.example.com",
]

support_portal_callback_urls = [
  "https://support.example.com/callback",
]

cif_validation_api_url = "https://core-banking.example.com/api/cif/validate"

lockout_threshold     = 3   # UC-06: lock after 3 failed attempts
sspr_link_ttl_seconds = 900 # UC-07: 15-minute password reset link

# UC-02: Blocked geographies (ISO 3166-1 alpha-2)
blocked_countries = ["KP", "IR", "SY", "RU", "MM"]

max_delegates_per_business = 3 # UC-10
