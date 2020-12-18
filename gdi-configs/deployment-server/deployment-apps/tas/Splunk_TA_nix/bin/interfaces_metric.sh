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

HEADER='Name       MAC                inetAddr         inet6Addr                                  Collisions  RXbytes          RXerrors         TXbytes          TXerrors         Speed        Duplex          OSName                                   OS_version  IP_address'
FORMAT='{mac = length(mac) ? mac : "?"; collisions = length(collisions) ? collisions : "?"; RXbytes = length(RXbytes) ? RXbytes : "?"; RXerrors = length(RXerrors) ? RXerrors : "?"; TXbytes = length(TXbytes) ? TXbytes : "?"; TXerrors = length(TXerrors) ? TXerrors : "?"; speed = length(speed) ? speed : "?"; duplex = length(duplex) ? duplex : "?"}'
PRINTF='END {printf "%-10s %-17s  %-15s  %-42s %-10s  %-16s %-16s %-16s %-16s %-12s %-12s    %-35s %15s  %-16s\n", name, mac, IPv4, IPv6, collisions, RXbytes, RXerrors, TXbytes, TXerrors, speed, duplex, OSName, OS_version, IP_address}'

if [ "x$KERNEL" = "xLinux" ] ; then
	HEADER='Name       MAC                inetAddr         inet6Addr                                  Collisions  RXbytes          RXerrors         RXdropped          TXbytes          TXerrors         TXdropped          Speed        Duplex          OSName                                   OS_version  IP_address'
	PRINTF='END {printf "%-10s %-17s  %-15s  %-42s %-10s  %-16s %-16s %-18s %-16s %-16s %-18s %-12s %-12s    %-35s %15s  %-16s\n", name, mac, IPv4, IPv6, collisions, RXbytes, RXerrors, RXdropped, TXbytes, TXerrors, TXdropped, speed, duplex, OSName, OS_version, IP_address}'
	queryHaveCommand ip
	FOUND_IP=$?
	queryHaveCommand ethtool
	FOUND_ETHTOOL=$?
	if [ ! -f "/etc/os-release" ] ; then
        DEFINE="-v OSName=$(cat /etc/*release | head -n 1| awk -F" release " '{print $1}'| tr ' ' '_') -v OS_version=$(cat /etc/*release | head -n 1| awk -F" release " '{print $2}' | cut -d\. -f1) -v IP_address=$(hostname -I | cut -d\  -f1)"
    else
        DEFINE="-v OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d\= -f2 | tr ' ' '_' | cut -d\" -f2) -v OS_version=$(cat /etc/*release | grep '\bVERSION_ID=' | cut -d\= -f2 | cut -d\" -f2) -v IP_address=$(hostname -I | cut -d\  -f1)"
    fi
	if [ $FOUND_IP -eq 0 ]; then
		CMD_LIST_INTERFACES="eval ip -s a | tee $TEE_DEST|grep 'state UP' | grep mtu | grep -Ev lo | tee -a $TEE_DEST | cut -d':' -f2 | tee -a $TEE_DEST | cut -d '@' -f 1 | tee -a $TEE_DEST | sort -u | tee -a $TEE_DEST"		
		CMD='eval ip addr show $iface; ip -s link show'
		GET_IPv4='{if ($0 ~ /inet /) {split($2, a, " "); IPv4 = a[1]}}'
		GET_IPv6='{if ($0 ~ /inet6 /) { IPv6 = $2 }}'
		GET_TXbytes='($0 ~ /TX: bytes /) {nr[NR+1]} NR in nr { TXbytes=$1; TXerrors=$3; TXdropped=$4; collisions=$6; }'
		GET_RXbytes='($0 ~ /RX: bytes /) {nr2[NR+1]} NR in nr2 { RXbytes=$1; RXerrors=$3; RXdropped=$4; }'
	else
		assertHaveCommand ifconfig
		CMD_LIST_INTERFACES="eval ifconfig | tee $TEE_DEST | grep 'Link encap:\|mtu' | grep -Ev lo | tee -a $TEE_DEST | cut -d' ' -f1 | cut -d':' -f1 | tee -a $TEE_DEST | sort -u | tee -a $TEE_DEST"
		CMD='ifconfig'
		GET_IPv4='{if ($0 ~ /inet addr:/) {split($2, a, ":"); IPv4 = a[2]} else if ($0 ~ /inet /) {IPv4 = $2}}'
		GET_IPv6='{if ($0 ~ /inet6 addr:/) { IPv6 = $3 } else if ($0 ~ /inet6 /) { IPv6 = $2 }}'
		GET_COLLISIONS='{if ($0 ~ /collisions:/) {split($1, a, ":"); collisions = a[2]; } else if ($10 ~ /collisions /) { collisions = $11; }}'
		GET_RXbytes='{if ($0 ~ /RX bytes:/) {split($2, a, ":"); RXbytes= a[2];} else if ($0 ~ /RX packets /) { RXbytes=$5; }}'
		GET_RXerrors='{if ($0 ~ /RX packets:/) {split($3, a, ":"); RXerrors=a[2]; split($4, b, ":"); RXdropped=b[2]; } else if ($0 ~ /RX errors /) { RXerrors=$3; RXdropped=$5; }}'
		GET_TXbytes='{if ($0 ~ /TX bytes:/) {split($6, a, ":"); TXbytes= a[2]; } else if ($0 ~ /TX packets /) { TXbytes=$5; }}'
		GET_TXerrors='{if ($0 ~ /TX packets:/) {split($3, a, ":"); TXerrors=a[2]; split($4, b, ":"); TXdropped=b[2]; } else if ($0 ~ /TX errors /) { TXerrors=$3; TXdropped=$5; }}'
	fi
	GET_ALL="$GET_IPv4 $GET_IPv6 $GET_COLLISIONS $GET_RXbytes $GET_RXerrors $GET_TXbytes $GET_TXerrors"
	FILL_BLANKS='{length(TXdropped) || TXdropped = "<n/a>";length(RXdropped) || RXdropped = "<n/a>";length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?";length(speed) || speed = "<n/a>"; length(duplex) || duplex = "<n/a>"; length(IPv4) || IPv4 = "<n/a>"; length(IPv6) || IPv6= "<n/a>"}'
	BEGIN='BEGIN {RXbytes = TXbytes = collisions = 0}'

	out=`$CMD_LIST_INTERFACES`
	lines=`echo "$out" | wc -l`
	if [ $lines -gt 0 ]; then
		echo "$HEADER"
	fi
	for iface in $out
	do
		# ethtool(8) would be preferred, but requires root privs; so we use dmesg(8), whose [a] source can be cleared, and [b] output format varies (so we have less confidence in parsing)
		if [ -r /sys/class/net/$iface/duplex ]; then
			DUPLEX=`cat /sys/class/net/$iface/duplex 2>/dev/null || echo 'error'`
			if [ "$DUPLEX" != 'error' ]; then
				DUPLEX=`echo $DUPLEX | sed 's/./\u&/'`
				if [ -r /sys/class/net/$iface/speed ]; then
					SPEED=`cat /sys/class/net/$iface/speed 2>/dev/null || echo 'error'`
					[ ! -z "$SPEED" ] && [ "$SPEED" != 'error' ] && SPEED="${SPEED}Mb/s"
				elif [ $FOUND_ETHTOOL -eq 0 ]; then
					SPEED=`ethtool $iface | grep Speed: | sed -e 's/^[ \t]*//' | tr -s ' ' | cut -d' ' -f2`
				else
					assertHaveCommand dmesg
					SPEED=`dmesg  | awk '/[Ll]ink( is | )[Uu]p/ && /'$iface'/ {for (i=1; i<=NF; ++i) {if (match($i, /([0-9]+)([Mm]bps)/))             {print $i} else { if (match($i, /[Mm]bps/))   {print $(i-1) "Mb/s"} } } }' | sed '$!d'`
				fi
			else
				DUPLEX=""
			fi
		fi
		if [ $FOUND_ETHTOOL -eq 0 ] && [ "$DUPLEX" = "" ] ; then
			SPEED=`ethtool $iface | grep Speed: | sed -e 's/^[ \t]*//' | tr -s ' ' | cut -d' ' -f2`
			DUPLEX=`ethtool $iface | grep Duplex: | sed -e 's/^[ \t]*//' | tr -s ' ' | cut -d' ' -f2`
		fi
		if [ "$DUPLEX" = "" ] || [ "$SPEED" = "" ] ; then
			assertHaveCommand dmesg
			# Get Duplex only if still null
			if [ "$DUPLEX" = "" ] ; then
				DUPLEX=`dmesg | awk '/[Ll]ink( is | )[Uu]p/ && /'$iface'/ {for (i=1; i<=NF; ++i) {if (match($i, /([\-\_a-zA-Z0-9]+)([Dd]uplex)/)) {print $i} else { if (match($i, /[Dd]uplex/)) {print $(i-1)       } } } }' | sed 's/[-_]//g; $!d'`
			fi
			# Get Speed only if still null
			if [ "$SPEED" = "" ] ; then
				SPEED=`dmesg  | awk '/[Ll]ink( is | )[Uu]p/ && /'$iface'/ {for (i=1; i<=NF; ++i) {if (match($i, /([0-9]+)([Mm]bps)/))             {print $i} else { if (match($i, /[Mm]bps/))   {print $(i-1) "Mb/s"} } } }' | sed '$!d'`
			fi
		fi
		if [ $FOUND_IP -eq 0 ]; then
			GET_MAC='{if ($0 ~ /ether /) { mac = $2 }}'
		elif [ -r /sys/class/net/$iface/address ]; then
			MAC=`cat /sys/class/net/$iface/address`
		else
			GET_MAC='{if ($0 ~ /ether /) { mac = $2; } else if ( NR == 1 ) { mac = $5; }}'
		fi
		if [ "$DUPLEX" != 'error' ] && [ "$SPEED" != 'error' ]; then
			$CMD $iface | tee -a $TEE_DEST | awk $DEFINE "$BEGIN $GET_MAC $GET_ALL $FILL_BLANKS $PRINTF" name=$iface speed=$SPEED duplex=$DUPLEX mac=$MAC || error="true"
	 		echo "Cmd = [$CMD $iface];     | awk $DEFINE '$BEGIN $GET_MAC $GET_ALL $FILL_BLANKS $PRINTF' name=$iface speed=$SPEED duplex=$DUPLEX mac=$MAC" >> $TEE_DEST
		else
			echo "ERROR: cat command failed for interface $iface" >> $TEE_DEST
		fi
	done

