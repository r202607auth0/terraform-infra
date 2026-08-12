# Auth0 Online Banking IAM – Terraform Configuration

## Use Case Coverage

| UC | Name | Key Auth0 Components |
|----|------|----------------------|
| UC-01 | User Registration | Pre-User Reg Action (CIF validation), email OTP activation, mandatory MFA enrollment, bilingual prompts, WCAG 2.1AA |
| UC-02 | New User Login | Post-Login Action (geo/IP block, risk-based MFA, email verification enforcement), FAPI 2.0 (PAR, JAR, DPoP) |
| UC-03 | Legacy User Login | Post-Login Action (email-on-file check → collect email → validate → update profile → MFA enroll), separate legacy connection |
| UC-04 | Step-Up Authentication | Post-Login Action (high-risk scope detection → always-challenge Option 1 or conditional Option 2), 6 Fraud Team actions |
| UC-05 | MFA Factor Matrix | Auth0 Guardian (Email OTP + TOTP Phase 1; Push/Passkeys later phase; SMS excluded), enrollment hierarchy enforcement |
| UC-06 | Account Lockout | OOTB brute-force protection (3 attempts), MFA-failure lockout, email notification Post-Login Action |
| UC-07 | Self-Service Password Recovery | Universal Login change-password flow, 15-min link TTL, complexity rules, no password reuse, no PII reveal |
| UC-08 | User Profile Management | Step-up enforcement before sensitive field updates (integrates UC-04), audit log Post-Login Action |
| UC-09 | Session / Device Activity | Auth0 Log Streams → SIEM, login history via Management API, session revocation |
| UC-10 | Delegated Admin Management | RBAC roles (delegate-readonly, delegate-initiator, signing-officer), delegate app_metadata, Post-Login token enrichment |
| UC-11 | User Notifications | Post-Login Action (new device, unusual location, step-up attempt, profile change → SendGrid email) |
| UC-12 | Support-Initiated Password Reset | Support Portal client, Management API grant (update:users), scoped support:reset_password scope |
| UC-13 | Support-Assisted Transaction | Scoped agent token (support:assist_transaction), step-up for customer identity verify |
| UC-14 | Support-Initiated Lockout | Management API PATCH /users/{id} {blocked: true}, audit log |
| UC-15 | Support-Initiated Unblock | Management API PATCH /users/{id} {blocked: false}, audit log |

## File Structure

```
auth0-olb-iam/
├── main.tf                 # Provider + backend config
├── variables.tf            # All input variables
├── tenant.tf               # Auth0 tenant settings (session, UL, locales)
├── connection.tf           # Database connections + password policy (UC-01, UC-06, UC-07)
├── applications.tf         # OLB Portal (FAPI 2.0) + Support Portal + M2M client
├── resource_server.tf      # API scopes incl. all step-up and delegate scopes
├── rbac.tf                 # Roles: banking-customer, delegate-readonly, delegate-initiator, signing-officer, support-agent
├── mfa.tf                  # Guardian MFA policy (Email OTP, TOTP, Push, Passkeys)
├── attack_protection.tf    # Brute-force + suspicious IP + breached password detection
├── email_templates.tf      # Lockout, SSPR, welcome, verify, change-password templates
├── actions.tf              # All 6 Auth0 Actions + trigger bindings
├── log_streams.tf          # Log stream → SIEM (UC-09, UC-10, UC-11)
├── prompts.tf              # Custom signup/login/MFA/SSPR prompts – EN + FR-CA
├── outputs.tf              # Exported IDs and identifiers
├── terraform.<env>.tfvars  # Non-secret values per env (dev/qa/staging/prod)
├── backend/
│   └── <env>.hcl           # Partial backend config per env (s3 remote state)
├── .github/
│   ├── actions/
│   │   └── terraform-setup/action.yml  # Composite: install TF + AWS OIDC (state backend)
│   └── workflows/
│       ├── terraform.yml               # Orchestrator: validate → dev → qa → staging → prod
│       └── terraform-env.yml           # Reusable per-env workflow: Plan + approval-gated Apply
└── .gitignore
```

## Prerequisites

1. **AWS OIDC trust** (once per environment account). Register GitHub as an OIDC
   identity provider and create the role the pipeline assumes:

   | Setting | Value |
   |---|---|
   | Provider URL | `https://token.actions.githubusercontent.com` |
   | Audience | `sts.amazonaws.com` |
   | Role name | `github-actions-terraform` (override via `AWS_OIDC_ROLE_NAME`) |

   Restrict the role's trust policy `sub` claim to this repository — a wildcard
   such as `repo:<ORG>/*:*` would let any repo in the org assume it:

   | Job | Subject claim |
   |---|---|
   | `plan` (push) | `repo:<ORG>/<REPO>:ref:refs/heads/main` |
   | `plan` (PR) | `repo:<ORG>/<REPO>:pull_request` |
   | `apply` (dev) | `repo:<ORG>/<REPO>:environment:dev` |
   | `apply` (qa) | `repo:<ORG>/<REPO>:environment:qa` |
   | `apply` (staging) | `repo:<ORG>/<REPO>:environment:staging` |
   | `apply` (prod) | `repo:<ORG>/<REPO>:environment:prod` |

   The role's permission policy needs only S3 state access and DynamoDB lock
   access — see the exact actions in `backend/<env>.hcl`.

