##############################################################################
# log_streams.tf – Log Streams & Audit
# UC-09: Session / Device Activity (display login history)
# UC-10: Delegated Admin – audit trail
# UC-11: Login monitoring / security alerting
##############################################################################

# ── Auth0 Log Stream → AWS EventBridge → SIEM / Data Lake ──────────────────
#
# Auth0 publishes to a *partner event source* in the target AWS account. The
# generated source name is an OUTPUT of this resource (sink.0.aws_partner_event_source);
# it must not be set as an input. Associate it with an event bus on the AWS
# side (aws_cloudwatch_event_bus) in the account's own Terraform stack.
#
# IMMUTABILITY: aws_account_id and aws_region cannot be changed in place.
# Editing either forces replacement of the log stream, which means a brief gap
# in log delivery and a new partner event source to re-associate in AWS.
resource "auth0_log_stream" "siem" {
  name   = "olb-siem-log-stream-${var.environment}"
  type   = "eventbridge" # AWS EventBridge; swap for "http" if using Splunk/Datadog
  status = "active"

  filters {
    type = "category"
    name = "auth.login.success"
  }
  filters {
    type = "category"
    name = "auth.login.fail"
  }
  filters {
    type = "category"
    name = "auth.logout.success"
  }
  filters {
    type = "category"
    name = "user.fail_by_credentials_exists"
  }
  filters {
    type = "category"
    name = "auth.mfa"
  }
  filters {
    type = "category"
    name = "management.success" # Support agent actions (UC-12–15)
  }
  filters {
    type = "category"
    name = "user.update" # Profile changes (UC-08)
  }

  sink {
    aws_account_id = var.aws_account_id
    aws_region     = var.aws_region
  }
}
