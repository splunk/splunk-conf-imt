require([
    'splunkjs/ready!',
    'splunkjs/mvc/simplexml/ready!',
    'underscore',
    'jquery',
    '../app/Splunk_TA_nix/components/js_sdk_extensions/scripted_inputs',
    '../app/Splunk_TA_nix/components/js_sdk_extensions/monitor_inputs'
], function (
    mvc,
    ignored,
    _,
    $,
    sdkx_scripted_inputs,
    sdkx_monitor_inputs
) {
    var ScriptedInputs = sdkx_scripted_inputs.ScriptedInputs;
    var MonitorInputs = sdkx_monitor_inputs.MonitorInputs;

    var service = mvc.createService();
    var cleaned_data = {};

    // -------------------------------------------------------------------------
    // Prerequisite Checks

    // Error if running on unrecognized unix
    // 
    service.get('/services/SetupService', cleaned_data, function (err, response) {
        if (err) {
            console.error("Problem fetching data", err);
        } else if (response.status === 200) {
            var isRecognizedUnix = JSON.parse(response.data);
            if (!isRecognizedUnix) {
                $('#not-unix-error').show();
                $('#save-btn').addClass('disabled');
            }
        } else {
            console.error('Problem checking whether splunkweb is running on Unix.');
        }
    });

    // -------------------------------------------------------------------------
    // Populate Tables

    var INPUT_ROW_TEMPLATE = _.template(
        '<tr class="input" data-fullname="<%- fullname %>">\n' +
        '    <td><%- name %></td>\n' +
        '    <td><input class="enable-btn"  type="radio" name="<%- name %>" <% if (enabled)  { %>checked="checked"<% } %> /></td>\n' +
        '    <td><input class="disable-btn" type="radio" name="<%- name %>" <% if (!enabled) { %>checked="checked"<% } %> /></td>\n' +
        '<% if (interval != -1) { %>\n' +
        '    <td><input class="interval-field" type="number" value="<%- interval %>" /></td>\n' +
        '<% } %>\n' +
        '<% if (index != -1) { %>\n' +
        '   <% if (index == "") { %>\n' +
        '       <td>' +
        '       <splunk-search-dropdown name="metric_index_selector" id="index-selection" label-field="title" value-field="title" search="| rest services/data/indexes  datatype=metric | dedup title | search title!=_*  | table title"/>' +
        '       </td>\n' +
        '   <% }else { %>\n' +
        '       <td>' +
        '       <splunk-search-dropdown name="metric_index_selector" id="index-selection" label-field="title" value-field="title" value="<%- index %>" search="| rest services/data/indexes  datatype=metric | dedup title | search title!=_*  | table title"/>' +
        '       </td>\n' +
        '   <% } %>\n' +
        '<% } %>\n' +
        '</tr>\n');

    // Populate monitor input table
    var monitorInputs = {};
    new MonitorInputs(
        service,
        { owner: '-', app: 'Splunk_TA_nix', sharing: 'app' }
    ).fetch(function (err, inputs) {
        var inputsList = _.filter(inputs.list(), function (input) {
            return input.namespace.app === 'Splunk_TA_nix';
        });

        _.each(inputsList, function (input) {
            $('#monitor-input-table').append($(INPUT_ROW_TEMPLATE({
                fullname: input.name,
                name: input.name,
                enabled: !input.properties().disabled,
                interval: -1,
                index: -1
            })));
            monitorInputs[input.name] = input;
        });
    });

    // Populate scripted Event inputs table
    var scriptedMetricInputs = {};
    new ScriptedInputs(
        service,
        { owner: '-', app: 'Splunk_TA_nix', sharing: 'app' }
    ).fetch(function (err, inputs) {
        var inputsList = _.filter(inputs.list(), function (input) {
            var input_name = input.name.substring(input.name.lastIndexOf('/') + 1).split("_");
            return (input.namespace.app === 'Splunk_TA_nix' && input_name[input_name.length - 1] === "metric.sh");
        });

        _.each(inputsList, function (input) {
            $('#scripted-metric-input-table').append($(INPUT_ROW_TEMPLATE({
                fullname: input.name,
                name: input.name.substring(input.name.lastIndexOf('/') + 1),
                enabled: !input.properties().disabled,
                interval: input.properties().interval,
                index: input.properties().index === "default" ? "" : input.properties().index
            })));
            scriptedMetricInputs[input.name] = input;
        });
    });

    // Populate scripted Event inputs table
    var scriptedEventInputs = {};
    new ScriptedInputs(
        service,
        { owner: '-', app: 'Splunk_TA_nix', sharing: 'app' }
    ).fetch(function (err, inputs) {
        var inputsList = _.filter(inputs.list(), function (input) {
            var input_name = input.name.substring(input.name.lastIndexOf('/') + 1).split("_");
            return (input.namespace.app === 'Splunk_TA_nix' && input_name[input_name.length - 1] !== "metric.sh");
        });

        _.each(inputsList, function (input) {
            $('#scripted-event-input-table').append($(INPUT_ROW_TEMPLATE({
                fullname: input.name,
                name: input.name.substring(input.name.lastIndexOf('/') + 1),
                enabled: !input.properties().disabled,
                interval: input.properties().interval,
                index: -1
            })));
            scriptedEventInputs[input.name] = input;
        });
    });


    // -------------------------------------------------------------------------
    // Buttons

    // Enable All button
    $('.enable-all-btn').click(function (e) {
        e.preventDefault();
        var table = $(e.target).closest('.input-table');
        $('.input .enable-btn', table).prop('checked', true);
    });

    // Disable All button
    $('.disable-all-btn').click(function (e) {
        e.preventDefault();
        var table = $(e.target).closest('.input-table');
        $('.input .disable-btn', table).prop('checked', true);
    });

    // Save button
    $('#save-btn').click(function (e) {
        e.preventDefault();
        if ($('#save-btn').hasClass('disabled')) {
            return;
        }

        var savesPending = 0;
        var saveErrors = [];

        // Save monitor inputs
        _.each($('#monitor-input-table .input'), function (inputElem) {
            var fullname = $(inputElem).data('fullname');
            var enabled = $('.enable-btn', inputElem).prop('checked');

            var input = monitorInputs[fullname];

            savesPending += 1;
            input.update({
                'disabled': !enabled
            }, saveDone);
        });

        var invalidIndex = 0;      // invalid index flag
        var invalidInterval = 0;   // invalid interval flag
        var numbers = /^[0-9]+$/;
        // Save scripted Metric inputs
        _.each($('#scripted-metric-input-table .input'), function (inputElem) {
            var fullname = $(inputElem).data('fullname');
            var enabled = $('.enable-btn', inputElem).prop('checked');
            var interval = $('.interval-field', inputElem).val();
            var index = $('#index-selection', inputElem)[0].outerText;
            if (index.includes("Select...") || index.includes("Search produced no results.")) {
                index = (enabled === true ? index : "");   // Setting index="" if input is disable, so it allows to save.
                if (enabled) {
                    invalidIndex = 1;
                }
            }
            if (!interval.match(numbers)) {                // Check for the interval, Interval must contain only numeric values
                if (interval.charAt(0) === "-" || interval.includes(".")) {
                    interval = "invalid";
                }
                invalidInterval = 1;
            }
            var input = scriptedMetricInputs[fullname];
            savesPending += 1;
            input.update({
                'disabled': !enabled,
                'interval': interval,
                'index': index
            }, saveDone);
        });

        // Save scripted Event inputs
        _.each($('#scripted-event-input-table .input'), function (inputElem) {
            var fullname = $(inputElem).data('fullname');
            var enabled = $('.enable-btn', inputElem).prop('checked');
            var interval = $('.interval-field', inputElem).val();
            if (!interval.match(numbers)) {
                if (interval.charAt(0) === "-" || interval.includes(".")) {
                    interval = "invalid";
                }
                invalidInterval = 1;
            }
            var input = scriptedEventInputs[fullname];
            savesPending += 1;
            input.update({
                'disabled': !enabled,
                'interval': interval
            }, saveDone);
        });

        //Set is_configured=true in app.conf
        service.post('/services/SetupService', cleaned_data, function (err, response) {
            if (err) {
                console.log("Error saving configuration in app.conf");
            }
        });

        // After saves are completed...
        function saveDone(err) {
            $('#index-not-selected-error').hide();
            $('#generic-save-error').hide();
            $('#invalid-interval-error').hide();
            if (err) {
                saveErrors.push(err);
            }

            savesPending -= 1;
            if (savesPending > 0) {
                return;
            }
            if (saveErrors.length === 0) {
                // Save successful. Provide feedback in form of page reload.
                window.location.reload();
            } else {

                // invalid index or interval failure
                if (invalidIndex || invalidInterval) {
                    if (invalidInterval) {
                        invalidInterval = 0;
                        // invalid interval failure
                        $('#invalid-interval-error').show();
                    }
                    if (invalidIndex) {
                        invalidIndex = 0;
                        // invalid index failure
                        $('#index-not-selected-error').show();
                    }
                } else {
                    // Unexpected failure.
                    $('#generic-save-error').show();
                }

                // (Allow Support to debug if necessary.)
                console.log('Errors while saving inputs:');
                console.log(saveErrors);
            }
        }
    });
});