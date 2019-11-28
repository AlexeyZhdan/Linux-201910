# Управление пакетами. Дистрибьюция софта.
## Создание своего RPM пакетам

Для начала следует установить в систему инструменты для сборки и управления RPM пакетами для этого используем следующую команду:

```bash
[root@bash ~]# yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils
```

Возьмем пакет NGINX и включим в негоподдержку openssl
Загружаем исходники **(SRPM)** пакета **NGINX** для его модификации для этого используем команду:

 ```bash
 [root@bash ~]# wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.16.1-1.el7.ngx.src.rpm
 ```

 Проверяем что пакет успешно загрузился

 ```bash
 [root@bash ~]# ll
total 1044
-rw-------. 1 root root    5570 Jun  1 17:18 anaconda-ks.cfg
-rw-r--r--. 1 root root 1052448 Aug 13 16:17 nginx-1.16.1-1.el7.ngx.src.rpm
-rw-------. 1 root root    5300 Jun  1 17:18 original-ks.cfg
```

Устанавливаем загруженный пакет командой:

```bash
[root@bash ~]# rpm -i nginx-1.16.1-1.el7.ngx.src.rpm
```

Загружаем исходники для пакета **openssl** командой:

```bash
[root@bash ~]# wget https://www.openssl.org/source/latest.tar.gz
```

Распаковываем архив командой:

```bash
[root@bash ~]# tar -xvf latest.tar.gz
```

Проставляем все зависимости

```bash
[root@bash ~]# yum-builddep rpmbuild/SPECS/nginx.spec
```

Редактируем файл *nginx.spec*

```bash
%define BASE_CONFIGURE_ARGS $(echo "--prefix=%{_sysconfdir}/nginx --sbin-path=%{_sbindir}/nginx --modules-path=%{_libdir}/nginx/modules --conf-path=%{_sysconfdir}/nginx/nginx.conf --error-log-path=%{_localstatedir}/log/nginx/error.log --http-log-path=%{_localstatedir}/log/nginx/access.log --pid-path=%{_localstatedir}/run/nginx.pid --lock-path=%{_localstatedir}/run/nginx.lock --http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp --http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp --http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp --http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp --user=%{nginx_user} --group=%{nginx_group} --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-openssl=/root/openssl-1.1.1d --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module")
```

Приступаем к сборке пакета

```bash
[root@bash ~]# rpmbuild -bb rpmbuild/SPECS/nginx.spec
```

Получаем ошибку и идем за компилятором. Устанавливаем пакет **gcc**

```bash
[root@bash ~]# yum install gcc
```

и запускаем повторно. В случае успешной установки получаем в конце вывода следующие строки:

```bash
Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.M1eSIU
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd nginx-1.16.1
+ /usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nginx-1.16.1-1.el7.ngx.x86_64
+ exit 0
```

Убеждаемся что пакеты успешно создались:

```bash
[root@bash ~]# ll rpmbuild/RPMS/x86_64/
total 5488
-rw-r--r--. 1 root root 3657612 Nov 27 14:29 nginx-1.16.1-1.el7.ngx.x86_64.rpm
-rw-r--r--. 1 root root 1959160 Nov 27 14:29 nginx-debuginfo-1.16.1-1.el7.ngx.x86_64.rpm
```

Устанавливаем пакет

```bash
[root@bash ~]# yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.16.1-1.el7.ngx.x86_64.rpm

...
Verifying  : 1:nginx-1.16.1-1.el7.ngx.x86_64                                                                      1/1

Installed:
nginx.x86_64 1:1.16.1-1.el7.ngx

Complete!
```

Запускаем и проверяем что все работает

```bash
[root@bash ~]# systemctl start nginx
[root@bash ~]# systemctl status nginx
● nginx.service - nginx - high performance web server
 Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
 Active: active (running) since Wed 2019-11-27 14:44:34 UTC; 26s ago
   Docs: http://nginx.org/en/docs/
Process: 31399 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=0/SUCCESS)
Main PID: 31400 (nginx)
 CGroup: /system.slice/nginx.service
         ├─31400 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
         └─31401 nginx: worker process

Nov 27 14:44:34 bash systemd[1]: Starting nginx - high performance web server...
Nov 27 14:44:34 bash systemd[1]: PID file /var/run/nginx.pid not readable (yet?) after start.
Nov 27 14:44:34 bash systemd[1]: Started nginx - high performance web server.
```

## Создать свой репозиторий и разместить в нем созданный RPM пакет