elif [ "x$KERNEL" = "xSunOS" ] ; then
	assertHaveCommandGivenPath /usr/sbin/ifconfig
	assertHaveCommand kstat

	CMD_LIST_INTERFACES="eval /usr/sbin/ifconfig -au | tee $TEE_DEST | egrep -v 'LOOPBACK|netmask' | tee -a $TEE_DEST | grep flags | cut -d':' -f1 | tee -a $TEE_DEST | sort -u | tee -a $TEE_DEST"
	DEFINE="-v OSName=`uname -s` -v OS_version=`uname -r` -v IP_address=`ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1`"
    if [ SOLARIS_8 = false ] && [ SOLARIS_9 = false] ; then
		GET_COLLISIONS_RXbytes_TXbytes_SPEED_DUPLEX='($1=="collisions") {collisions=$2} (/duplex/) {duplex=$2} ($1=="rbytes") {RXbytes=$2} ($1=="obytes") {TXbytes=$2} (/ierrors/) {RXerrors=$2} (/oerrors/) {TXerrors=$2} ($1=="ifspeed") {speed=$2; speed/=1000000; speed=speed "Mb/s"}' 
	else
		GET_COLLISIONS_RXbytes_TXbytes_SPEED_DUPLEX='($1=="collisions") {collisions=$2} ($1=="duplex") {duplex=$2} ($1=="rbytes") {RXbytes=$2} ($1=="obytes") {TXbytes=$2} ($1=="ierrors") {RXerrors=$2} ($1=="oerrors") {TXerrors=$2} ($1=="ifspeed") {speed=$2; speed/=1000000; speed=speed "Mb/s"}'
	fi
	GET_IP='/ netmask / {for (i=1; i<=NF; i++) {if ($i == "inet") IPv4 = $(i+1); if ($i == "inet6") IPv6 = $(i+1)}}'
    GET_MAC='{if ($1 == "ether") {split($2, submac, ":"); mac=sprintf("%02s:%02s:%02s:%02s:%02s:%02s", submac[1], submac[2], submac[3], submac[4], submac[5], submac[6])}}'
	FILL_BLANKS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?";length(speed) || speed = "<n/a>"; length(duplex) || duplex = "<n/a>";IPv4 = IPv4 ? IPv4 : "<n/a>"; IPv6 = IPv6 ? IPv6 : "<n/a>"}'
	GET_ALL="$GET_COLLISIONS_RXbytes_TXbytes_SPEED_DUPLEX $GET_IP $GET_MAC $FILL_BLANKS"

	out=`$CMD_LIST_INTERFACES`
	lines=`echo "$out" | wc -l`
	if [ $lines -gt 0 ]; then
		echo "$HEADER"
	fi
	for iface in $out
	do
		echo "Cmd = [$CMD_LIST_INTERFACES]" >> $TEE_DEST
		NODE=`uname -n`
		if [ SOLARIS_8 = false ] && [ SOLARIS_9 = false] ; then
			CMD_DESCRIBE_INTERFACE="eval kstat -c net -n $iface ; /usr/sbin/ifconfig $iface 2>/dev/null"
		else
			CMD_DESCRIBE_INTERFACE="eval kstat -n $iface ; /usr/sbin/ifconfig $iface 2>/dev/null"
		fi
		$CMD_DESCRIBE_INTERFACE | tee -a $TEE_DEST | $AWK $DEFINE "$GET_ALL $FORMAT $PRINTF" name=$iface node=$NODE
		echo "Cmd = [$CMD_DESCRIBE_INTERFACE];     | $AWK $DEFINE '$GET_ALL $FORMAT $PRINTF' name=$iface node=$NODE" >> $TEE_DEST
	done
