# Test-only requirement: `mock_provider` needs Terraform >= 1.7 (or OpenTofu >= 1.7).
# The module itself still supports >= 1.5 -- do not bump required_version for this file.
mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaaexamplecompartment"
  display_name   = "test-instance-events"
  condition      = "{\"eventType\":[\"com.oraclecloud.computeapi.launchinstance.end\"]}"
  actions = [
    {
      action_type = "ONS"
      topic_id    = "ocid1.onstopic.oc1..aaaaaaaaexampletopic"
    }
  ]
}

run "defaults_produce_a_live_rule" {
  assert {
    condition     = oci_events_rule.this.is_enabled == true
    error_message = "The rule must be enabled by default; a disabled rule never evaluates events."
  }

  assert {
    condition     = oci_events_rule.this.compartment_id == var.compartment_id
    error_message = "compartment_id must be passed straight through to the rule."
  }

  assert {
    condition     = oci_events_rule.this.condition == var.condition
    error_message = "condition must be passed through verbatim."
  }

  assert {
    condition     = length(tolist(one(oci_events_rule.this.actions).action)) == 1
    error_message = "Exactly one action should be rendered from a single-element actions list."
  }

  assert {
    condition     = tolist(one(oci_events_rule.this.actions).action)[0].is_enabled == true
    error_message = "Actions must default to enabled; a rule whose only action is disabled delivers nothing."
  }

  assert {
    condition     = tolist(one(oci_events_rule.this.actions).action)[0].topic_id == var.actions[0].topic_id
    error_message = "The ONS action must carry the topic OCID it was given."
  }
}

run "renders_stream_and_function_targets" {
  variables {
    actions = [
      {
        action_type = "OSS"
        stream_id   = "ocid1.stream.oc1..aaaaaaaaexamplestream"
      },
      {
        action_type = "FAAS"
        function_id = "ocid1.fnfunc.oc1..aaaaaaaaexamplefunction"
      },
    ]
  }

  assert {
    condition     = length(tolist(one(oci_events_rule.this.actions).action)) == 2
    error_message = "Both OSS and FAAS actions should be rendered."
  }
}

# --- the rule must actually be able to fire -------------------------------

run "rejects_action_without_a_target_ocid" {
  command = plan

  variables {
    actions = [{ action_type = "ONS" }]
  }

  expect_failures = [var.actions]
}

run "rejects_action_with_an_empty_target_ocid" {
  command = plan

  variables {
    actions = [{ action_type = "ONS", topic_id = "" }]
  }

  expect_failures = [var.actions]
}

run "rejects_target_ocid_that_does_not_match_action_type" {
  command = plan

  variables {
    actions = [{
      action_type = "ONS"
      function_id = "ocid1.fnfunc.oc1..aaaaaaaaexamplefunction"
    }]
  }

  expect_failures = [var.actions]
}

run "rejects_extra_target_ocid_alongside_the_right_one" {
  command = plan

  variables {
    actions = [{
      action_type = "ONS"
      topic_id    = "ocid1.onstopic.oc1..aaaaaaaaexampletopic"
      stream_id   = "ocid1.stream.oc1..aaaaaaaaexamplestream"
    }]
  }

  expect_failures = [var.actions]
}

run "rejects_all_actions_disabled" {
  command = plan

  variables {
    actions = [{
      action_type = "ONS"
      topic_id    = "ocid1.onstopic.oc1..aaaaaaaaexampletopic"
      is_enabled  = false
    }]
  }

  expect_failures = [var.actions]
}

run "rejects_empty_actions_list" {
  command = plan

  variables {
    actions = []
  }

  expect_failures = [var.actions]
}

run "rejects_unknown_action_type" {
  command = plan

  variables {
    actions = [{
      action_type = "EMAIL"
      topic_id    = "ocid1.onstopic.oc1..aaaaaaaaexampletopic"
    }]
  }

  expect_failures = [var.actions]
}

# --- the condition must be able to match ----------------------------------

run "rejects_malformed_condition_json" {
  command = plan

  variables {
    condition = "{eventType: [com.oraclecloud.computeapi.launchinstance.end]}"
  }

  expect_failures = [var.condition]
}

run "rejects_condition_that_is_not_a_json_object" {
  command = plan

  variables {
    condition = "[\"com.oraclecloud.computeapi.launchinstance.end\"]"
  }

  expect_failures = [var.condition]
}

run "rejects_empty_event_type_list" {
  command = plan

  variables {
    condition = "{\"eventType\":[]}"
  }

  expect_failures = [var.condition]
}

run "rejects_event_type_that_is_not_a_list" {
  command = plan

  variables {
    condition = "{\"eventType\":\"com.oraclecloud.computeapi.launchinstance.end\"}"
  }

  expect_failures = [var.condition]
}

run "rejects_misspelled_event_type_prefix" {
  command = plan

  variables {
    condition = "{\"eventType\":[\"com.oracle.cloud.computeapi.launchinstance.end\"]}"
  }

  expect_failures = [var.condition]
}

run "rejects_event_type_with_stray_whitespace" {
  command = plan

  variables {
    condition = "{\"eventType\":[\" com.oraclecloud.computeapi.launchinstance.end\"]}"
  }

  expect_failures = [var.condition]
}

