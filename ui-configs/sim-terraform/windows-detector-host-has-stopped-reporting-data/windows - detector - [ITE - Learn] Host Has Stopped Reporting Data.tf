####################################
# Base Configuration and variables

terraform {
  required_version = ">= 0.13"
  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "~> 6.7.4"
    }
  }
}

provider "signalfx" {
   auth_token = var.access_token
   api_url    = "https://api.${var.realm}.signalfx.com"
}

variable "access_token" {
  description = "SIM Access Token"
}

variable "realm" {
  description = "SIM Realm"
}

variable "sim_prefix" {
  type        = string
  description = "Splunk Infrastructure Monitoring (SIM) Detector Prefix"
  default     = "[ITE-Learn]"
}

####################################
# Customized Detector and Message Body

resource "signalfx_detector" "not_reporting" {
  name         = "${var.sim_prefix} Host Has Stopped Reporting Data"
  description  = "Alerts when no procstat process metrics have been received for > 15s for the specified host(s) and process(es)"
  program_text = <<-EOF
  from signalfx.detectors.not_reporting import not_reporting
  A = data('cpu.utilization', filter=filter('host.name', '<HOST-TO-CHECK>')).publish(label='A')
  not_reporting.detector(stream=A, resource_identifier=None, duration='15s').publish('${var.sim_prefix} Host Has Stopped Reporting Data')
  EOF
  rule {
    detect_label       = "${var.sim_prefix} Host Has Stopped Reporting Data"
    severity           = "Critical"
    parameterized_body = var.message_body
  }
}

variable "message_body" {
  type = string

  default = <<-EOF
    {{#if anomalous}}
            Rule "{{{ruleName}}}" in detector "{{{detectorName}}}" triggered at {{timestamp}}.
    {{else}}
            Rule "{{{ruleName}}}" in detector "{{{detectorName}}}" cleared at {{timestamp}}.
    {{/if}}

    {{#if anomalous}}
      Triggering condition: {{{readableRule}}}
    {{/if}}

    {{#if anomalous}}
      Signal value: {{inputs.A.value}}
    {{else}}
      Current signal value: {{inputs.A.value}}
    {{/if}}

    {{#notEmpty dimensions}}
      Signal details: {{{dimensions}}}
    {{/notEmpty}}

    {{#if anomalous}}
      {{#if runbookUrl}}
        Runbook: {{{runbookUrl}}}
      {{/if}}
      {{#if tip}}
        Tip: {{{tip}}}
      {{/if}}
    {{/if}}
  EOF
}
