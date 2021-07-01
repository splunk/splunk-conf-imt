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

resource "signalfx_detector" "cpu-nearing-capacity" {
  name         = "${var.sim_prefix} CPU Utilization Nearing Capacity (Static)"
  description  = "Alerts when cpu.utilization is above 95% for 5m or more"
  program_text = <<-EOF
  A = data('cpu.utilization', filter=filter('host', '<HOSTS-TO-CHECK>')).publish(label='A')
  detect(when(A > threshold(95), lasting='5m')).publish("${var.sim_prefix} CPU Utilization Nearing Capacity (Static)")
  EOF
  rule {
    detect_label       = "${var.sim_prefix} CPU Utilization Nearing Capacity (Static)"
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
