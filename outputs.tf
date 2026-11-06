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

output "service_policy_id" {
  description = "OCID of the Events service delivery policy; null when create_service_policy is false."
  value       = one(oci_identity_policy.service[*].id)
}

output "service_policy_statements" {
  description = "Statements of the Events service delivery policy; empty when create_service_policy is false."
  value       = one(oci_identity_policy.service[*].statements) == null ? [] : one(oci_identity_policy.service[*].statements)
}
