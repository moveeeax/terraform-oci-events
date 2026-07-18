# terraform-oci-events

Terraform module that manages an [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
Events rule. A rule matches emitted events against a JSON condition and triggers actions
such as publishing to a Notifications topic, a Streaming stream or invoking a Function.

## Usage

```hcl
module "events_rule" {
  source = "github.com/cybercapybara/terraform-oci-events"

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

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| oci       | >= 5.0   |

## Inputs

| Name             | Description                                                       | Type                | Default | Required |
|------------------|-------------------------------------------------------------------|---------------------|---------|:--------:|
| `compartment_id` | OCID of the compartment in which to create the rule.              | `string`            | n/a     |   yes    |
| `display_name`   | Human-readable name for the rule.                                 | `string`            | n/a     |   yes    |
| `description`    | Description of the rule.                                          | `string`            | `null`  |    no    |
| `is_enabled`     | Whether the rule is enabled.                                      | `bool`              | `true`  |    no    |
| `condition`      | JSON condition matched against incoming events.                   | `string`            | n/a     |   yes    |
| `actions`        | List of actions (ONS/OSS/FAAS) to trigger on match.              | `list(object(...))` | n/a     |   yes    |
| `freeform_tags`  | Free-form tags applied to the rule.                              | `map(string)`       | `{}`    |    no    |
| `defined_tags`   | Defined tags applied to the rule, keyed `namespace.key`.          | `map(string)`       | `{}`    |    no    |

## Outputs

| Name           | Description                     |
|----------------|---------------------------------|
| `id`           | OCID of the events rule.        |
| `display_name` | Display name of the rule.       |
| `is_enabled`   | Whether the rule is enabled.    |
| `state`        | Lifecycle state of the rule.    |

## License

[MIT](LICENSE)
