#!/bin/bash

IF=$1
dns=""

_get_dns_from_dhcp_lease () {
  dns=$(awk 'BEGIN{
      while( (getline line < "maclist") > 0){
          mac[line]
      }
      RS="}"
      FS="\n"
  }
  /lease/{
      for(i=1;i<=NF;i++){
          gsub(";","",$i)
          if ($i ~ /interface/) {
              m=split($i, IP," ")
              interface=IP[2]
          }
          if( $i ~ /domain-name-servers/ ){
              m=split($i, hw," ")
              dns=hw[3]
          }
      }
      print interface" "dns
  } ' /var/lib/dhcp/dhclient.leases | grep "$IF" | tail -n 1 | cut -d" " -f 2)
}

get_dns_from_dhcp_lease () {
  _get_dns_from_dhcp_lease
  space_dns="${dns//,/' '}"
  echo dns-nameservers "$space_dns"
}