run "accepts_wildcard_and_data_filters" {
  command = plan

  variables {
    condition = "{\"eventType\":[\"com.oraclecloud.objectstorage.*\"],\"data\":{\"compartmentName\":[\"prod\"]}}"
  }

  assert {
    condition     = oci_events_rule.this.condition == var.condition
    error_message = "Wildcard event types and data filters are valid OCI conditions and must be accepted."
  }
}

run "accepts_match_all_condition" {
  command = plan

  variables {
    condition = "{}"
  }

  assert {
    condition     = oci_events_rule.this.condition == "{}"
    error_message = "An empty object is a documented match-all condition and must be accepted."
  }
}

# --- identity inputs ------------------------------------------------------

run "rejects_non_ocid_compartment" {
  command = plan

  variables {
    compartment_id = "my-compartment"
  }

  expect_failures = [var.compartment_id]
}

run "rejects_blank_display_name" {
  command = plan

  variables {
    display_name = "   "
  }

  expect_failures = [var.display_name]
}

# --- service policy for delivery -------------------------------------------

run "no_service_policy_by_default" {
  assert {
    condition     = length(oci_identity_policy.service) == 0
    error_message = "No IAM policy may be created unless create_service_policy is true."
  }

  assert {
    condition     = output.service_policy_id == null
    error_message = "service_policy_id must be null when no policy is created."
  }

  assert {
    condition     = length(output.service_policy_statements) == 0
    error_message = "service_policy_statements must be empty when no policy is created."
  }
}

run "service_policy_for_ons_grants_topic_publish_only" {
  variables {
    display_name          = "test instance events"
    create_service_policy = true
  }

  assert {
    condition = oci_identity_policy.service[0].statements == tolist([
      "Allow service cloudEvents to use ons-topics in compartment id ocid1.compartment.oc1..aaaaaaaaexamplecompartment",
    ])
    error_message = "An ONS-only rule must get exactly the ons-topics statement, scoped to the rule's compartment."
  }

  assert {
    condition     = oci_identity_policy.service[0].compartment_id == var.compartment_id
    error_message = "The policy must default to the rule's compartment."
  }

  assert {
    condition     = oci_identity_policy.service[0].name == "test-instance-events-events-delivery"
    error_message = "The default policy name must be the sanitised display_name plus -events-delivery."
  }

  assert {
    condition     = output.service_policy_id == oci_identity_policy.service[0].id
    error_message = "service_policy_id must expose the policy OCID."
  }
}

run "service_policy_covers_every_action_type_once" {
  variables {
    create_service_policy         = true
    service_policy_compartment_id = "ocid1.compartment.oc1..aaaaaaaatargetcompartment"
    service_policy_name           = "events-delivery"
    actions = [
      {
        action_type = "FAAS"
        function_id = "ocid1.fnfunc.oc1..aaaaaaaaexamplefunction"
      },
      {
        action_type = "OSS"
        stream_id   = "ocid1.stream.oc1..aaaaaaaaexamplestream"
      },
      {
        action_type = "ONS"
        topic_id    = "ocid1.onstopic.oc1..aaaaaaaaexampletopic"
      },
      {
        action_type = "ONS"
        topic_id    = "ocid1.onstopic.oc1..aaaaaaaaexampletopic2"
      },
    ]
  }

  assert {
    condition = oci_identity_policy.service[0].statements == tolist([
      "Allow service cloudEvents to use fn-invocation in compartment id ocid1.compartment.oc1..aaaaaaaatargetcompartment",
      "Allow service cloudEvents to use ons-topics in compartment id ocid1.compartment.oc1..aaaaaaaatargetcompartment",
      "Allow service cloudEvents to use stream-push in compartment id ocid1.compartment.oc1..aaaaaaaatargetcompartment",
      "Allow service cloudEvents to read streams in compartment id ocid1.compartment.oc1..aaaaaaaatargetcompartment",
    ])
    error_message = "Each action type present must add its statements exactly once, scoped to service_policy_compartment_id."
  }

  assert {
    condition     = oci_identity_policy.service[0].compartment_id == "ocid1.compartment.oc1..aaaaaaaatargetcompartment"
    error_message = "The policy must be created in service_policy_compartment_id."
  }

  assert {
    condition     = oci_identity_policy.service[0].name == "events-delivery"
    error_message = "service_policy_name must override the default name."
  }
}

run "service_policy_in_root_compartment_uses_tenancy_scope" {
  variables {
    create_service_policy         = true
    service_policy_compartment_id = "ocid1.tenancy.oc1..aaaaaaaaexampletenancy"
  }

  assert {
    condition = oci_identity_policy.service[0].statements == tolist([
      "Allow service cloudEvents to use ons-topics in tenancy",
    ])
    error_message = "A tenancy OCID must produce an 'in tenancy' statement."
  }
}

run "rejects_non_compartment_service_policy_compartment" {
  command = plan

  variables {
    create_service_policy         = true
    service_policy_compartment_id = "ocid1.onstopic.oc1..aaaaaaaaexampletopic"
  }

  expect_failures = [var.service_policy_compartment_id]
}

run "rejects_blank_service_policy_name" {
  command = plan

  variables {
    create_service_policy = true
    service_policy_name   = " "
  }

  expect_failures = [var.service_policy_name]
}
