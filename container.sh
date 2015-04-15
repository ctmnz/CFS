#!/bin/sh

## SET UP HERE
container_name="containername"
container_root_password="containerpass"
container_mysql_password="mysqlpassword"

### END ####

############################################################################

container_dir="$('pwd')/$container_name"

## make project dir

mkdir -p $container_dir/var/lib/rpm

#### Rebuild rpm db

rpm --rebuilddb --root=$container_dir/var/lib/rpm

## centos-release

yumdownloader --destdir=$container_dir/var/lib/rpm centos-release

## Install the script

rpm -ivh --root=$container_dir --nodeps $container_dir/var/lib/rpm/centos-release*.rpm

## Install rpm-build and yum

yum --installroot=$container_dir install -y rpm-build yum

## Install httpd (testing)

yum --installroot=$container_dir install -y passwd bash centos-release vim

yum --installroot=$container_dir groupinstall -y "Minimal Install"
yum --installroot=$container_dir install -y php php-mysql php-pecl-memcached mariadb mariadb-server
yum --installroot=$container_dir install -y memcached httpd mysql mysql-server 
yum --installroot=$container_dir clean all
## copyfiles from host to container

mkdir -p $container_dir/FilesFromHost/
cp -r files $container_dir/FilesFromHost/

## Set root password
echo root:$container_root_password | chroot $container_dir chpasswd


# Enable services

chroot $container_dir systemctl enable httpd
chroot $container_dir systemctl enable mariadb
chroot $container_dir systemctl enable memcached

### Make it as service

cat > /etc/systemd/system/$container_name\.service <<EOF 
[Unit]
Description=Automatic generated container $container_name

[Service]
ExecStart=/usr/bin/systemd-nspawn -bD $container_dir
KillMode=process
EOF

#### MYSQL
## Optional set mysql root pass
if [ -z "$container_mysql_password" ]
then
	echo "mysql root password not set. skipping...."
else
	echo "Seting new mysql root password....."
	tempSqlFile=${container_dir}/tmp/mysql-first-time.sql
	cat > "$tempSqlFile" <<-EOSQL
		-- What's done in this file shouldn't be replicated
		--  or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0;
		
		DELETE FROM mysql.user ;
		CREATE USER 'root'@'%' IDENTIFIED BY '${container_mysql_password}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
		FLUSH PRIVILEGES;
	EOSQL
fi




## Start the service

systemctl daemon-reload
systemctl start $container_name



