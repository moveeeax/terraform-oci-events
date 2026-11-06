# terraform-oci-events

Terraform module that manages an [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
Events rule. A rule matches emitted events against a JSON condition and triggers actions
such as publishing to a Notifications topic, a Streaming stream or invoking a Function.

The module's main job beyond wiring the resource is to reject the configurations that OCI
happily accepts but that produce a rule which is created, reported healthy, and never
delivers anything. See [Rules that never fire](#rules-that-never-fire).

## Usage

```hcl
module "events_rule" {
  source = "github.com/moveeeax/terraform-oci-events?ref=v1.0.0"

  compartment_id = var.compartment_id
  display_name   = "prod-instance-events"

  condition = jsonencode({
    eventType = ["com.oraclecloud.computeapi.launchinstance.end"]
  })

  actions = [
    {
      action_type = "ONS"
      topic_id    = var.topic_id
    }
  ]

  # IAM policy that lets the Events service publish to the topic.
  create_service_policy = true

  freeform_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Rules that never fire

The OCI Events API stores a rule's condition as an opaque JSON string and never checks it
against the catalogue of event types the platform actually emits. Likewise, an action whose
target OCID is missing, empty, or belongs to a different action type is accepted and simply
delivers nowhere. In both cases `terraform apply` succeeds, the rule shows up as `ACTIVE`,
and nothing ever happens.

This module validates the cases it can detect before the API is called:

| Rejected input | Why |
|----------------|-----|
| `condition` that is not valid JSON | Stored verbatim; matches nothing. |
| `condition` that decodes to an array, string or number | Only a JSON object is a filter. |
| `eventType` that is not an array, or is `[]` | An empty list matches no events. |
| `eventType` entry not starting `com.oraclecloud.`, or containing whitespace | OCI only emits `com.oraclecloud.*` event types, so anything else can never match. Catches wrong prefixes and copy-paste whitespace. |
| `ONS` action with no `topic_id` (or `""`) — likewise `OSS`/`stream_id`, `FAAS`/`function_id` | The action has no reachable destination. |
| An action setting a target OCID that does not match its `action_type` | The provider only reads the field matching `action_type`; the others are silently dropped. |
| Every action having `is_enabled = false` | The rule matches events but delivers nothing. |
| `compartment_id` that is not a compartment or tenancy OCID | Typo protection. |

What the module *cannot* check is whether a well-formed event type actually exists — a typo
inside the service or operation segment (`com.oraclecloud.computapi.launchinstance.end`)
still produces a silent no-op rule. Cross-check names against
[Services that Produce Events](https://docs.oracle.com/iaas/Content/Events/Reference/eventsproducers.htm).

Two things that look wrong but are not, and are therefore accepted:

- `condition = jsonencode({})` is the documented match-all filter.
- `*` wildcards are supported inside event types and data filters.

Note also that a rule matches events from its own compartment **and all child
compartments**, so `compartment_id` should be the root of the subtree you want to watch.

## Service policy for delivery

The Events service delivers to topics, streams and functions as the service
principal `cloudEvents`, and IAM has to allow it. Without a policy the rule matches
events and every delivery is refused, with nothing in Terraform to show for it.

`create_service_policy = true` creates that policy (`oci_identity_policy`) with
statements only for the action types the rule uses:

| `action_type` | Statement | Permission it carries |
|---------------|-----------|-----------------------|
| `ONS`  | `Allow service cloudEvents to use ons-topics in <scope>` | `ONS_TOPIC_PUBLISH` |
| `OSS`  | `Allow service cloudEvents to use stream-push in <scope>` and `... to read streams in <scope>` | `STREAM_PRODUCE`, `STREAM_READ` |
| `FAAS` | `Allow service cloudEvents to use fn-invocation in <scope>` | `FN_INVOCATION` |

The permissions are the ones Oracle lists for Events delivery in
[Events policies](https://docs.oracle.com/en-us/iaas/Content/Events/Concepts/eventspolicy.htm)
(cross-tenancy section); the verbs and resource types are the narrowest that carry
them per the IAM references for
[Notifications](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/notificationpolicyreference.htm),
[Streaming](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/streamingpolicyreference.htm) and
[Functions](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/functionspolicyreference.htm).
`use ons-topics` also includes `ONS_TOPIC_SUBSCRIBE`; there is no narrower verb.
Many published examples grant `use functions-family` instead, which also covers
applications and function reads; this module does not.

`<scope>` is `compartment id <service_policy_compartment_id>`, which defaults to
`compartment_id`. Set `service_policy_compartment_id` to the compartment holding
the targets when they live elsewhere; the policy is created there and covers its
child compartments. A tenancy OCID yields `in tenancy`. Creating the policy needs
permission to manage policies in that compartment, and the policy name
(`service_policy_name`, default `<display_name>-events-delivery`) must be unique in
the tenancy.

The policy is off by default, so existing configurations that grant the access
elsewhere are unaffected.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| oci       | >= 5.0   |

Running the test suite additionally requires Terraform or OpenTofu >= 1.7 for
`mock_provider`. The module itself still works on 1.5.

## Inputs

| Name             | Description                                                       | Type                | Default | Required |
|------------------|-------------------------------------------------------------------|---------------------|---------|:--------:|
| `compartment_id` | OCID of the compartment in which to create the rule. Must be an `ocid1.compartment.*` or `ocid1.tenancy.*` OCID. | `string`            | n/a     |   yes    |
| `display_name`   | Human-readable name for the rule. Non-blank, at most 255 characters. | `string`            | n/a     |   yes    |
| `description`    | Description of the rule.                                          | `string`            | `null`  |    no    |
| `is_enabled`     | Whether the rule is enabled.                                      | `bool`              | `true`  |    no    |
| `condition`      | JSON condition matched against incoming events. Build it with `jsonencode`. | `string`            | n/a     |   yes    |
| `actions`        | List of actions (ONS/OSS/FAAS) to trigger on match. Each must set exactly the target OCID matching its `action_type`. | `list(object(...))` | n/a     |   yes    |
| `freeform_tags`  | Free-form tags applied to the rule.                              | `map(string)`       | `{}`    |    no    |
| `defined_tags`   | Defined tags applied to the rule, keyed `namespace.key`.          | `map(string)`       | `{}`    |    no    |
| `create_service_policy` | Create the IAM policy that lets the Events service deliver to the action targets. | `bool` | `false` | no |
| `service_policy_compartment_id` | Compartment (or tenancy) OCID holding the targets; the policy is created and scoped there. Null uses `compartment_id`. | `string` | `null` | no |
| `service_policy_name` | Policy name, unique in the tenancy. Null uses `<display_name>-events-delivery`. | `string` | `null` | no |

### `actions` object

| Field         | Type     | Default | Notes |
|---------------|----------|---------|-------|
| `action_type` | `string` | n/a     | One of `ONS`, `OSS`, `FAAS`. |
| `is_enabled`  | `bool`   | `true`  | At least one action must be enabled. |
| `description` | `string` | `null`  | |
| `topic_id`    | `string` | `null`  | Required when `action_type = "ONS"`. |
| `stream_id`   | `string` | `null`  | Required when `action_type = "OSS"`. |
| `function_id` | `string` | `null`  | Required when `action_type = "FAAS"`. |

## Outputs

| Name           | Description                     |
|----------------|---------------------------------|
| `id`           | OCID of the events rule.        |
| `display_name` | Display name of the rule.       |
| `is_enabled`   | Whether the rule is enabled.    |
| `state`        | Lifecycle state of the rule.    |
| `service_policy_id` | OCID of the delivery policy; null when `create_service_policy` is false. |
| `service_policy_statements` | Statements of the delivery policy; empty when it is not created. |

## Testing

The suite in [`tests/`](tests) uses `mock_provider`, so it needs no OCI credentials and no
network access:

```console
$ terraform init -backend=false
$ terraform test
```

## License

[MIT](LICENSE)
