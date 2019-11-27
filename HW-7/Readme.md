# Управление пакетами. Дистрибьюция софта.
## Создание своего RPM пакетам

Для начала следует установить в систему инструменты для сборки и управления RPM пакетами для этого используем следующую команду:

```bash
[root@bash ~]# yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils
```

Возьмем пакет NGINX и включим в негоподдержку openssl
Загружаем исходники (SRPM) пакета NGINX для его модификации для этого используем команду:

 ```bash
 [root@bash ~]# wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.16.1-1.el7.ngx.src.rpm
 ```

 проверяем что пакет успешно загрузился

 ```bash
 [root@bash ~]# ll
total 1044
-rw-------. 1 root root    5570 Jun  1 17:18 anaconda-ks.cfg
-rw-r--r--. 1 root root 1052448 Aug 13 16:17 nginx-1.16.1-1.el7.ngx.src.rpm
-rw-------. 1 root root    5300 Jun  1 17:18 original-ks.cfg
```

устанавливаем командой:

```bash
[root@bash ~]# rpm -i nginx-1.16.1-1.el7.ngx.src.rpm
```

загружаем исходники для пакета openssl командой:

```bash
[root@bash ~]# wget https://www.openssl.org/source/latest.tar.gz
```

Распаковываем архив командой:

```bash
[root@bash ~]# tar -xvf latest.tar.gz
```

проставляем все зависимости

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

Получаем ошибку и идем за компилятором. Устанавливаем пакет gcc

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
