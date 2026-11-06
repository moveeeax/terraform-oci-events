# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `create_service_policy` input (default `false`): creates an IAM policy that
  lets the Events service (`cloudEvents`) deliver to the rule's targets, with
  statements only for the action types in use (`use ons-topics`, `use
  stream-push` plus `read streams`, `use fn-invocation`). Scoped by the new
  `service_policy_compartment_id` (default `compartment_id`; a tenancy OCID gives
  `in tenancy`) and named by `service_policy_name`. New outputs
  `service_policy_id` and `service_policy_statements`. Existing inputs and
  outputs are unchanged.

[Unreleased]: https://github.com/moveeeax/terraform-oci-events/compare/v1.1.0...HEAD