elif [ "x$KERNEL" = "xAIX" ] ; then
	assertHaveCommandGivenPath /usr/sbin/ifconfig
	assertHaveCommandGivenPath /usr/bin/netstat

	CMD_LIST_INTERFACES="eval /usr/sbin/ifconfig -au | tee $TEE_DEST | egrep -v 'LOOPBACK|netmask|inet6|tcp_sendspace' | tee -a $TEE_DEST | grep flags | cut -d':' -f1 | tee -a $TEE_DEST | sort -u | tee -a $TEE_DEST"
	DEFINE="-v OSName=$(uname -s) -v OSVersion=$(oslevel -r |  cut -d'-' -f1) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    	GET_COLLISIONS_RXbytes_TXbytes_SPEED_DUPLEX_ERRORS='($1=="Single"){collisions_s=$4} ($1=="Multiple"){collisions=collisions_s+$4} ($1=="Bytes:") {RXbytes=$4 ; TXbytes=$2} ($1=="Media" && $3=="Running:") {speed=$4"Mb/s" ; duplex=$6} ($1="Transmit" && $2="Errors:") {TXerrors=$3 ; RXerrors=$6}'
	GET_IP='/ netmask / {for (i=1; i<=NF; i++) {if ($i == "inet") IPv4 = $(i+1); if ($i == "inet6") IPv6 = $(i+1)}}'
	GET_MAC='/^Hardware Address:/{mac=$3}'
	GET_OS_VERSION='{OS_version=OSVersion/1000}'
	FILL_BLANKS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?";length(speed) || speed = "<n/a>"; length(duplex) || duplex = "<n/a>"; IPv4 = IPv4 ? IPv4 : "<n/a>"; IPv6 = IPv6 ? IPv6 : "<n/a>"}'
	GET_ALL="$GET_COLLISIONS_RXbytes_TXbytes_SPEED_DUPLEX_ERRORS $GET_IP $GET_MAC $GET_OS_VERSION $FILL_BLANKS"

	out=`$CMD_LIST_INTERFACES`
	lines=`echo "$out" | wc -l`
	if [ $lines -gt 0 ]; then
		echo "$HEADER"
	fi
	for iface in $out
	do
		echo "Cmd = [$CMD_LIST_INTERFACES]" >> $TEE_DEST
		NODE=`uname -n`
		CMD_DESCRIBE_INTERFACE="eval netstat -v $iface ; /usr/sbin/ifconfig $iface"
		$CMD_DESCRIBE_INTERFACE | tee -a $TEE_DEST | $AWK $DEFINE "$GET_ALL $FORMAT $PRINTF" name=$iface node=$NODE
		echo "Cmd = [$CMD_DESCRIBE_INTERFACE];     | $AWK $DEFINE '$GET_ALL $FORMAT $PRINTF' name=$iface node=$NODE" >> $TEE_DEST
	done
