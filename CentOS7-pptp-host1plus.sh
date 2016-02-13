#!/bin/bash
#    Setup Simple PPTP VPN server for CentOS 7 on Host1plus
#    Copyright (C) 2015-2016 Danyl Zhang <1475811550@qq.com> and contributors
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

printhelp() {

echo "
Usage: ./CentOS7-pptp-host1plus.sh [OPTION]
If you are using custom password , Make sure its more than 8 characters. Otherwise it will generate random password for you. 
If you trying set password only. It will generate Default user with Random password. 
example: ./CentOS7-pptp-host1plus.sh -u myusr -p mypass
Use without parameter [ ./CentOS7-pptp-host1plus.sh ] to use default username and Random password
  -u,    --username             Enter the Username
  -p,    --password             Enter the Password
"
}

while [ "$1" != "" ]; do
  case "$1" in
    -u    | --username )             NAME=$2; shift 2 ;;
    -p    | --password )             PASS=$2; shift 2 ;;
    -h    | --help )            echo "$(printhelp)"; exit; shift; break ;;
  esac
done

# Check if user is root
[ $(id -u) != "0" ] && { echo -e "\033[31mError: You must be root to run this script\033[0m"; exit 1; } 

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear

[ ! -e '/usr/bin/curl' ] && yum -y install curl

VPN_IP=`curl ipv4.icanhazip.com`

VPN_LOCAL="192.168.0.150"
VPN_REMOTE="192.168.0.151-200"
clear

yum -y install epel-release firewalld
yum -y install ppp pptpd

echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

[ -z "`grep '^localip' /etc/pptpd.conf`" ] && echo "localip $VPN_LOCAL" >> /etc/pptpd.conf # Local IP address of your VPN server
[ -z "`grep '^remoteip' /etc/pptpd.conf`" ] && echo "remoteip $VPN_REMOTE" >> /etc/pptpd.conf # Scope for your home network

if [ -z "`grep '^ms-dns' /etc/ppp/options.pptpd`" ];then
	echo "ms-dns 8.8.8.8" >> /etc/ppp/options.pptpd # Google DNS Primary
	echo "ms-dns 209.244.0.3" >> /etc/ppp/options.pptpd # Level3 Primary
	echo "ms-dns 208.67.222.222" >> /etc/ppp/options.pptpd # OpenDNS Primary
fi

#no liI10oO chars in password

LEN=$(echo ${#PASS})

if [ -z "$PASS" ] || [ $LEN -lt 8 ] || [ -z "$NAME"]
then
   P1=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P2=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P3=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   PASS="$P1-$P2-$P3"
fi

if [ -z "$NAME" ]
then
   NAME="vpn"
fi

cat >> /etc/ppp/chap-secrets <<END
$NAME pptpd $PASS *
END

ETH=`route | grep default | awk '{print $NF}'`
systemctl start firewalld
firewall-cmd --add-port=22/tcp --permanent
firewall-cmd --add-port=1723/tcp --permanent
firewall-cmd --add-masquerade --permanent
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -i $ETH -p gre -j ACCEPT
firewall-cmd --reload

echo 'systemctl start pptpd' >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
systemctl start pptpd
chkconfig pptpd on
clear

echo -e "You can now connect to your VPN via your external IP \033[32m${VPN_IP}\033[0m"

echo -e "Username: \033[32m${NAME}\033[0m"
echo -e "Password: \033[32m${PASS}\033[0m"