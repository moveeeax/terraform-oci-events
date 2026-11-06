provider "oci" {}

module "events_rule" {
  source = "../.."

  compartment_id = var.compartment_id
  display_name   = "example-instance-events"
  description    = "Notify on instance lifecycle changes"

  condition = jsonencode({
    eventType = ["com.oraclecloud.computeapi.launchinstance.end"]
  })

  actions = [
    {
      action_type = "ONS"
      topic_id    = var.topic_id
      description = "Publish to notifications topic"
    }
  ]

  # Let the Events service publish to the topic; without an IAM policy for the
  # cloudEvents service principal the rule fires and delivers nothing.
  create_service_policy = true

  freeform_tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

variable "compartment_id" {
  description = "Compartment OCID to deploy the example rule into."
  type        = string
}

variable "topic_id" {
  description = "OCID of the ONS topic the rule publishes to."
  type        = string
}

output "events_rule_id" {
  value = module.events_rule.id
}
