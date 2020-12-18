#!/usr/bin/env bash
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

. `dirname $0`/common.sh

assertHaveCommand lsof
HEADER='COMMAND     PID        USER   FD      TYPE             DEVICE     SIZE       NODE NAME'
HEADERIZE='{NR == 1 && $0 = header}'
CMD='lsof -nPs'
PRINTF='{printf "%-15.15s  %-10s  %-15.15s  %-8s %-8s  %-15.15s  %15s  %-20.20s  %-s\n", $1,$2,$3,$4,$5,$6,$7,$8,$9}'

if [ "x$KERNEL" = "xLinux" ] ; then
	HEADERIZE='NR == 1 {match($0, "USER"); separator=RSTART+RLENGTH; match($0, "NAME"); name_start=RSTART; mid_length=RSTART-separator; } 
	{   first_part=substr($0, 0, separator);
	 	mid_part=substr($0, separator, mid_length);
		last_part=substr($0, name_start);
		split(first_part, first, " ");
		split(mid_part, mid, " "); 
		split(last_part, last, " ");
		if (length(last) > 1 ) { for(ptr=2; ptr<=length(last); ptr++) { $(NF+1-length(last)) = $(NF+1-length(last)) FS last[ptr]; } }
		if (length(first) == 4) { $3=$4; $4=$5; $5=$6; $6=$7; $7=$8; $8=$9; $9=$10; }
	}
	NR==1 { $0 = header;}'
	FILTER='/Permission denied/ {next} {if ($4 == "NOFD" || $5 == "unknown") next}'
	FILL_BLANKS='{ if(length(mid) == 4) {$9=$8; $8=$7; $7="?" } else if(length(mid) == 3) {$9=$7; $8=$6; $7="?"; $6="?"; } }'
elif [ "x$KERNEL" = "xHP-UX" ] ; then
    FILTER='/Permission denied/ {next} {if ($4 == "NOFD" || $5 == "unknown") next}'
    FILL_BLANKS='{if (NF<9) {node=$7; name=$8; $7="?"; $8=node; $9=name}}'
elif [ "x$KERNEL" = "xSunOS" ] ; then
	failUnsupportedScript
elif [ "x$KERNEL" = "xAIX" ] ; then
	failUnsupportedScript
elif [ "x$KERNEL" = "xDarwin" ] ; then
	FILTER='{if ($5 ~ /KQUEUE|PIPE|PSXSEM/) next}'
	FILL_BLANKS='{if (NF<9) {name=$8; $8="?"; $9=name}}'
elif [ "x$KERNEL" = "xFreeBSD" ] ; then
	# the below syntax is valid when using zsh, bash, ksh
	if [[ $KERNEL_RELEASE =~ 11.* ]] ; then
		# empty condition to allow the execution of script as is
		echo > /dev/null
	else
		failUnsupportedScript
	fi
fi

assertHaveCommand $CMD
$CMD 2>$TEE_DEST | tee $TEE_DEST | awk "$HEADERIZE $FILTER $FILL_BLANKS $PRINTF"  header="$HEADER"
echo "Cmd = [$CMD 2>$TEE_DEST];  | awk '$HEADERIZE $FILTER $FILL_BLANKS $PRINTF' header=\"$HEADER\"" >> $TEE_DEST
