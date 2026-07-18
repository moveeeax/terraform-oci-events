resource "oci_events_rule" "this" {
  compartment_id = var.compartment_id
  display_name   = var.display_name
  description    = var.description
  is_enabled     = var.is_enabled
  condition      = var.condition

  actions {
    dynamic "actions" {
      for_each = var.actions
      content {
        action_type = actions.value.action_type
        is_enabled  = actions.value.is_enabled
        description = actions.value.description
        topic_id    = actions.value.topic_id
        stream_id   = actions.value.stream_id
        function_id = actions.value.function_id
      }
    }
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
