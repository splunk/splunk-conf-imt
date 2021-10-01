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

resource "signalfx_detector" "vmware-esxi-memory-swap-sudden-change" {
  name         = "${var.sim_prefix} VMWare ESXi Sudden Change in Memory Swapping"
  description  = "Alerts when vsphere.mem_swapin_rate_kbs and vsphere.mem_swapout_rate_kbs suddenly rise an ESXi host"
  program_text = <<-EOF
  from signalfx.detectors.against_recent import against_recent
  A = data('vsphere.mem_swapin_rate_kbs', filter=filter('object_type', 'HostSystem')).publish(label='A', enable=False)
  B = data('vsphere.mem_swapout_rate_kbs', filter=filter('object_type', 'HostSystem')).publish(label='B', enable=False)
  C = (A+B).mean(by=['esx_ip']).publish(label='C')
  against_recent.detector_mean_std(stream=C, current_window='8m', historical_window='1h', fire_num_stddev=3, clear_num_stddev=2.5, orientation='above', ignore_extremes=True, calculation_mode='vanilla').publish('${var.sim_prefix} VMWare ESXi Sudden Change in Memory Swapping')
  EOF
  rule {
    detect_label       = "${var.sim_prefix} VMWare ESXi Sudden Change in Memory Swapping"
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
