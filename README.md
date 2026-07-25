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
  source = "github.com/moveeeax/terraform-oci-events"

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

## Testing

The suite in [`tests/`](tests) uses `mock_provider`, so it needs no OCI credentials and no
network access:

```console
$ terraform init -backend=false
$ terraform test
```

## License

[MIT](LICENSE)
