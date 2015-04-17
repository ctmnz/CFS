#!/bin/sh

## SET UP HERE
container_name="containername"
container_root_password="containerpass"
container_mysql_password="mysqlpassword"
container_sshd_port="23"


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
yum --installroot=$container_dir install -y openssh-server
yum --installroot=$container_dir install -y php php-mysql php-pecl-memcached mariadb mariadb-server phpMyAdmin
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
#	sleep 5
#	chroot $container_dir mysql --execute="source /tmp/mysql-first-time.sql"
fi


######### SSHD


if [ -z "$container_sshd_port" ]
then 
	echo  "No ssh port enabled. skipping...."
else
	echo  "Setting up ssh for the container..."

	## on the host

	cat > /etc/systemd/system/$container_name\.socket <<HostEOF 
	[Unit]
	Description=The SSH socket for : ${container_name}

	[Socket]
	ListenStream=${container_sshd_port}
HostEOF



	## on the container
	sshSocketFile=${container_dir}/etc/systemd/system/sshd.socket
	cat > "$sshSocketFile" <<-EOSSHDsock
		[Unit]
		Description=SSH Socket for Per-Connection Servers

		[Socket]
		ListenStream=${container_sshd_port}
		Accept=yes
EOSSHDsock
	sshServiceFile=${container_dir}/etc/systemd/system/sshd@.service
	cat > "$sshServiceFile" <<-EOSSHDservice
		[Unit]
		Description=SSH Per-Connection Server for %I

		[Service]
		ExecStart=-/usr/sbin/sshd -i
		StandardInput=socket
EOSSHDservice

	## start sshd 
	chroot $container_dir ln -s /etc/systemd/system/sshd.socket /etc/systemd/system/sockets.target.wants/

fi






############



## Start the service

systemctl daemon-reload
systemctl enable $container_name
#systemctl start $container_name




