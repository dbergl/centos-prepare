#!/bin/bash

# make sure curl and wget are available
sudo yum -y install curl wget

# install epel and ius repos
curl -L 'https://setup.ius.io/' | sudo bash

# grab latest package updates
sudo yum -y update

# remove mariadb 5.5 libs since they will conflict
sudo yum -y remove mariadb-libs

# install apache, php, redis, mysql-client, etc...
sudo yum -y install vim-enhanced httpd redis30u mod_php70u php70u-cli \
   php70u-devel php70u-gd php70u-json php70u-mbstring php70u-mysqlnd \
   php70u-opcache php70u-pdo php70u-pear php70u-pecl-apcu php70u-process \
   php70u-soap php70u-xml git2u mariadb101u-devel mariadb101u-libs \
   mariadb101u libsphinxclient libsphinxclient-devel gcc unixODBC postfix \
   policycoreutils-python

wget --content-disposition http://sphinxsearch.com/files/sphinx-2.2.10-1.rhel7.x86_64.rpm

sudo yum -y install sphinx-2.2.10-1.rhel7.x86_64.rpm

# enable httpd to talk to other services
# need to add redis_port_t and sphinx_port_t
#   mysqld_port_t: sudo setsebool -P httpd_can_network_connect_db 1
# for now use httpd_can_network_connect
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_execmem 1
sudo setsebool -P httpd_can_sendmail 1
sudo setsebool -P daemons_enable_cluster_mode 1

# install php redis module
git clone https://github.com/phpredis/phpredis.git
cd phpredis
git checkout php7
phpize
./configure --with-php-config=`which php-config`
make
sudo make install
echo "extension=redis.so" | sudo tee /etc/php.d/40-redis.ini
git clean -f -d
cd ..
rm -rf phpredis

# install php sphinx module
git clone https://git.php.net/repository/pecl/search_engine/sphinx.git
cd sphinx
git checkout php7
phpize
./configure --with-php-config=`which php-config`
make
sudo make install
echo "extension=sphinx.so" | sudo tee /etc/php.d/40-sphinx.ini
git clean -f -d
cd ..
rm -rf sphinx

# enable and start services
sudo mkdir -p /etc/systemd/system/httpd.service.d
echo "
[Service]
PrivateTmp=false
" | sudo tee /etc/systemd/system/httpd.service.d/nopt.conf
sudo systemctl daemon-reload
sudo systemctl enable httpd
sudo systemctl start httpd

# speed up ssh
sudo sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sudo systemctl restart sshd

# redis.conf
sudo sed -i 's/^bind/# bind/g' /etc/redis.conf
sudo sed -i 's/^# unixsocket/unixsocket/g' /etc/redis.conf

# set up redis policy to write /tmp/redis.sock
echo "

module redis-socket 1.0;

require {
        type tmp_t;
        type redis_t;
        class dir { write add_name remove_name };
        class sock_file { create setattr unlink };
}

#============= redis_t ==============
allow redis_t tmp_t:dir { write add_name remove_name };
allow redis_t tmp_t:sock_file { create setattr unlink };
" > redis-socket.te
checkmodule -M -m -o redis-socket.mod redis-socket.te
semodule_package -m redis-socket.mod -o redis-socket.pp
sudo semodule -i redis-socket.pp

# enable and start redis
sudo systemctl enable redis
sudo systemctl start redis

# enable httpd to talk to sphinx.sock
echo "

module httpd-sphinx 1.0;

require {
   type var_run_t;
   type httpd_t;
   type initrc_t;
   class sock_file write;
   class unix_stream_socket connectto;
}

#============= httpd_t ==============
allow httpd_t var_run_t:sock_file write;
allow httpd_t initrc_t:unix_stream_socket connectto;
" > httpd-sphinx.te
checkmodule -M -m -o httpd-sphinx.mod httpd-sphinx.te
semodule_package -m httpd-sphinx.mod -o httpd-sphinx.pp
sudo semodule -i httpd-sphinx.pp

# enable httpd to talk to redis.sock
echo "

module httpd-redis-sock 1.0;

require {
   type httpd_t;
   type tmp_t;
   class sock_file write;
}

#============= httpd_t ==============
allow httpd_t tmp_t:sock_file write;
" > httpd-redis-sock.te
checkmodule -M -m -o httpd-redis-sock.mod httpd-redis-sock.te
semodule_package -m httpd-redis-sock.mod -o httpd-redis-sock.pp
sudo semodule -i httpd-redis-sock.pp

# install HTMLPurifer with support for PHP7
sudo pear install channel://pear.php.net/XML_Serializer-0.20.2
sudo pear install PEAR_PackageFileManager_Plugins
sudo pear install PEAR_PackageFileManager2

pear channel-discover htmlpurifier.org
git clone https://github.com/ezyang/htmlpurifier.git
cd htmlpurifier
sed -i "s/setPhpDep('5.0.0')/setPhpDep('7.0.0')/g" package.php
sed -i "s/setPearinstallerDep('1.4.3')/setPearinstallerDep('1.10.1')/g" package.php
echo '4.8.0' > VERSION
php package.php
pear package library/package.xml
sudo pear install HTMLPurifier-4.8.0.tgz
cd ..
rm -rf htmlpurifier

sudo chmod 777 /usr/share/pear/HTMLPurifier/DefinitionCache/Serializer
sudo chcon -R --reference=/usr/share/pear /usr/share/pear/HTMLPurifier

sudo pear uninstall PEAR_PackageFileManager2
sudo pear uninstall PEAR_PackageFileManager_Plugins
sudo pear uninstall XML_Serializer
sudo pear uninstall XML_Parser
