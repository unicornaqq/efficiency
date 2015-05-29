#!/bin/sh
#08:44:03 root@OB-S2007-spa spa:~> uemcli -sslPolicy accept -noHeader -u admin -p Password123! -d 10.62.34.250 /net/if show
#example:
#1:    ID               = if_47
#      Type             = iscsi
#      NAS server       = 
#      Port             = spa_eth4
#      VLAN ID          = 7
#      IP address       = 2620:0:170:1d78:1a4:bad:beef:9/64
#      Subnet mask      = 
#      Gateway          = 2620:0:170:1d78::1
#      IPv4 mode        = 
#      IPv4 address     = 
#      IPv4 subnet mask = 
#      IPv4 gateway     = 
#      IPv6 mode        = 
#      IPv6 address     = 2620:0:170:1d78:1a4:bad:beef:9/64
#      IPv6 gateway     = 2620:0:170:1d78::1
#      SP               = spa
#      Preferred        =

uemcli -sslPolicy accept -noHeader -u admin -p Password123! -d 10.62.34.250 /net/if show | grep -v "VLAN ID" | grep ID > ~/ip_temp.txt
while read id_info; do
info_array=( $id_info )
id=${info_array[3]}
uemcli -sslPolicy accept -noHeader -u admin -p Password123! -d 10.62.34.250 /net/if -id $id delete
done<~/ip_temp.txt
rm -fr ~/ip_temp.txt

