output "id" {
  description = "OCID of the events rule."
  value       = oci_events_rule.this.id
}

output "display_name" {
  description = "Display name of the rule."
  value       = oci_events_rule.this.display_name
}

output "is_enabled" {
  description = "Whether the rule is enabled."
  value       = oci_events_rule.this.is_enabled
}

output "state" {
  description = "Lifecycle state of the rule."
  value       = oci_events_rule.this.state
}
