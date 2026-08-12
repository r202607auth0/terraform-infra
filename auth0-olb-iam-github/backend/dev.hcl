##############################################################################
# backend/dev.hcl – Partial S3 backend config for the dev environment
# Used as: terraform init -reconfigure -backend-config=backend/dev.hcl
#
# The state bucket lives in the dev AWS account (GitHub variable
# AWS_ACCOUNT_ID_DEV). The pipeline reaches it by assuming an IAM role in that
# account via GitHub OIDC — no access keys are stored anywhere.
#
# Bucket prerequisites (create once, out-of-band — a state bucket cannot
# bootstrap its own state):
#   - Versioning ENABLED (state rollback / recovery)
#   - Default encryption ENABLED (SSE-S3, or SSE-KMS – see kms_key_id below)
#   - Public access BLOCKED (all four settings)
#   - Bucket policy denying non-TLS requests (aws:SecureTransport = false)
#
# The pipeline IAM role needs, at minimum:
#   s3:ListBucket                           on arn:aws:s3:::<bucket>
#   s3:GetObject / PutObject / DeleteObject on arn:aws:s3:::<bucket>/auth0/dev/*
#   dynamodb:GetItem / PutItem / DeleteItem / DescribeTable on the lock table
##############################################################################

bucket = "olb-iam-tfstate-dev"
key    = "auth0/dev/terraform.tfstate"
region = "us-east-1"

# Server-side encryption of the state object at rest. The state file holds the
# Auth0 client secret, SendGrid key and CIF shared secret in cleartext, so this
# is mandatory, not optional.
encrypt = true

# Optional: customer-managed KMS key instead of SSE-S3. The pipeline role then
# also needs kms:Encrypt / kms:Decrypt / kms:GenerateDataKey on the key.
# kms_key_id = "arn:aws:kms:us-east-1:<account-id>:key/<key-id>"

# State locking via DynamoDB (table must have a partition key named "LockID",
# type String). This replaces the blob-lease locking the previous backend gave
# you for free — without it, two concurrent runs can corrupt state.
dynamodb_table = "olb-iam-tfstate-locks"

# ── Terraform >= 1.10 alternative ────────────────────────────────────────────
# Terraform 1.10 added native S3 locking, removing the DynamoDB table entirely
# (dynamodb_table is deprecated from 1.11 onward). The workflow pins 1.9.8, so
# DynamoDB is still required today. When you bump TF_VERSION to >= 1.10, delete
# the dynamodb_table line above and use instead:
#
#   use_lockfile = true
