# Overview
This repo contains all of the configuration necessary to quickly deploy a working set of GDI, visualization, and alerting configurations for Splunk Infrastructure Monitoring and Troublehshooting that aligns with our customers most commonly requested use cases and the use cases we have outlined in the IMT Autobahn

# Installation Pre-requisites
This section covers the steps that should be done before this app can be configured and used. The steps and process for doing these things are well documented and processed elsewhere

1. Deploy UF to desired hosts correctly configured to "phone home" to Splunk deployment server
2. Deploy SA to desires hosts (validate presence of basic host metrics in SIM)
2. Configure UF (via outputs.conf) to send data to Splunk as expected (validate internal logs from UF) 
3. Configure SA with base agent.yaml from this repo (re-validate presence of basic host metrics)
4. Ensure $SPLUNK_HOME is present and accurate on all Splunk instances (including UFs)

# Installation Steps
1. Deploy configs to deployment server
2. Deploy configs to indexers
3. Deploy configs to SH
4. Configure SIM TA with correct realm and token
5. Run SIM terraform
6. TODO configure SIM org ID into Splunk IMT Quick Start App

# Configure GDI
1. TODO deployment server stuff

# Usage Steps
1. Navigate to Splunk IMT Quick Start app on SH
2. Review use cases and procedures and click to view implementation
3. Customize as appropriate for proof
