#!/bin/bash

# make sure curl and wget are available
yum -y install curl wget

# install epel and ius repos
curl -L 'https://setup.ius.io/' | bash

# grab latest package updates
yum -y update

# remove mariadb 5.5 libs since they will conflict
yum -y remove mariadb-libs

# install apache, php, redis, mysql-client, etc...
sudo yum -y install vim-enhanced httpd redis30u mod_php70u php70u-cli \
   php70u-devel php70u-gd php70u-json php70u-mbstring php70u-mysqlnd \
   php70u-opcache php70u-pdo php70u-pear php70u-pecl-apcu php70u-process \
   php70u-soap php70u-xml git2u mariadb101u-devel mariadb101u-libs \
   mariadb101u libsphinxclient libsphinxclient-devel gcc sphinx postfix \
   policycoreutils-python

# enable httpd to talk to other services
setsebool httpd_can_network_connect on

# install php redis module
git clone https://github.com/phpredis/phpredis.git
cd phpredis
git checkout php7
phpize
./configure --with-php-config=`which php-config`
make
make install
echo "extension=redis.so" | tee /etc/php.d/40-redis.ini
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
make install
echo "extension=sphinx.so" | tee /etc/php.d/40-sphinx.ini
git clean -f -d
cd ..
rm -rf sphinx

# enable and start services
systemctl enable httpd
systemctl enable redis
systemctl start httpd
systemctl start redis

sudo -u apache tee /var/www/html/test_redis.php <<EOF
<?php

$redis = new Redis();

$is_connected = $redis->connect('127.0.0.1', 6379);

if (!$is_connected) {
   echo "Redis: connection failed.\n";
   exit(1);
} else {
   echo "Redis: connected!\n";
}
EOF
