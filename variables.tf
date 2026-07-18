variable "compartment_id" {
  description = "OCID of the compartment in which to create the events rule."
  type        = string
}

variable "display_name" {
  description = "Human-readable name for the rule."
  type        = string
}

variable "description" {
  description = "Description of the rule."
  type        = string
  default     = null
}

variable "is_enabled" {
  description = "Whether the rule is enabled."
  type        = bool
  default     = true
}

variable "condition" {
  description = "JSON condition matched against incoming events (eventType, source, and data filters)."
  type        = string
}

variable "actions" {
  description = "List of actions to trigger when the rule matches."
  type = list(object({
    action_type = string
    is_enabled  = optional(bool, true)
    description = optional(string)
    topic_id    = optional(string)
    stream_id   = optional(string)
    function_id = optional(string)
  }))

  validation {
    condition     = length(var.actions) > 0
    error_message = "At least one action must be provided."
  }

  validation {
    condition = alltrue([
      for a in var.actions : contains(["ONS", "OSS", "FAAS"], a.action_type)
    ])
    error_message = "action_type must be ONS, OSS, or FAAS."
  }
}

variable "freeform_tags" {
  description = "Free-form tags applied to the rule."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags applied to the rule, keyed as \"namespace.key\"."
  type        = map(string)
  default     = {}
}
