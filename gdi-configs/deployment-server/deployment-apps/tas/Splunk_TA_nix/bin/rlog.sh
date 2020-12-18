#!/bin/sh
# Copyright (C) 2019 Splunk Inc. All Rights Reserved.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# credit for improvement to http://splunk-base.splunk.com/answers/41391/rlogsh-using-too-much-cpu
. `dirname $0`/common.sh

OLD_SEEK_FILE=$SPLUNK_HOME/var/run/splunk/unix_audit_seekfile # For handling upgrade scenarios
CURRENT_AUDIT_FILE=/var/log/audit/audit.log # For handling upgrade scenarios
SEEK_FILE=$SPLUNK_HOME/var/run/splunk/unix_audit_seektime
AUDIT_FILE=/var/log/audit/audit.log*

if [ "x$KERNEL" = "xLinux" ] ; then
    assertInvokerIsSuperuser
    assertHaveCommand service
    assertHaveCommandGivenPath /sbin/ausearch
    if [ -n "`service auditd status 2>/dev/null`" -a "$?" -eq 0 ] ; then
            CURRENT_TIME=$(date --date="1 seconds ago" +"%m/%d/%Y %T") # 1 second ago to avoid data loss

            if [ -e $SEEK_FILE ] ; then
                SEEK_TIME=`head -1 $SEEK_FILE`
                awk " { print } " $AUDIT_FILE | /sbin/ausearch -i -ts $SEEK_TIME -te $CURRENT_TIME | grep -v "^----" 

            elif [ -e $OLD_SEEK_FILE ] ; then
                rm -rf $OLD_SEEK_FILE # remove previous checkpoint
                # start ingesting from the first entry of current audit file                
                awk ' { print } ' $CURRENT_AUDIT_FILE | /sbin/ausearch -i -te $CURRENT_TIME | grep -v "^----"
            
            else
                # no checkpoint found
                awk " { print } " $AUDIT_FILE | /sbin/ausearch -i  -te $CURRENT_TIME | grep -v "^----"
            fi
            echo "$CURRENT_TIME" > $SEEK_FILE # Checkpoint+
    
    elif [ "`service auditd status`" -a ] ; then    # Added this condition to get error logs
        :
    fi
elif [ "x$KERNEL" = "xSunOS" ] ; then
    :
elif [ "x$KERNEL" = "xDarwin" ] ; then
    :
elif [ "x$KERNEL" = "xHP-UX" ] ; then
	:
elif [ "x$KERNEL" = "xFreeBSD" ] ; then
	:
fi