elif [ "x$KERNEL" = "xDarwin" ] ; then
	assertHaveCommand ifconfig
	assertHaveCommand netstat

	CMD_LIST_INTERFACES='ifconfig -u'
	DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    CHOOSE_ACTIVE='/^[a-z0-9]+: / {sub(":", "", $1); iface=$1} /status: active/ {print iface}'
	UNIQUE='sort -u'
	GET_MAC='{$1 == "ether" && mac = $2}'
	GET_IPv4='{$1 == "inet" && IPv4 = $2}'
	GET_IPv6='{if ($1 == "inet6") {sub("%.*$", "", $2);IPv6 = $2}}'
	GET_SPEED_DUPLEX='{if ($1 == "media:") {gsub("[^0-9]", "", $3); speed=$3 "Mb/s"; sub("-duplex.*", "", $4); sub("<", "", $4); duplex=$4}}'
	GET_RXbytes_TXbytes_COLLISIONS_ERRORS='{if ($4 == mac) {RXbytes = $7; RXerrors = $6; TXbytes = $10; TXerrors = $9; collisions = $11}}'
	FILL_BLANKS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?";length(speed) || speed = "<n/a>"; length(duplex) || duplex = "<n/a>"; IPv4 = IPv4 ? IPv4 : "<n/a>"; IPv6 = IPv6 ? IPv6 : "<n/a>"}'
	GET_ALL="$GET_MAC $GET_IPv4 $GET_IPv6 $GET_SPEED_DUPLEX $GET_RXbytes_TXbytes_COLLISIONS_ERRORS $FILL_BLANKS"

	out=`$CMD_LIST_INTERFACES | tee $TEE_DEST | awk "$CHOOSE_ACTIVE" | $UNIQUE | tee -a $TEE_DEST`
	lines=`echo "$out" | wc -l`
	if [ $lines -gt 0 ]; then
		echo "$HEADER"
	fi
	for iface in $out
	do
		echo "Cmd = [$CMD_LIST_INTERFACES];  | awk '$CHOOSE_ACTIVE' | $UNIQUE" >> $TEE_DEST
		CMD_DESCRIBE_INTERFACE="eval ifconfig $iface ; netstat -b -I $iface"
		$CMD_DESCRIBE_INTERFACE | tee -a $TEE_DEST | awk $DEFINE "$GET_ALL $PRINTF" name=$iface 
		echo "Cmd = [$CMD_DESCRIBE_INTERFACE];     | awk $DEFINE '$GET_ALL $PRINTF' name=$iface" >> $TEE_DEST
	done
