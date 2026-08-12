##############################################################################
# terraform.qa.tfvars – QA environment values
#
# NON-SECRET VALUES ONLY. This file is committed to source control.
#
# The GitHub Actions workflow injects the remaining values as TF_VAR_*
# environment variables.
#
# From repository VARIABLES (non-sensitive):
#   AUTH0_DOMAIN_QA              -> TF_VAR_auth0_domain
#   AUTH0_CLIENT_ID_QA           -> TF_VAR_auth0_mgmt_client_id
#   AWS_ACCOUNT_ID_QA            -> TF_VAR_aws_account_id
#   AWS_REGION                      -> TF_VAR_aws_region
#
# From repository SECRETS (sensitive, masked in logs):
#   AUTH0_CLIENT_SECRET_QA       -> TF_VAR_auth0_mgmt_client_secret
#   SENDGRID_API_KEY_QA          -> TF_VAR_sendgrid_api_key
#   CIF_VALIDATION_API_SECRET_QA -> TF_VAR_cif_validation_api_secret
#
# For a local run, export those TF_VAR_* variables in your shell first.
##############################################################################

environment = "qa"

app_callback_urls = [
  "https://olb-qa.example.com/callback",
]

app_logout_urls = [
  "https://olb-qa.example.com",
]

support_portal_callback_urls = [
  "https://support-qa.example.com/callback",
]

cif_validation_api_url = "https://core-banking-qa.example.com/api/cif/validate"

lockout_threshold     = 3      # UC-06: lock after 3 failed attempts
sspr_link_ttl_seconds = 900    # UC-07: 15-minute password reset link

# UC-02: Blocked geographies (ISO 3166-1 alpha-2)
blocked_countries = ["KP", "IR", "SY", "RU", "MM"]

max_delegates_per_business = 3   # UC-10
