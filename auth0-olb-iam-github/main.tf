##############################################################################
# Auth0 Online Banking IAM – Terraform Configuration
# 15 Use Cases: UC-01 to UC-15
# Environments: Dev | QA | Staging | Prod
# FAPI 2.0 compliant (Auth Code + PKCE, PAR, JAR, DPoP, Private Key JWT)
##############################################################################

terraform {
  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.0"
    }
    # Required by random_password.redirect_secret (actions.tf).
    # Previously relied on implicit installation – now pinned explicitly.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  required_version = ">= 1.5.0, < 2.0.0"

  ##############################################################################
  # Remote state – AWS S3 (one state file per environment).
  #
  # NOTE: Terraform does NOT allow variables, locals or expressions inside a
  # backend block. This is therefore a PARTIAL backend configuration — the
  # environment-specific values live in backend/<env>.hcl and are supplied at
  # init time:
  #
  #   terraform init -reconfigure -backend-config=backend/dev.hcl
  #
  # The GitHub Actions workflow does this automatically per environment.
  #
  # Credentials are NOT configured here. The pipeline assumes an IAM role via
  # GitHub OIDC (aws-actions/configure-aws-credentials), which exports
  # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN into the job
  # environment. The S3 backend picks those up automatically — no static keys
  # are ever stored in GitHub.
  ##############################################################################
  backend "s3" {}
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_mgmt_client_id
  client_secret = var.auth0_mgmt_client_secret
}
