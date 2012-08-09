#!/bin/bash
# Gitlab Automatic Install Script for NiftyCloud(CentOS 6.2 64bit Plain)
# 2012/04/04 @ysaotome

##パッケージのインストール
yum --enablerepo=remi-test,remi,epel,dag -y install apr-devel apr-util-devel byacc db4-devel gcc gcc-c++ gdbm-devel git glibc-devel libcurl-devel libicu-devel libxml2-devel libxslt libxslt-devel libyaml make mysql-devel ncurses-devel openssl-devel pcre-devel python-devel python-setuptools readline-devel redis sqlite-devel tcl-devel lib-devel libtool
/sbin/ldconfig

/sbin/chkconfig redis on 
/sbin/service redis start

##ユーザ作成
/usr/sbin/useradd -c 'git contrall user' -r -s /bin/zsh -d /home/git -m git
/usr/sbin/useradd -c 'gitlab system user' -r -s /bin/zsh -d /home/gitlab -m gitlab
/usr/sbin/usermod -a -G git gitlab

/usr/bin/sudo -u gitlab ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa
/bin/cp -pr /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
/bin/chown git:git /home/git/gitlab.pub
/bin/chmod 777 /home/git/gitlab.pub

##gitoliteインストール
cd /home/git
/usr/bin/sudo -u git /usr/bin/git clone git://github.com/gitlabhq/gitolite /home/git/gitolite
/usr/bin/sudo -u git -H /home/git/gitolite/src/gl-system-install
/usr/bin/sudo -u git echo 'PATH=/home/git/bin:$PATH' >> /home/git/.zshrc
/usr/bin/sudo -u git -H sed -i 's/0077/0007/g' /home/git/share/gitolite/conf/example.gitolite.rc
/usr/bin/sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; gl-setup -q /home/git/gitlab.pub"

##一時的にwheelを扱う
/usr/sbin/usermod -a -G wheel gitlab
/bin/cp -pr /etc/sudoers /etc/sudoers.org
echo '%wheel  ALL=(ALL)       NOPASSWD: ALL' >> /etc/sudoers

##gitlabインストール
/usr/bin/easy_install pip
/usr/bin/pip install pygments
/bin/su - gitlab
/bin/zsh -s stable < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)
source /home/gitlab/.zshrc
rvm install 1.9.3
rvm use 1.9.3 --default
gem update --system
gem install passenger
/usr/bin/git clone git://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab
/bin/cp config/gitlab.yml.example config/gitlab.yml
/bin/cp config/database.yml.sqlite config/database.yml
bundle install --without development test --deployment
bundle exec rake db:setup RAILS_ENV=production
bundle exec rake db:seed_fu RAILS_ENV=production

rvmsudo passenger-install-nginx-module --auto-download --auto --prefix=/home/gitlab/nginx

exit

##wheelを不許可にする
/bin/cp -pr /etc/sudoers.org /etc/sudoers
/usr/bin/gpasswd -d gitlab wheel

## nginxの設定
/bin/cp -pr /home/gitlab/nginx/conf/nginx.conf /home/gitlab/nginx/conf/nginx.conf.org
/bin/sed -i 's/#user  nobody;/user  gitlab;/' /home/gitlab/nginx/conf/nginx.conf
/bin/sed -i '40,50s/            root   html;/            root   \/home\/gitlab\/gitlab\/public;\n            passenger_enabled on;/' /home/gitlab/nginx/conf/nginx.conf

cd /etc/init.d
/usr/bin/wget -O nginx https://raw.github.com/gist/2293771/9aaeab881585ef6055888efbd8a96a0a7bac2b6b/nginx_initd_for_gitlab.sh
/bin/chmod +x nginx
/sbin/chkconfig nginx on 
/sbin/service nginx start

/bin/echo 'Gitlab Install Completed!(･_･)b'