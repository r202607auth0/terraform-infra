##############################################################################
# variables.tf – Input Variables
##############################################################################

variable "environment" {
  description = "Target environment: dev | qa | staging | prod"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, staging, prod"
  }
}

variable "auth0_domain" {
  description = "Auth0 tenant domain (e.g. your-tenant.us.auth0.com)"
  type        = string
  sensitive   = true
}

variable "auth0_mgmt_client_id" {
  description = "Management API client ID"
  type        = string
  sensitive   = true
}

variable "auth0_mgmt_client_secret" {
  description = "Management API client secret"
  type        = string
  sensitive   = true
}

variable "app_callback_urls" {
  description = "Allowed callback URLs for the Online Banking Portal application"
  type        = list(string)
}

variable "app_logout_urls" {
  description = "Allowed logout URLs for the Online Banking Portal application"
  type        = list(string)
}

variable "support_portal_callback_urls" {
  description = "Allowed callback URLs for the Support Portal application"
  type        = list(string)
}

variable "sendgrid_api_key" {
  description = "SendGrid API key for transactional emails (lockout, SSPR, notifications)"
  type        = string
  sensitive   = true
}

variable "cif_validation_api_url" {
  description = "Core banking API endpoint for CIF validation during registration"
  type        = string
}

variable "cif_validation_api_secret" {
  description = "Shared secret for the CIF validation API"
  type        = string
  sensitive   = true
}

variable "lockout_threshold" {
  description = "Number of failed attempts before account lockout (UC-06)"
  type        = number
  default     = 3
}

variable "sspr_link_ttl_seconds" {
  description = "Password reset link TTL in seconds (UC-07 – default 15 min)"
  type        = number
  default     = 900
}

variable "blocked_countries" {
  description = "ISO-3166-1 alpha-2 country codes blocked from accessing the portal (UC-02)"
  type        = list(string)
  default     = ["KP", "IR", "SY", "RU", "MM"]  # DPRK, Iran, Syria, Russia, Myanmar
  # Crimea / occupied Ukraine regions handled via IP blocklist (PM-57775)
}

variable "max_delegates_per_business" {
  description = "Maximum delegate accounts per business customer (UC-10)"
  type        = number
  default     = 3
}

##############################################################################
# AWS – used by the EventBridge log stream sink (log_streams.tf).
#
# These are NOT credentials and are not used to authenticate anything. The
# pipeline's own AWS auth (for the S3 state backend) is handled by GitHub OIDC
# role assumption in .github/actions/terraform-setup.
#
# Both are supplied by the workflow from repository VARIABLES:
#   AWS_ACCOUNT_ID_<ENV> -> TF_VAR_aws_account_id
#   AWS_REGION           -> TF_VAR_aws_region
##############################################################################

variable "aws_account_id" {
  description = "12-digit AWS account ID that receives the Auth0 EventBridge partner event source"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be exactly 12 digits (e.g. 123456789012)."
  }
}

variable "aws_region" {
  description = "AWS region for the EventBridge partner event source and the S3 state bucket"
  type        = string
  default     = "us-east-1"
  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "ca-central-1", "eu-west-1", "eu-west-2", "eu-west-3",
      "eu-central-1", "eu-north-1", "ap-south-1", "ap-southeast-1",
      "ap-southeast-2", "ap-northeast-1", "ap-northeast-2", "ap-northeast-3",
      "ap-east-1", "me-south-1", "sa-east-1"
    ], var.aws_region)
    error_message = "aws_region must be a region supported by the Auth0 EventBridge sink."
  }
}
