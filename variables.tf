variable "compartment_id" {
  description = "OCID of the compartment in which to create the events rule. The rule matches events emitted in this compartment and all of its children."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.(compartment|tenancy)\\.", var.compartment_id))
    error_message = "compartment_id must be a compartment or tenancy OCID (starting with \"ocid1.compartment.\" or \"ocid1.tenancy.\")."
  }
}

variable "display_name" {
  description = "Human-readable name for the rule."
  type        = string

  validation {
    condition     = length(trimspace(var.display_name)) > 0 && length(var.display_name) <= 255
    error_message = "display_name must be a non-blank string of at most 255 characters."
  }
}

variable "description" {
  description = "Description of the rule."
  type        = string
  default     = null
}

variable "is_enabled" {
  description = "Whether the rule is enabled. A disabled rule is created but never evaluates events."
  type        = bool
  default     = true
}

variable "condition" {
  description = <<-EOT
    JSON condition matched against incoming events (eventType, source and data filters).
    Build it with `jsonencode` rather than hand-writing an escaped string. OCI stores the
    condition verbatim and does not verify that the event types in it actually exist, so a
    typo produces a rule that is enabled and never fires. `jsonencode({})` matches every
    event in the compartment subtree.
  EOT
  type        = string

  validation {
    condition     = can(jsondecode(var.condition))
    error_message = "condition must be valid JSON. Build it with jsonencode({ eventType = [...] }) instead of a hand-escaped string."
  }

  validation {
    condition     = can(keys(jsondecode(var.condition)))
    error_message = "condition must decode to a JSON object such as {\"eventType\": [...]}, not an array, string or number. OCI accepts other shapes but they match no events."
  }

  # An `eventType` key must be a non-empty array. `eventType: []` is accepted by OCI and
  # silently matches nothing, which is the classic "rule exists, is enabled, never fires".
  validation {
    condition = (
      !can(jsondecode(var.condition).eventType) ||
      (can(tolist(jsondecode(var.condition).eventType)) && length(try(tolist(jsondecode(var.condition).eventType), [])) > 0)
    )
    error_message = "condition.eventType must be a non-empty JSON array of event type strings. An empty array matches no events, so the rule would never fire."
  }

  # OCI Events only ever delivers events emitted by OCI services, which are all named
  # com.oraclecloud.<service>.<operation>[.<phase>]. Anything else can never match.
  validation {
    condition = alltrue([
      for e in try(tolist(jsondecode(var.condition).eventType), []) :
      can(regex("^com\\.oraclecloud\\.[^\\s]+$", e))
    ])
    error_message = "Every condition.eventType entry must look like \"com.oraclecloud.<service>.<operation>\" with no whitespace (the asterisk wildcard is allowed). OCI never emits event types with any other prefix, so such an entry would never match."
  }
}

variable "actions" {
  description = <<-EOT
    Actions to trigger when the rule matches. Each action must set exactly the target OCID
    that matches its action_type: ONS -> topic_id, OSS -> stream_id, FAAS -> function_id.
  EOT
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

  # Without this, an action carrying no target OCID (or an empty string, which the OCI
  # provider treats as unset) produces a rule that matches events and delivers nowhere.
  validation {
    condition = alltrue([
      for a in var.actions : (
        a.action_type == "ONS" ? try(length(trimspace(a.topic_id)), 0) > 0 :
        a.action_type == "OSS" ? try(length(trimspace(a.stream_id)), 0) > 0 :
        a.action_type == "FAAS" ? try(length(trimspace(a.function_id)), 0) > 0 :
        true
      )
    ])
    error_message = "Each action must set a non-empty target OCID for its action_type: ONS requires topic_id, OSS requires stream_id, FAAS requires function_id."
  }

  # A target OCID that does not belong to the action_type is ignored by the Events service,
  # so e.g. an ONS action carrying only function_id would deliver nothing.
  validation {
    condition = alltrue([
      for a in var.actions : length(compact([
        try(trimspace(a.topic_id), ""),
        try(trimspace(a.stream_id), ""),
        try(trimspace(a.function_id), ""),
      ])) <= 1
    ])
    error_message = "Each action must set exactly one target OCID. Setting a target that does not match action_type (for example function_id on an ONS action) is silently ignored by OCI."
  }

  validation {
    condition     = anytrue([for a in var.actions : a.is_enabled])
    error_message = "At least one action must have is_enabled = true; a rule whose actions are all disabled matches events but delivers nothing."
  }
}

variable "create_service_policy" {
  description = "Create an IAM policy that lets the Events service (service principal cloudEvents) deliver to the targets of the rule's action types. Without such a policy, created here or elsewhere, the rule matches events and every delivery is refused. Default false: no policy is created."
  type        = bool
  default     = false
}

variable "service_policy_compartment_id" {
  description = "OCID of the compartment that holds the action targets (topics, streams, functions). The policy is created in this compartment and grants access in it and its children; a tenancy OCID grants access in the whole tenancy. Null uses compartment_id. Ignored unless create_service_policy is true."
  type        = string
  default     = null

  validation {
    condition     = var.service_policy_compartment_id == null || can(regex("^ocid1\\.(compartment|tenancy)\\.", var.service_policy_compartment_id))
    error_message = "service_policy_compartment_id must be a compartment or tenancy OCID (starting with \"ocid1.compartment.\" or \"ocid1.tenancy.\") or null."
  }
}

variable "service_policy_name" {
  description = "Name of the service policy. IAM policy names are unique per tenancy. Null uses \"<display_name>-events-delivery\", with characters other than letters, digits, _, . and - replaced by -. Ignored unless create_service_policy is true."
  type        = string
  default     = null

  validation {
    condition     = var.service_policy_name == null || try(length(trimspace(var.service_policy_name)) > 0, false)
    error_message = "service_policy_name must not be blank; leave it null to use the default name."
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