2. **Repository variables** (Settings → Secrets and variables → Actions → *Variables*).
   These are non-sensitive and stay visible in logs, which makes failures easy to
   diagnose. Create four of each (one per environment), plus two shared:

   | Variable | Maps to |
   |---|---|
   | `AUTH0_DOMAIN_<ENV>` | `TF_VAR_auth0_domain` |
   | `AUTH0_CLIENT_ID_<ENV>` | `TF_VAR_auth0_mgmt_client_id` |
   | `AWS_ACCOUNT_ID_<ENV>` | `TF_VAR_aws_account_id` + the OIDC role ARN |
   | `AWS_REGION` (shared, optional) | `TF_VAR_aws_region` — defaults to `us-east-1` |
   | `AWS_OIDC_ROLE_NAME` (shared, optional) | defaults to `github-actions-terraform` |

3. **Repository secrets** (Settings → Secrets and variables → Actions → *Secrets*).
   Stored **per environment** using a name **suffix** (`_DEV`, `_QA`, `_STAGING`,
   `_PROD`). The orchestrator maps them onto the reusable workflow's generic names,
   and they are injected into Terraform as `TF_VAR_*` and masked in logs:

   | Secret name (per env) | Maps to Terraform variable |
   |---|---|
   | `AUTH0_CLIENT_SECRET_<ENV>` | `auth0_mgmt_client_secret` |
   | `SENDGRID_API_KEY_<ENV>` | `sendgrid_api_key` |
   | `CIF_VALIDATION_API_SECRET_<ENV>` | `cif_validation_api_secret` |

   Twelve secrets in total across the four environments. **No AWS credentials are
   stored in GitHub** — the pipeline mints short-lived STS credentials per run via
   OIDC.

   > **Why repository (suffixed) secrets, not Environment secrets?** The `plan` job runs
   > *before* the approval gate so reviewers can see the plan. GitHub Environment secrets
   > are only readable by a job that declares `environment:`, which would also make the
   > plan wait for approval. Repository secrets with an env suffix keep the
   > plan-before-approve flow intact.

   > **Preflight check:** the `plan` job verifies every required variable and secret is
   > non-empty before touching Terraform. GitHub silently substitutes an empty string for
   > a missing secret, which would otherwise surface much later as an opaque Auth0 401.

4. **Environments** (Settings → Environments): create `dev`, `qa`, `staging`, `prod`.
   Add **Required reviewers** to each — at minimum a two-person review on `prod`.
   Approvals are configured here, not in YAML. Optionally restrict each environment to
   the `main` branch under *Deployment branches*.

5. **Commit `.terraform.lock.hcl`** so the plan and apply jobs resolve identical
   provider versions.

> **Security note:** a saved plan file contains sensitive variable values in
> cleartext. The plan artifact retention is set to 1 day; keep it short and restrict who
> can download run artifacts in your org/repo settings.

### Remote state

State lives in **AWS S3** — one bucket per environment account, one key per
environment. The backend is a **partial configuration** (`backend "s3" {}` in
`main.tf`); Terraform forbids variables inside a backend block, so the
per-environment values are supplied at init time via
`-backend-config=backend/<env>.hcl`.

Each state bucket must be created out-of-band (a state bucket cannot bootstrap
its own state) with **versioning on**, **default encryption on**, **public access
blocked**, and a bucket policy denying non-TLS requests. Locking uses a DynamoDB
table with a `LockID` string partition key.

> **Terraform ≥ 1.10:** native S3 locking (`use_lockfile = true`) removes the
> DynamoDB dependency entirely; `dynamodb_table` is deprecated from 1.11 onward.
> The workflow pins 1.9.8, so DynamoDB is required today. See the note at the
> bottom of each `backend/<env>.hcl` for the swap.


## MFA Phase Plan (UC-05)

| Phase | Factors Available |
|-------|-------------------|
| Phase 1 (now) | Email OTP (Low / AAL2) + TOTP (Medium / AAL2) |
| Later phase | Push / Guardian SDK (High / AAL2+) + Passkeys (Very High / AAL3) |
| Excluded | SMS OTP (deprecated per requirements) |

## FAPI 2.0 Compliance (OLB Portal)

The Online Banking Portal client is configured as a server-side web application using:
- **Authorization Code + PKCE** (`auth0_client.olb_portal`)
- **Private Key JWT** for client authentication (`token_endpoint_auth_method = "private_key_jwt"`)
- **PAR** – Pushed Authorization Requests (enforced at application layer)
- **JAR** – JWT Secured Authorization Request (enforced at application layer)
- **DPoP** – Demonstrate Possession of Proof (enforced at application layer)

## Geographic Restrictions (UC-02)

Blocked countries configured in `var.blocked_countries`:
DPRK (KP), Iran (IR), Syria (SY), Russia (RU), Myanmar (MM)

Crimea and other occupied Ukraine regions (Donetsk, Luhansk, Kherson, Zaporizhzhia) 
are handled via the IP blocklist (Jira PM-57775) once finalized.
The `BANNED_IPS_JSON` secret in the post-login Action is updated once that list is complete.
