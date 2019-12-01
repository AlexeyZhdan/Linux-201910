#!/bin/bash

#yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc
wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.16.1-1.el7.ngx.src.rpm --directory-prefix=/root/
rpm -i /root/nginx-1.16.1-1.el7.ngx.src.rpm --prefix=/root/
wget https://www.openssl.org/source/latest.tar.gz --directory-prefix=/root/
tar -xvf /root/latest.tar.gz --directory=/root/
yum-builddep -y /root/rpmbuild/SPECS/nginx.spec
cp --remove-destination /files/nginx.spec /root/rpmbuild/SPECS/
rpmbuild -bb /root/rpmbuild/SPECS/nginx.spec
yum localinstall -y /root/rpmbuild/RPMS/x86_64/nginx-1.16.1-1.el7.ngx.x86_64.rpm
systemctl start nginx
systemctl enable nginx
