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

resource "signalfx_detector" "countdown" {
  name         = "${var.sim_prefix} Host Disk Utilization Nearing Exhaustion"
  description  = "Alerts when increasing disk.utilization is projected to increase to 100 in 48 hours"
  program_text = <<-EOF
  from signalfx.detectors.countdown import countdown
  A = data('disk.utilization', filter=filter('host', '<HOSTS-TO-CHECK>') and filter('mountpoint', '<DISKS-TO-CHECK>')).publish(label='A')
  countdown.hours_left_stream_incr_detector(stream=A, maximum_capacity=100, lower_threshold=48, fire_lasting=lasting('12m', 0.95), clear_threshold=60, clear_lasting=lasting('12m', 0.95), use_double_ewma=False).publish("${var.sim_prefix} Host Disk Utilization Nearing Exhaustion")
  EOF
  rule {
    detect_label       = "${var.sim_prefix} Host Disk Utilization Nearing Exhaustion"
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
