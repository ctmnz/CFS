#!/bin/sh

container_name="nspawncontainer"

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

mkdir -p $container_dir/filesfromhost/
cp -r files $container_dir/filesfromhost/


## you should

echo "Write passwd, change root password and then exit !!"
chroot $container_dir
# passwd
# and change rootpassword


### Make it as service

cat > /etc/systemd/system/$container_name\.service <<EOF 
[Unit]
Description=Automatic generated container $container_name

[Service]
ExecStart=/usr/bin/systemd-nspawn -bD $container_dir
KillMode=process
EOF

systemctl daemon-reload
systemctl start $container_name



