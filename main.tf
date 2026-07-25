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
}
