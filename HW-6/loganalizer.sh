#!/bin/bash

logFile=/var/log/httpd/access.log

cat $logFile | awk '/GET \/ HTTP/ { ipcount[$1]++ } END { for (i in ipcount) { printf "IP: %13s - %d times/n", i, ipcount[i] } }' | sort -rn > /tmp/ip.log

echo " "
echo "Top 10 Source IP address"
echo "______________________________________________________"

logTmp= /tmp/ip.log
awk '{ print $3 " times - IP:" $2}' $logTmp | sort -rn | head -10

echo " "
echo "Top 10 Destination address"
echo "______________________________________________________"

cat $logFile | awk '{ destcount[$7]++ } END { for (i in destcount) { printf "Destination address %13s - %d times/n", i, destcount[i] } }' | sort -rn > /tmp/uri.log

uriTmp=/tmp/uri.log
awk '{ print $4 " times - URI:" $3}' $uriTmp | sort -rn | head -10

echo " "
echo "Error count"
echo "______________________________________________________"

cat $logFile | awk '$9 !~ 200 && $9 !~ 301 { print $9 }' | sort -rn | wc -l

echo " "
echo "All return codes"
echo "______________________________________________________"

cat $logFile | awk '{ retcodcount[$9]++ } END { for (i in retcodcount) { printf "Return code %13s - %d times/n", i, retcodcount[i] } }' | sort -rn 
