#!/bin/bash
# Wordpress Automatic Install Script for NiftyCloud(CentOS 6.2 64bit Plain)
# 2012/04/03 @ysaotome

#===============================================
# Wordpress Settings
#===============================================
##MySQL管理ユーザのパスワード
MYSQL_ROOT_PASS='mysql##123'
##Wordpressデータベース名
WP_MYSQL_DB_NAME='wordpress'
##WordpressDB管理ユーザ名
WP_MYSQL_ADMIN_NAME='wpsql'
##WordpressDB管理ユーザのパスワード
WP_MYSQL_ADMIN_PASS='wpsql##123'
##WordpressBLOGタイトル
WP_BLOG_TITLE='にふくら　で　わーどぷれす'
##WordpressBLOG管理ユーザ名
WP_BLOG_ADMIN_NAME='wpadmin'
##WordpressBLOG管理ユーザのパスワード
WP_BLOG_ADMIN_PASSWORD='wpadmin##123'
##WordpressBLOG管理ユーザのメールアドレス
WP_BLOG_ADMIN_MAIL='wp@wphoge.jp'
#===============================================

## 環境変数
HOST_ARC=$(/bin/uname -m)
HOST_NAME=$(/usr/sbin/vmtoolsd --cmd 'info-get guestinfo.hostname')
HOST_IPADDR=$(ip addr show eth0 2>/dev/null | grep 'inet ' | sed -e 's/.*inet \([^ ]*\)\/.*/\1/')

## Apache,MySQL,PHP5.3.x,postfixをインストール
/usr/bin/yum -y --enablerepo=remi-test,remi,epel,dag install httpd.${HOST_ARC} mysql.${HOST_ARC} mysql-server.${HOST_ARC} php.${HOST_ARC} php-mbstring.${HOST_ARC} php-mysql.${HOST_ARC} postfix.${HOST_ARC}

## Apacheの設定
/bin/rm -rf /etc/httpd/conf.d/welcome.conf
/bin/rm -rf /var/www/error/noindex.html
/bin/sed -i.org -e 's/Options Indexes FollowSymLinks/Options FollowSymLinks/' /etc/httpd/conf/httpd.conf
/bin/sed -i 's/ServerTokens OS/ServerTokens ProductOnly/' /etc/httpd/conf/httpd.conf
/bin/sed -i 's/ServerSignature On/ServerSignature Off/' /etc/httpd/conf/httpd.conf
/etc/init.d/httpd start
/sbin/chkconfig httpd on

## MySQLの設定
/etc/init.d/mysqld start 
/sbin/chkconfig mysqld on
/usr/bin/mysqladmin -u root password ${MYSQL_ROOT_PASS}
/usr/bin/mysql -u root -p${MYSQL_ROOT_PASS} -e "DROP DATABASE test; DELETE FROM mysql.user WHERE user=''; DELETE FROM mysql.user WHERE host='"${HOST_NAME}"';"

## PHPの設定
/bin/sed -i.org -e "s/;date.timezone =/date.timezone = Asia\/Tokyo/g" /etc/php.ini

## postfixの設定
/usr/sbin/alternatives --set mta /usr/sbin/sendmail.postfix 
/bin/cp -p /etc/postfix/main.cf /etc/postfix/main.cf.org
/bin/cat << _PF_CONFIG_ >> /etc/postfix/main.cf
mynetworks = 127.0.0.1
inet_interfaces = localhost
alias_maps = hash:/etc/aliases
mynetworks_style = host
_PF_CONFIG_
/bin/echo 'root:'${WP_BLOG_ADMIN_MAIL} >> /etc/aliases 
/usr/bin/newaliases
/etc/init.d/postfix start
/sbin/chkconfig --add postfix
/sbin/chkconfig postfix on

## Wordpressセットアップ
### Wordpressのパッケージ取得と展開
/usr/bin/wget -P /var/www/html/ 'http://ja.wordpress.org/latest-ja.tar.gz'
/bin/tar zxf /var/www/html/latest-ja.tar.gz -C /var/www/html/
/bin/rm -f  /var/www/html/latest-ja.tar.gz
/bin/chown -R apache:apache /var/www/html/wordpress/
### WordpressのDB作成と権限設定
/usr/bin/mysql -u root -p${MYSQL_ROOT_PASS} -e "CREATE DATABASE "${WP_MYSQL_DB_NAME}" DEFAULT CHARACTER SET utf8;"
/usr/bin/mysql -u root -p${MYSQL_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON "${WP_MYSQL_DB_NAME}".* TO '"${WP_MYSQL_ADMIN_NAME}"'@'localhost' IDENTIFIED BY '"${WP_MYSQL_ADMIN_PASS}"';"
/usr/bin/mysql -u root -p${MYSQL_ROOT_PASS} -e "FLUSH PRIVILEGES;"
### wp-config.phpファイルの作成(3.3時点)
/bin/cat << _WP_CONFIG_1_ >> /var/www/html/wordpress/wp-config.php
<?php
define('DB_NAME', '${WP_MYSQL_DB_NAME}');
define('DB_USER', '${WP_MYSQL_ADMIN_NAME}');
define('DB_PASSWORD', '${WP_MYSQL_ADMIN_PASS}');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', 'utf8_general_ci');
_WP_CONFIG_1_
/usr/bin/wget -O wp_salt.txt 'https://api.wordpress.org/secret-key/1.1/salt/'
/bin/cat wp_salt.txt >> /var/www/html/wordpress/wp-config.php
/bin/rm -f wp_salt.txt
/bin/cat << _WP_CONFIG_2_ >> /var/www/html/wordpress/wp-config.php
\$table_prefix  = 'wp_';
define('WPLANG', 'ja');
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
_WP_CONFIG_2_
/bin/chown apache:apache /var/www/html/wordpress/wp-config.php
### wordpressの初期設定
/usr/bin/wget -O /tmp/wp_install_result.txt --post-data 'weblog_title='${WP_BLOG_TITLE}'&user_name='${WP_BLOG_ADMIN_NAME}'&admin_password='${WP_BLOG_ADMIN_PASSWORD}'&admin_password2='${WP_BLOG_ADMIN_PASSWORD}'&admin_email='${WP_BLOG_ADMIN_MAIL} 'http://'${HOST_IPADDR}'/wordpress/wp-admin/install.php?step=2'
#/bin/cat /tmp/wp_install_result.txt
#/bin/rm -f /tmp/wp_install_result.txt

/bin/echo 'Wordpress Install Completed!(･_･)b'
