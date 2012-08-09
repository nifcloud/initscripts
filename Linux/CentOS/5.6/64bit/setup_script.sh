#!/bin/bash
# CentOS 5.6 64bit Plain setup script for NiftyCloud
# 2012/03/16 @ysaotome

#===============================================
# Settings
#===============================================
##rootのパスワード
ROOT_PASSWORD='hoge##123'
##追加する管理ユーザ名
USER_NAME='hoge'
##管理ユーザのパスワード
USER_PASSWORD='hoge##123'
#===============================================
ARC=$(/bin/uname -m)
SALT=$(/usr/bin/uuidgen| /usr/bin/tr -d '-')

## hostname変更
HOST_NAME=$(/usr/sbin/vmtoolsd --cmd 'info-get guestinfo.hostname')
/bin/hostname ${HOST_NAME}
/bin/sed -i.org -e 's/HOSTNAME=.*/HOSTNAME='${HOST_NAME}'/' /etc/sysconfig/network

## ROOTパスワード設定
/usr/sbin/usermod -p $(/usr/bin/perl -e 'print crypt(${ARGV[0]}, ${ARGV[1]})' ${ROOT_PASSWORD} ${SALT}) root

## 管理ユーザ追加と設定
/usr/sbin/useradd -G 100 -p $(/usr/bin/perl -e 'print crypt(${ARGV[0]}, ${ARGV[1]})' ${USER_PASSWORD} ${SALT}) -m ${USER_NAME}
/bin/mkdir -p -m 700 /home/${USER_NAME}/.ssh
/bin/cp /root/.ssh/authorized_keys /home/${USER_NAME}/.ssh/.
/bin/chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.ssh

## ssh経由でのROOTログイン禁止
/bin/sed -i.org -e 's/^PermitRootLogin .*/PermitRootLogin no/g' /etc/ssh/sshd_config

## 起動スクリプト書き換え
/bin/cp -p /etc/rc.d/rc.local{,.org}
/bin/cat << _EOF1_ >> /etc/rc.d/rc.local
/bin/sed -ie 's/exclude=/#exclude=/' /etc/yum.conf

## リポジトリ追加：RPMforge
/bin/rpm --import http://ftp.riken.jp/Linux/dag/RPM-GPG-KEY.dag.txt
/bin/rpm -ivh http://ftp.riken.jp/Linux/dag/redhat/el5/en/${ARC}/rpmforge/RPMS/rpmforge-release-0.5.2-2.el5.rf.${ARC}.rpm
/bin/sed -i.org -e "s/enabled.*=.*1/enabled=0/g" /etc/yum.repos.d/rpmforge.repo 

## リポジトリ追加：EPEL
/bin/rpm --import http://ftp.riken.jp/Linux/fedora/epel/RPM-GPG-KEY-EPEL
/bin/rpm -ivh http://ftp.riken.jp/Linux/fedora/epel/5/${ARC}/epel-release-5-4.noarch.rpm
/bin/sed -i.org -e "s/enabled.*=.*1/enabled=0/g" /etc/yum.repos.d/epel.repo 

## リポジトリ追加：Remi
/bin/rpm --import http://rpms.famillecollet.com/RPM-GPG-KEY-remi
/bin/rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-5.rpm
/bin/sed -i.org -e "s/enabled.*=.*1/enabled=0/g" /etc/yum.repos.d/remi.repo 

## ツールセットアップ zsh,screen,ntp,sysstat,net-snmpをセットアップする
/usr/bin/yum --enablerepo=rpmforge,epel,remi -y install zsh.${ARC} screen.${ARC} ntp.${ARC} sysstat.${ARC} net-snmp.${ARC} java-1.6.0-openjdk.${ARC} git.${ARC}