elif [ "x$KERNEL" = "xHP-UX" ] ; then
    assertHaveCommand ifconfig
    assertHaveCommand lanadmin
    assertHaveCommand lanscan
    assertHaveCommand netstat

    CMD='lanscan'
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    LANSCAN_AWK='/^Hardware/ {next} /^Path/ {next} {mac=$2; ifnum=$3; ifstate=$4; name=$5; type=$8}'
    GET_IP4='{c="netstat -niwf inet | grep "name; c | getline; close(c); if (NF==10) {next} mtu=$2; IPv4=$4; RXbytes=$5; RXerrors=$6; TXbytes=$7; TXerrors=$8; collisions=$9}'
    GET_IP6='{c="netstat -niwf inet6 | grep "name" "; c| getline; close(c); IPv6=$3}'
    GET_SPEED_DUPLEX='{c="lanadmin -x "ifnum ; c | getline; close(c); if (NF==4) speed=$3"Mb/s"; sub("\-.*", "", $4); duplex=tolower($4)}'
    PRINTF='{printf "%-10s %-17s  %-15s  %-42s %-10s  %-16s %-16s %-16s %-16s %-12s %-12s    %-35s %15s  %-16s\n", name, mac, IPv4, IPv6, collisions, RXbytes, RXerrors, TXbytes, TXerrors, speed, duplex, OSName, OS_version, IP_address}'
    FILL_BLANKS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?";length(speed) || speed = "<n/a>"; length(duplex) || duplex = "<n/a>"; IPv4 = IPv4 ? IPv4 : "<n/a>"; IPv6 = IPv6 ? IPv6 : "<n/a>"}'
	out=`$CMD | awk "$LANSCAN_AWK $GET_IP4 $GET_IP6 $GET_SPEED_DUPLEX $PRINTF $FILL_BLANKS"`
	lines=`echo "$out" | wc -l`
	if [ $lines -gt 0 ]; then
		echo "$HEADER"
		echo "$out"
	fi
