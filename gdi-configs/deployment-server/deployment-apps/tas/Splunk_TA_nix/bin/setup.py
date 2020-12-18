import splunk
import sys
import json
import splunk.bundle as bundle

class SetupService(splunk.rest.BaseRestHandler):
    def handle_GET(self):
        try:
            is_recognized_unix = not sys.platform.startswith('win')
            self.response.write(json.dumps(is_recognized_unix))
        except Exception as e:
            self.response.write(e)

    def handle_POST(self):
        sessionKey = self.sessionKey
        try:
            conf = bundle.getConf('app', sessionKey, namespace="Splunk_TA_nix", owner='nobody')
            stanza = conf.stanzas['install'].findKeys('is_configured')
            if stanza:
                if stanza["is_configured"] == "0" or stanza["is_configured"] == "false":
                    conf["install"]["is_configured"] = 'true'
                    splunk.rest.simpleRequest("/apps/local/Splunk_TA_nix/_reload", sessionKey=sessionKey)
            else:
                conf["install"]["is_configured"] = 'true'
                splunk.rest.simpleRequest("/apps/local/Splunk_TA_nix/_reload", sessionKey=sessionKey)
        except Exception as e:
            self.response.write(e)