## zshとscreenの設定ファイル取得
/usr/bin/wget --no-check-certificate -P /home/${USER_NAME}/ 'https://raw.github.com/gist/1336176/8ec9767aaaaec88cbe8c2b4a4092f16d7839c77b/.screenrc'
/usr/bin/wget --no-check-certificate -P /home/${USER_NAME}/ 'https://raw.github.com/gist/1336176/11ea1e2f7767d4f3e4a65d5422301a9cf4bf2ce5/.zshrc'
/bin/chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.screenrc /home/${USER_NAME}/.zshrc
/bin/ln -s /home/${USER_NAME}/.screenrc /root/
/bin/ln -s /home/${USER_NAME}/.zshrc /root/
/usr/sbin/usermod -s /bin/zsh root
/usr/sbin/usermod -s /bin/zsh ${USER_NAME}

## ntpdの設定ファイル
/usr/bin/vmware-toolbox-cmd timesync disable
/bin/sed -i.org -e "s/^server /#server /g" /etc/ntp.conf
/bin/cat << _NTPDCONF_ >> /etc/ntp.conf
server -4 ntp.nict.jp iburst
server -4 ntp.nict.jp iburst
server -4 ntp.nict.jp iburst
server -4 ntp1.jst.mfeed.ad.jp
server -4 ntp2.jst.mfeed.ad.jp
server -4 ntp3.jst.mfeed.ad.jp
_NTPDCONF_
/sbin/chkconfig ntpd on
/etc/init.d/ntpd start

## snmpdの設定ファイル
## by http://cloud.nifty.com/snmp/
/bin/cp -p /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.org
/bin/cat << _SNMPDCONF_ >>/etc/snmp/snmpd.conf
rocommunity niftycloud 10.100.0.14 .1.3.6.1.
rocommunity niftycloud 10.100.8.15 .1.3.6.1.
rocommunity niftycloud 10.100.16.13 .1.3.6.1.
rocommunity niftycloud 10.100.32.15 .1.3.6.1.
rocommunity niftycloud 202.248.175.141 .1.3.6.1.
rocommunity niftycloud 10.100.48.13 .1.3.6.1.
disk / 10000
_SNMPDCONF_
/sbin/chkconfig snmpd on
/etc/init.d/snmpd start

## NIFTY Cloud API Tools の設定
/usr/bin/wget -P /home/${USER_NAME}/ 'http://cloud.nifty.com/api/sdk/NIFTY_Cloud_api-tools.zip'
/usr/bin/unzip -d /home/${USER_NAME}/ /home/${USER_NAME}/NIFTY_Cloud_api-tools.zip
/bin/rm /home/${USER_NAME}/NIFTY_Cloud_api-tools.zip
/bin/chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/NIFTY_Cloud_api-tools/
/bin/chmod 755 /home/${USER_NAME}/NIFTY_Cloud_api-tools/bin/*

/bin/cat << '_EOF3_' > /home/${USER_NAME}/ncas.txt
## NIFTY Cloud API Settings
export NIFTY_CLOUD_HOME=/home/${USER_NAME}/NIFTY_Cloud_api-tools/
export PATH=\$PATH:\$NIFTY_CLOUD_HOME/bin
export JAVA_HOME=/usr/lib/jvm/jre

_EOF3_

/bin/cp -p /home/${USER_NAME}/.zshrc /home/${USER_NAME}/.zshrc_tmp
/bin/cat /home/${USER_NAME}/ncas.txt /home/${USER_NAME}/.zshrc_tmp > /home/hoge/.zshrc
/bin/rm -rf /home/${USER_NAME}/.zshrc_tmp /home/${USER_NAME}/ncas.txt

## yum update
/usr/bin/yum --enablerepo=rpmforge,epel,remi -y update

/bin/sed -ie 's/#exclude=/exclude=/' /etc/yum.conf

## yum update後のkernelにドライバ適用
/bin/cat << _EOF2_ >> /etc/rc.d/rc.local.new
#!/bin/sh
/usr/sbin/vmware-tools-upgrader -p "-d"
/bin/mv /etc/rc.d/rc.local.org /etc/rc.d/rc.local && /sbin/shutdown -r now
_EOF2_

/bin/chmod 755 /etc/rc.d/rc.local.new
/bin/mv /etc/rc.d/rc.local.new /etc/rc.d/rc.local && /sbin/shutdown -r now
_EOF1_

## 再起動
/bin/echo "Go Reboot!(･_･)b"
/sbin/shutdown -r now