#!/bin/bash
## AUTHOR : bricheux AT casptech DOT com
## V0

ARGS='rugtosmt rubyops addpkgs sp3step check10 update10 bootstrap zyppertosmt check11 update11 help'
SMTIP='10.2.2.53'
SMTHOST='mysmt'
DOMAIN='mine.lan'

# Care for "##specific to a certain customer" markers, indicating calls that may not work or need adaptation

function kitkat()
{
	echo "!! STOP RIGHT HERE, something manual feels required"
	exit 0
}

function stepjustended()
{
	echo "############"
	echo "# STEP-END #"
	echo "############"
}

function suggest()
{
	echo "# Just a suggestion : $@"
}

function givemeanswers()
{
	wget -q http://$SMTIP/auto/answer -O /opt/novell/oes-install/answer
}

function check10
{
	rug ref
	rug sl
	rug ca
	rug pd -i
}

function check11()
{
	zypper ref -s
	zypper sl
	zypper lr
	zypper se -t product
}

function update10
{
	givemeanswers
	df -h /var/cache/zmd
	read -p "Proceed ? (only 'yes' accepted or will exit) " prcd
	if [ ! $prcd == "yes" ]; then echo "Exiting now..." && exit ; fi
	suggest "Time to get out of cluster?"
	rug ref
	rug up -t patch -g recommended && rug ping -a
}

function rubyops()
{
	echo "# Downloading ruby patch 369..."
	cd /tmp
	wget http://$SMTIP/auto/rpms/ruby-devel-1.8.6.p369-0.4.x86_64.rpm -O /tmp/ruby-369.rpm
	wget http://$SMTIP/auto/rpms/ruby-1.8.6.p369-0.4.x86_64.rpm -O /tmp/ruby-devel-369.rpm
	#rpm -Uvh ruby-devel-1.8.6.p369-0.4.x86_64.rpm ruby-1.8.6.p369-0.4.x86_64.rpm
	rpm -Uvh /tmp/ruby*369*rpm
	if [ $? -eq 0 ]; then rm /tmp/ruby*369*rpm ; fi
}

function grubcheatsheet()
{
	echo "title Boot – OES11SP2 UPGRADE INSTALL"
	echo "root (hd0,0)"
	echo "kernel /vmlinuz-oes112-install usessh=1 sshpassword=upgrade11 hostip=10.2.2.XXX netmask=255.255.0.0 gateway=10.2.1.254 nameserver=10.2.2.89 vnc=1 vncpassword=upgrade11 install=http://$SMTIP/bootstrap/OES11SP2-full"
	echo "initrd /initrd-oes112-install"
	suggest "Don't forget to change IP address from 'XXX'"
}

function zyppertosmt()
{
	echo "# Cleaning previous sources"
	zypper sl | grep 1 > /dev/null
	srcnb=$?
	while [ srcnb -eq 0 ]
	do
		zypper sd 1 && echo "1 done..."
		zypper sl | grep 1 > /dev/null
		srcnb=$?
	done
	cd /tmp
	wget -q http://$SMTIP/repo/tools/clientSetup4SMT.sh -0 /tmp/clientSetup4SMT.sh
	grep $SMTHOST /etc/hosts || echo "$SMTIP $SMTHOST $SMTHOST.$DOMAIN" >> /etc/hosts
	sh clientSetup4SMT.sh --host $SMTHOST.$DOMAIN
	zypper sl
	suse_register --restore-repos
	check11
	suggest "update11 time?"
}

function update11()
{
	zypper ref -s
	zypper up -t patch
}

function rugtosmt()
{
	echo "# Cleaning previous sources"
	rug sl | grep 1 > /dev/null
	srcnb=$?
	while [ srcnb -eq 0 ]
	do
		rug sd 1 && echo "1 done..."
		rug sl | grep 1 > /dev/null
		srcnb=$?
	done

	echo "# Proceeding with install sources"
	yast inst_source

	echo "# Cleaning caches and secrets..."
	rczmd stop
	rm -rf /var/cache/zmd/*
	rm /var/lib/zmd/zmd.db
	rm /etc/zmd/deviceid
	rm /etc/zmd/secret
	rczmd start
	rm /var/cache/SuseRegister/lastzmdconfig.cache

	echo "# Registering to new SMT server"
	cd /tmp
	wget -q http://$SMTIP/repo/tools/clientSetup4SMT.sh -0 /tmp/clientSetup4SMT.sh
	grep $SMTHOST /etc/hosts || echo "$SMTIP $SMTHOST $SMTHOST.$DOMAIN" >> /etc/hosts
	sh clientSetup4SMT.sh --host $SMTHOST.$DOMAIN

	rug sl
	rug ca
	suggest "Check that nothing's missing in catalogs and proceed?"
	suggest "yast disk time!"
	suggest "Time to get out of cluster?"
	kitkat
}

function addpkgs()
{
	echo "# Mounting OES2 source"
	mkdir /mnt/iso 2> /dev/null ; mount -t iso9660 -o loop $(find /sources -name 'OES2*SP2*.iso') /mnt/iso ##specific to a certain customer
	rpm -Uvh $(find /mnt/iso/ | grep -E "fuse")
	rpm -Uvh $(find /mnt/iso/ | grep -E "ruby-1.*20")
	rpm -Uvh $(find /mnt/iso/ | grep -E "glibc-dceext-2.*")
	umount /mnt/iso && echo "# OES2 source unmounted"
}

function sp3step()
{
	givemeanswers
	rpm -qa | grep -E "ruby.+p369" > /dev/null 2>&1 ; if [ ! $? == 0 ]; then rubyops; fi
	sed -ri 's/adm_cl[a-z]+,/admin,/' /etc/sysconfig/novell/*[^s] ##specific to a certain customer
	rug ref
	rug in -t patch move-to-oes2-sp3 && rug ping –a
	rug up -t patch -g recommended && rug ping –a
	suggest "Time to use the NTP cheat  (press any key to proceed after copying the line) : /etc/init.d/ntp start ; /etc/init.d/ntp status || ( sleep 30 && /etc/init.d/ntp start )"
	vim /etc/init.d/firstboot
	chkconfig xdm off
	read -p "Proceed with REBOOT? (only 'yes' accepted or will exit) " prcd
	if [ ! $prcd == "yes" ]; then echo "Exiting now..." ; exit ; fi
	reboot & exit
}

function bootstrap()
{
	cd /boot/
	wget http://$SMTIP/auto/vmlinuz-oes112-install
	wget http://$SMTIP/auto/initrd-oes112-install
	grubcheatsheet ; vim grub/menu.lst ##specific to a certain customer
	read -p "Proceed with REBOOT? (only 'yes' accepted or will exit) " prcd
	if [ ! $prcd == "yes" ]; then echo "Exiting now..." ; exit ; fi
	reboot & exit
}

function help()
{
	echo "Usage is (stepped) :"
	i=1
	for a in $ARGS;
	do
		echo "$i. $a"
		((i++))
	done
}

function main()
{
	for a in $ARGS;
	do
		if [ ! -z $1 ] && [ $1 == $a ];
		then
			eval $a ; stepjustended
			exit 0
		fi
	done
	echo "No usable operation provided."
	help

}

main $1