Создаем каталог для размещения репозитория. Создаем каталог **repo** в каталоге для статики **NGINX** по умолчанию ***/usr/shsre/nginx/html***

```bash
[root@bash ~]# mkdir /usr/share/nginx/html/repo
```

копируем в каталог **repo** созданный ранее **RPM** и дополнительно размещаем в нем **RPM** для установки репозитория **Percona-Server**

```bash
[root@bash ~]# cp rpmbuild/RPMS/x86_64/nginx-1.16.1-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo
[root@bash ~]# wget http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-0.1-6.noarch.rpm
--2019-11-28 06:51:46--  http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm
Resolving www.percona.com (www.percona.com)... 74.121.199.234
Connecting to www.percona.com (www.percona.com)|74.121.199.234|:80... connected.
HTTP request sent, awaiting response... 301 Moved Permanently
Location: https://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm [following]
--2019-11-28 06:51:47--  https://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm
Connecting to www.percona.com (www.percona.com)|74.121.199.234|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 14520 (14K) [application/x-redhat-package-manager]
Saving to: ‘/usr/share/nginx/html/repo/percona-release-0.1-6.noarch.rpm’

100%[==============================================================================>] 14,520      --.-K/s   in 0s

2019-11-28 06:51:48 (47.6 MB/s) - ‘/usr/share/nginx/html/repo/percona-release-0.1-6.noarch.rpm’ saved [14520/14520]
```

инициализируем репозиторий

```bash
[root@bash ~]# createrepo /usr/share/nginx/html/repo/
Spawning worker 0 with 2 pkgs
Workers Finished
Saving Primary metadata
Saving file lists metadata
Saving other metadata
Generating sqlite DBs
Sqlite DBs complete
```

настраиваем в **NGINX** доступ к листингу каталогов, для чего в секции ***/locations*** в файле ***/etc/nginx/conf.d/default.conf*** добавляем директиву *autoindex on*

```bash
location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
    autoindex on;
}
```

проверяем синтаксис

```bash
[root@bash ~]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

перезапускаем **NGINX**

```bash
[root@bash ~]# nginx -s reload
```

проверяем при помощи команды **curl**

```bash
[root@bash ~]# curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          28-Nov-2019 06:54                   -
<a href="nginx-1.16.1-1.el7.ngx.x86_64.rpm">nginx-1.16.1-1.el7.ngx.x86_64.rpm</a>                  28-Nov-2019 06:47             3657612
<a href="percona-release-0.1-6.noarch.rpm">percona-release-0.1-6.noarch.rpm</a>                   13-Jun-2018 06:34               14520
</pre><hr></body>
</html>
```

Добавляем наш репозиторий в  **/etc/yum.repos.d**

```bash
[root@bash ~]# cat >> /etc/yum.repos.d/myrepo.repo <<EOF
> [myrepo]
> name=myrepo-linux
> baseurl=http://localhost/repo
> gpgcheck=0
> enabled=1
> EOF
```

Уеждаемся что репозиторий подключился

```bash
[root@bash ~]# yum repolist enabled | grep myrepo
myrepo                              myrepo-linux                               2
```

Проверяем что у нас есть в репозитории

```bash
[root@bash ~]# yum list |grep myrepo
nginx                                       1.16.1                     myrepo
percona-release.noarch                      0.1-6                      myrepo
```

Устанавливаем репозиторий **percona-release**

```bash
[root@bash repodata]# yum install percona-release -y
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: mirror.sale-dedic.com
 * extras: mirrors.datahouse.ru
 * updates: mirror.awanti.com
Resolving Dependencies
--> Running transaction check
---> Package percona-release.noarch 0:0.1-6 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

========================================================================================================================
 Package                            Arch                      Version                   Repository                 Size
========================================================================================================================
Installing:
 percona-release                    noarch                    0.1-6                     myrepo                     14 k

Transaction Summary
========================================================================================================================
Install  1 Package

Total download size: 14 k
Installed size: 16 k
Downloading packages:
percona-release-0.1-6.noarch.rpm                                                                 |  14 kB  00:00:00
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : percona-release-0.1-6.noarch                                                                         1/1
  Verifying  : percona-release-0.1-6.noarch                                                                         1/1

Installed:
  percona-release.noarch 0:0.1-6

Complete!
```

При добавлении дополнительных **RPM** пакетов в наш репозиторий, после каждого добавления необходимо выполнить команду **createrepo /usr/share/nginx/html/repo**  
