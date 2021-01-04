# Overview
This repo contains all of the configuration necessary to quickly deploy a working set of GDI, visualization, and alerting configurations for Splunk Infrastructure Monitoring and Troublehshooting that aligns with our customers most commonly requested use cases and the use cases we have outlined in the IMT Autobahn

# Installation Pre-requisites
This section covers the steps that should be done before this app can be configured and used. The steps and process for doing these things are well documented and processed elsewhere

1. Deploy UF and SA to desired hosts correctly configured to "phone home" to Splunk deployment server
2. Configure UF (via outputs.conf) to send data to Splunk as expected (validate internal logs from UF) 
3. Configure SA (via agent.yaml) to send data to SIM as expected (validate presence of basic host metrics)
4. Ensure $SPLUNK_HOME is present and accurate on all Splunk instances (including UFs)

# Installation Steps
1. From DS perform the following
 a. git clone https://github.com/splunk/splunk-conf-imt.git
 b. cd splunk-conf-imt/
 c. ./deployment-configs/ds_deploy.sh
