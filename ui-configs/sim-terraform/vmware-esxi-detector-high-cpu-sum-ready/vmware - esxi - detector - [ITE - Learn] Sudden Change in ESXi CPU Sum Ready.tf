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

resource "signalfx_detector" "vmware-esxi-sum-ready-sudden-change" {
  name         = "${var.sim_prefix} VMWare ESXi Sudden Change in CPU Sum Ready"
  description  = "Alerts when vsphere.cpu_sum_ready suddenly rises across VMs on an ESXi host"
  program_text = <<-EOF
  from signalfx.detectors.against_recent import against_recent
  A = data('vsphere.cpu_ready_ms').mean(by=['esx_ip']).publish(label='A')
  against_recent.detector_mean_std(stream=A, current_window='8m', historical_window='1h', fire_num_stddev=3, clear_num_stddev=2.5, orientation='above', ignore_extremes=True, calculation_mode='vanilla').publish('${var.sim_prefix} VMWare ESXi Sudden Change in CPU Sum Ready')
  EOF
  rule {
    detect_label       = "${var.sim_prefix} VMWare ESXi Sudden Change in CPU Sum Ready"
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
