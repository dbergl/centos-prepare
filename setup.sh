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

sudo setsebool -P httpd_can_network_connect_db 1
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
sudo systemctl enable httpd
sudo systemctl start httpd

# speed up ssh
sudo sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sudo systemctl restart sshd

# redis.conf
sudo sed -i 's/^bind/# bind/g' /etc/redis.conf
sudo sed -i 's/^# unixsocket/unixsocket/g' /etc/redis.conf
sudo sed -i 's|/tmp/redis.sock|/var/run/redis/redis.sock|g' /etc/redis.conf
sudo sed -i s'/unixsocketperm 700/unixsocketperm 777/g' /etc/redis.conf

# enable and start redis
sudo systemctl enable redis
sudo systemctl start redis

# enable httpd to talk to sphinx
echo "

module httpd-sphinx 1.0;

require {
    attribute port_type;
    attribute defined_port_type;
    attribute unreserved_port_type;
    type httpd_t;
    type var_run_t;
    type initrc_t;
    class sock_file write;
    class unix_stream_socket connectto;
    class tcp_socket name_connect;
}

type sphinx_port_t, port_type, defined_port_type;
typeattribute sphinx_port_t unreserved_port_type;

#============== httpd_t ==============
allow httpd_t var_run_t:sock_file write;
allow httpd_t initrc_t:unix_stream_socket connectto;
allow httpd_t sphinx_port_t:tcp_socket name_connect;
" > httpd-sphinx.te
checkmodule -M -m -o httpd-sphinx.mod httpd-sphinx.te
semodule_package -m httpd-sphinx.mod -o httpd-sphinx.pp
sudo semodule -i httpd-sphinx.pp
sudo semanage port -a -t sphinx_port_t -p tcp 3312

# enable httpd to talk to redis
echo "
module httpd-redis 1.0;

require {
    type redis_port_t;
	type httpd_t;
	type redis_var_run_t;
	class sock_file write;
    class tcp_socket name_connect;
}

#============= httpd_t ==============
allow httpd_t redis_var_run_t:sock_file write;
allow httpd_t redis_port_t:tcp_socket name_connect;
" > httpd-redis.te
checkmodule -M -m -o httpd-redis.mod httpd-redis.te
semodule_package -m httpd-redis.mod -o httpd-redis.pp
sudo semodule -i httpd-redis.pp

# install HTMLPurifer with support for PHP7
sudo pear install channel://pear.php.net/XML_Serializer-0.20.2
sudo pear install PEAR_PackageFileManager_Plugins
sudo pear install PEAR_PackageFileManager2

sudo pear channel-discover htmlpurifier.org
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
