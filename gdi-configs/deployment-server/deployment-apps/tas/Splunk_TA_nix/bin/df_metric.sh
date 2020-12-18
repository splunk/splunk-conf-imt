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

. `dirname $0`/common.sh

HEADER='Filesystem                                          Type              Size        Used       Avail      UsePct    OSName                                   OS_version  IP_address        MountedOn'
HEADERIZE='/^Filesystem/ {print header; next}'
PRINTF='{printf "%-50s  %-10s  %10s  %10s  %10s  %10s    %-35s %15s  %-16s  %s\n", $1, $2, $3, $4, $5, $6, OSName, OS_version, IP_address, $7}'
FILL_DIMENSIONS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?"}'

if [ "x$KERNEL" = "xLinux" ] ; then
    assertHaveCommand df  
    CMD='df -TPk'
    if [ ! -f "/etc/os-release" ] ; then
        DEFINE="-v OSName=$(cat /etc/*release | head -n 1| awk -F" release " '{print $1}'| tr ' ' '_') -v OS_version=$(cat /etc/*release | head -n 1| awk -F" release " '{print $2}' | cut -d\. -f1) -v IP_address=$(hostname -I | cut -d\  -f1)"
    else
        DEFINE="-v OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d\= -f2 | tr ' ' '_' | cut -d\" -f2) -v OS_version=$(cat /etc/*release | grep '\bVERSION_ID=' | cut -d\= -f2 | cut -d\" -f2) -v IP_address=$(hostname -I | cut -d\  -f1)"
    fi
    FORMAT='{OSName=OSName;OS_version=OS_version;IP_address=IP_address;if(substr($6,length($6),1)=="%") $6=substr($6, 1, length($6)-1);}'
    FILTER_POST='($2 ~ /^(devtmpfs|tmpfs)$/) {next}'
elif [ "x$KERNEL" = "xSunOS" ] ; then
    assertHaveCommandGivenPath /usr/bin/df
    CMD='eval /usr/bin/df -n; /usr/bin/df -k'
    DEFINE="-v OSName=`uname -s` -v OS_version=`uname -r` -v IP_address=`ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1`"
    FILTER_PRE='/libc_psr/ {next}'
    MAP_FS_TO_TYPE='/: / {fsTypes[$1] = $2; next}'
    BEGIN='BEGIN { FS = "[ \t]*:?[ \t]+" }'
    FORMAT='{size=$2; used=$3; avail=$4; usePct=$5; mountedOn=$6; $2=fsTypes[mountedOn]; $3=size; $4=used; $5=avail; if(substr(usePct,length(usePct),1)=="%") $6=substr(usePct, 1, length(usePct)-1); else $6=usePct; $7=mountedOn; OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    FILTER_POST='($2 ~ /^(devfs|ctfs|proc|mntfs|objfs|lofs|fd|tmpfs)$/) {next} ($1 == "/proc") {next}'
elif [ "x$KERNEL" = "xAIX" ] ; then
    assertHaveCommandGivenPath /usr/bin/df
    CMD='eval /usr/sysv/bin/df -n ; /usr/bin/df -kP'
    DEFINE="-v OSName=$(uname -s) -v OSVersion=$(oslevel -r | cut -d'-' -f1) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    MAP_FS_TO_TYPE='/: / {fsTypes[$1] = $3; next}'
    FORMAT='{size=$2; used=$3; avail=$4; usePct=$5; mountedOn=$6; $2=fsTypes[mountedOn]; $3=size; $4=used; $5=avail; if(substr(usePct,length(usePct),1)=="%") $6=substr(usePct, 1, length(usePct)-1); else $6=usePct; $7=mountedOn; if ($2=="") {$2="?"}; OSName=OSName;OS_version=OSVersion/1000;IP_address=IP_address;}'
    FILTER_POST='($2 ~ /^(proc)$/) {next} ($1 == "/proc") {next}'
elif [ "x$KERNEL" = "xHP-UX" ] ; then
    assertHaveCommand df
    assertHaveCommand fstyp
    CMD='df -Pk'
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    MAP_FS_TO_TYPE='{c="fstyp " $1; c | getline ft; close(c);}'
    FORMAT='{size=$2; used=$3; avail=$4; usePct=$5; mountedOn=$6; $2=ft; $3=size; $4=used; $5=avail; if(substr(usePct,length(usePct),1)=="%") $6=substr(usePct, 1, length(usePct)-1); else $6=usePct; $7=mountedOn; OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    FILTER_POST='($2 ~ /^(tmpfs)$/) {next}'
elif [ "x$KERNEL" = "xDarwin" ] ; then
    assertHaveCommand mount
    assertHaveCommand df
    CMD='eval mount -t nocddafs,autofs,devfs,fdesc,nfs; df -k -T nocddafs,autofs,devfs,fdesc,nfs'
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    MAP_FS_TO_TYPE='/ on / {fs=$1; sub("^.*\134(", "", $0); sub(",.*$", "", $0); fsTypes[fs] = $0; next}'
    FORMAT='{size=$2; used=$3; avail=$4; usePct=$5; mountedOn=$9; for(i=10; i<=NF; i++) mountedOn = mountedOn " " $i; $2=fsTypes[$1]; $3=size; $4=used; $5=avail; if(substr(usePct,length(usePct),1)=="%") $6=substr(usePct, 1, length(usePct)-1); else $6=usePct; $7=mountedOn; OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    NORMALIZE='{sub("^/dev/", "", $1); sub("s[0-9]+$", "", $1)}'
elif [ "x$KERNEL" = "xFreeBSD" ] ; then
    assertHaveCommand mount
    assertHaveCommand df
    CMD='eval mount -t nodevfs,nonfs,noswap,nocd9660; df -k -t nodevfs,nonfs,noswap,nocd9660'
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    MAP_FS_TO_TYPE='/ on / {fs=$1; sub("^.*\134(", "", $0); sub(",.*$", "", $0); fsTypes[fs] = $0; next}'
    FORMAT='{size=$2; used=$3; avail=$4; usePct=$5; mountedOn=$6; $2=fsTypes[$1]; $3=size; $4=used; $5=avail; if(substr(usePct,length(usePct),1)=="%") $6=substr(usePct, 1, length(usePct)-1); else $6=usePct; $7=mountedOn; OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
fi

$CMD | tee $TEE_DEST | $AWK $DEFINE "$BEGIN $HEADERIZE $FILTER_PRE $MAP_FS_TO_TYPE $FORMAT $FILTER_POST $NORMALIZE $FILL_DIMENSIONS $PRINTF" header="$HEADER"
echo "Cmd = [$CMD];  | $AWK $DEFINE '$BEGIN $HEADERIZE $FILTER_PRE $MAP_FS_TO_TYPE $FORMAT $FILTER_POST $NORMALIZE $FILL_DIMENSIONS $PRINTF' header=\"$HEADER\"" >>$TEE_DEST
