resource "oci_events_rule" "this" {
  compartment_id = var.compartment_id
  display_name   = var.display_name
  description    = var.description
  is_enabled     = var.is_enabled
  condition      = var.condition

  actions {
    # The provider also accepts a nested block literally named "actions", but it is
    # deprecated in favour of "action" and emits a warning on every plan.
    dynamic "action" {
      for_each = var.actions
      content {
        action_type = action.value.action_type
        is_enabled  = action.value.is_enabled
        description = action.value.description
        topic_id    = action.value.topic_id
        stream_id   = action.value.stream_id
        function_id = action.value.function_id
      }
    }
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  # Let the delivery policy exist before the rule can start matching events.
  depends_on = [oci_identity_policy.service]
}

# The Events service delivers to topics, streams and functions as the service
# principal "cloudEvents", which needs IAM permission on the targets; without it
# the rule matches and every delivery is refused. Statements are generated only
# for the action types the rule uses, and each grants the narrowest verb on the
# narrowest resource type that carries the permission delivery needs:
#   ONS  -> ONS_TOPIC_PUBLISH   (use ons-topics)
#   OSS  -> STREAM_PRODUCE      (use stream-push) and STREAM_READ (read streams)
#   FAAS -> FN_INVOCATION       (use fn-invocation)
# These are the permissions Oracle lists for cross-tenancy Events delivery.
locals {
  service_policy_compartment_id = coalesce(var.service_policy_compartment_id, var.compartment_id)

  service_policy_scope = (
    can(regex("^ocid1\\.tenancy\\.", local.service_policy_compartment_id))
    ? "tenancy"
    : "compartment id ${local.service_policy_compartment_id}"
  )

  service_policy_grants = {
    ONS  = ["use ons-topics"]
    OSS  = ["use stream-push", "read streams"]
    FAAS = ["use fn-invocation"]
  }

  service_policy_action_types = sort(distinct([for a in var.actions : a.action_type]))

  service_policy_statements = flatten([
    for t in local.service_policy_action_types : [
      for g in local.service_policy_grants[t] : "Allow service cloudEvents to ${g} in ${local.service_policy_scope}"
    ]
  ])
}

resource "oci_identity_policy" "service" {
  count = var.create_service_policy ? 1 : 0

  compartment_id = local.service_policy_compartment_id
  name           = coalesce(var.service_policy_name, "${replace(var.display_name, "/[^A-Za-z0-9_.-]/", "-")}-events-delivery")
  description    = "Lets the Events service deliver events rule ${var.display_name} to its ${join(", ", local.service_policy_action_types)} targets."
  statements     = local.service_policy_statements

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
