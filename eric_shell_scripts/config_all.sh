#!/bin/sh
x=0
while [ $x -lt 8 ]; do
ip_addr=$((x+2))
echo "the ip_addr is $ip_addr"
if [ $x == 0 ]; then
	uemcli -sslPolicy accept -noHeader -u admin -p Password123! -d 10.62.34.250 /net/if create -type iscsi -port spa_eth4 -ipv4 static -addr 192.168.110."$ip_addr" -netmask 255.255.255.0 -gateway 192.168.110.1
	sleep 5
	uemcli -sslPolicy accept -noHeader -u admin -p Password123! -d 10.62.34.250 /net/if create -type iscsi -port spa_eth4 -ipv6 static -addr 2620:0:170:1d78:1a4:bad:beef:"$ip_addr"/64 -gateway 2620:0:170:1d78::1
	sleep 5
else
	uemcli -sslPolicy accept -noHeader -u admin -p Password123! -d 10.62.34.250 /net/if create -type iscsi -port spa_eth4 -ipv4 static -addr 192.168.110."$ip_addr" -netmask 255.255.255.0 -gateway 192.168.110.1 -vlanId "$x"
        sleep 5
        uemcli -sslPolicy accept -noHeader -u admin -p Password123! -d 10.62.34.250 /net/if create -type iscsi -port spa_eth4 -ipv6 static -addr 2620:0:170:1d78:1a4:bad:beef:"$ip_addr"/64 -gateway 2620:0:170:1d78::1 -vlanId "$x"
        sleep 5
fi
let x=x+1
done