elif [ "x$KERNEL" = "xFreeBSD" ] ; then
	assertHaveCommand ifconfig
	assertHaveCommand netstat

	CMD_LIST_INTERFACES='ifconfig -a'
	DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    	CHOOSE_ACTIVE='/LOOPBACK/ {next} !/RUNNING/ {next} /^[a-z0-9]+: / {sub(":$", "", $1); print $1}'
	UNIQUE='sort -u'
	GET_MAC='{$1 == "ether" && mac = $2}'
	GET_IP='/ netmask / {for (i=1; i<=NF; i++) {if ($i == "inet") IPv4 = $(i+1); if ($i == "inet6") IPv6 = $(i+1)}}'
	GET_SPEED_DUPLEX='/media: / {sub("\134(", "", $4); speed=$4; sub("-duplex.*", "", $5); sub("<", "", $5); duplex=$5}'
	GET_RXbytes_TXbytes_COLLISIONS_ERRORS='(NF==12) {if ($4 == mac) {RXbytes = $8; RXerrors = $6; TXerrors = $10; TXbytes = $11; collisions = $12}}'
	FILL_BLANKS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?";length(speed) || speed = "<n/a>"; length(duplex) || duplex = "<n/a>"; IPv4 = IPv4 ? IPv4 : "<n/a>"; IPv6 = IPv6 ? IPv6 : "<n/a>"}'
	GET_ALL="$GET_MAC $GET_IP $GET_SPEED_DUPLEX $GET_RXbytes_TXbytes_COLLISIONS_ERRORS $FILL_BLANKS"

	out=`$CMD_LIST_INTERFACES | tee $TEE_DEST | awk "$CHOOSE_ACTIVE" | $UNIQUE | tee -a $TEE_DEST`
	lines=`echo "$out" | wc -l`
	if [ $lines -gt 0 ]; then
		echo "$HEADER"
	fi
	for iface in $out
	do
		echo "Cmd = [$CMD_LIST_INTERFACES];  | awk '$CHOOSE_ACTIVE' | $UNIQUE" >> $TEE_DEST
		CMD_DESCRIBE_INTERFACE="eval ifconfig $iface ; netstat -b -I $iface"
		$CMD_DESCRIBE_INTERFACE | tee -a $TEE_DEST | awk $DEFINE "$GET_ALL $PRINTF" name=$iface 
		echo "Cmd = [$CMD_DESCRIBE_INTERFACE];     | awk $DEFINE '$GET_ALL $PRINTF' name=$iface" >> $TEE_DEST
	done
fi