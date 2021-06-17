resource "signalfx_detector" "not_reporting" {
  name         = "[ITE - Learn] Expected Process Not Running on Host"
  description  = "Alerts when no procstat process metrics have been received for > 15s for the specified host(s) and process(es)"
  program_text = <<-EOF
  from signalfx.detectors.not_reporting import not_reporting
  A = data('procstat.cpu_usage', filter=filter('host.name', '<HOST-TO-CHECK>') and filter('process_name', '<PROCESS-TO-CHECK>')).count(by=['host.name']).publish(label='A')
  not_reporting.detector(stream=A, resource_identifier=None, duration='15s').publish('[ITE - Learn] Expected Process Not Running on Host')
  EOF
  rule {
    detect_label       = "[ITE - Learn] Expected Process Not Running on Host"
    severity           = "Critical"
    parameterized_body = var.message_body
  }
}
