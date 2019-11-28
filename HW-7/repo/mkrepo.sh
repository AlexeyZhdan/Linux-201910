#!/bin/bash

mkdir /usr/share/nginx/html/repo
cp rpmbuild/RPMS/x86_64/nginx-1.16.1-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo
wget http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-0.1-6.noarch.rpm
createrepo /usr/share/nginx/html/repo/
cp -f /files/default.conf /etc/nginx/conf.d/nginx -s reload
cat >> /etc/yum.repos.d/myrepo.repo <<EOF
 [myrepo]
 name=myrepo-linux
 baseurl=http://localhost/repo
 gpgcheck=0
 enabled=1
 EOF
 
