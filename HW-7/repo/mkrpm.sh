#!/bin/bash

#yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc
wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.16.1-1.el7.ngx.src.rpm
rpm -i nginx-1.16.1-1.el7.ngx.src.rpm
wget https://www.openssl.org/source/latest.tar.gz
tar -xvf latest.tar.gz
yum-builddep rpmbuild/SPECS/nginx.spec
cp -f /files/nginx.spec /root/rpmbuild/SPECS/
rpmbuild -bb rpmbuild/SPECS/nginx.spec
yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.16.1-1.el7.ngx.x86_64.rpm
systemctl start nginx
systemctl enable nginx
