#!/bin/bash

export LC_ALL=C
export LANG=C

#---------------------------------
# BASH utilities for IP addresses.
#---------------------------------

# converts IPv4 as "A.B.C.D" to integer
ip4_to_int () {
  IFS=. read -r i j k l <<EOF
$1
EOF
  echo $(( (i << 24) + (j << 16) + (k << 8) + l ))
}

# converts interger to IPv4 as "A.B.C.D"
int_to_ip4 () {
  echo "$(( ($1 >> 24) % 256 )).$(( ($1 >> 16) % 256 )).$(( ($1 >> 8) % 256 )).$(( $1 % 256 ))"
}

# returns the ip part of an CIDR
cidr_ip () {
  IFS=/ read -r ip _ <<EOF
$1
EOF
  echo "$ip"
}

# returns the prefix part of an CIDR
cidr_prefix () {
  IFS=/ read -r _ prefix <<EOF
$1
EOF
  echo "$prefix"
}

# returns net mask in numberic from prefix size
netmask_of_prefix () {
  echo $((4294967295 ^ (1 << (32 - $1)) - 1))
}

# returns default gateway address (network address + 1) from CIDR
cidr_default_gw () {
  local ip
  local prefix
  local netmask
  local gw
  ip=$(ip4_to_int "$(cidr_ip "$1")")
  prefix=$(cidr_prefix "$1")
  netmask=$(netmask_of_prefix "$prefix")
  gw=$((ip & netmask + 1))
  int_to_ip4 $gw
}

# returns default gateway address (broadcast address - 1) from CIDR
cidr_default_gw_2 () {
  local ip
  local prefix
  local netmask
  local broadcast
  ip=$(ip4_to_int "$(cidr_ip "$1")")
  prefix=$(cidr_prefix "$1")
  netmask=$(netmask_of_prefix "$prefix")
  broadcast=$(((4294967295 - netmask) | ip))
  int_to_ip4 $((broadcast - 1))
}

in-addr_arpa () {
  local ans=0
  local cir
  local fst
  cir=$(cidr_prefix "$1")
  fst=$(cidr_default_gw "$1")
  if [ "$cir" -ge 1 ] && [ "$cir" -lt 8 ]; then
    ans=0
  elif [ "$cir" -ge 8 ] && [ "$cir" -lt 16 ]; then
    ans=$(echo "$fst" | awk -F'[.]' '{printf "%s",$1}')
  elif [ "$cir" -ge 16 ] && [ "$cir" -lt 24 ]; then
    ans=$(echo "$fst" | awk -F'[.]' '{printf "%s.%s",$2,$1}')
  elif [ "$cir" -ge 24 ] && [ "$cir" -lt 32 ]; then
    ans=$(echo "$fst" | awk -F'[.]' '{printf "%s.%s.%s",$3,$2,$1}')
  else
    ans=0
  fi
  echo $ans
}

iplist () {
  local num
  local max
  num=$(ip4_to_int "$(cidr_ip "$1")")
  max=$(("$num" + $2 - 1))

  while :
  do
    int_to_ip4 "$num"
    [[ "$num" == "$max" ]] && break || num=$(("$num"+1))
  done
  echo ""
}

ipmax() {
  local max
  max=$(iplist "$1" "$2" | tr '\n' ' ' | awk '{print $NF}')
  echo "$max"
}

cidr_netmask () {
  local ip
  local prefix
  local netmask
  local gw
  ip=$(ip4_to_int "$(cidr_ip "$1")")
  prefix=$(cidr_prefix "$1")
  netmask=$(netmask_of_prefix "$prefix")
  gw=$((ip & netmask))
  local cidr
  cidr=$(int_to_ip4 $gw)
  echo "$cidr"/"$prefix"
}