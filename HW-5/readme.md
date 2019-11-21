# Изучение systemd
## Написать сервис

Необходимо написать сервис, который раз в 30 секунд будет мониторить лог на предмет наличия ключевого слова. Файл и слово будут задаваться в **/etc/sysconfig**.
Для того чтобы сервис брал данные из каталога  **/etc/sysconfig** необходимо создать файл конфигурации для этого сервиса.
Создаем файл конфигурации **/etc/sysconfig/watchlog**

```bash
#Configuration file for my watchlog service
#Place it to /etc/sysconfig

#File and word in that file witch we will be monitoring
WORD="ALERT"
LOG=/var/log/watchlog.log
```

После этого нам необходимо создать файл **watchlog.log**  содержащий ключевое слово 'ALERT' в каталоге **/var/log**
Создадим скрипт **watchlog.sh** который будет анализировать файл на предмет нахождения в нем целевого слова. В качестве входных данных будут **ключевое слово** и **местоположение и название файла**. Данные на вход будут браться из файла **/etc/sysconfig/watchlog**.

Листинг скрипта **watchlog.sh**:

```bash
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
   logger "$DATE: I found word, Master!"
else
   exit 0
fi
```

В каталоге **/etc/systemd/system** создаем файл **watchlog.service** основной файл юнита запускающий созданный нами скрипт **watchlog.sh**

Листинг файла **watchlog.service**:

```bash
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```

В каталоге **/etc/systemd/system** создаем файл юнита для таймера **watchlog.timer**  

Листинг файла **watchlog.timer**:

```bash
[Unit]
Description=Run watchlog script every 30 second

[Timer]
#Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
```

Меняем разрешения на созданные файлы предоставляя право на запуск

Запускаем созданный сервис командой **systemctl start watchlog.timer** результат работы сервиса можно посмотреть командой **tail -f /var/log/messages**

Результат работы сервиса:

```bash
Nov 20 19:20:18 linuxsysd systemd: Started Run watchlog script every 30 second.
Nov 20 19:20:18 linuxsysd systemd: Starting Run watchlog script every 30 second.
Nov 20 19:41:19 linuxsysd vagrant: Wed Nov 20 19:41:19 UTC 2019: I found word, Master!
Nov 20 20:01:01 linuxsysd systemd: Created slice User Slice of root.
Nov 20 20:01:01 linuxsysd systemd: Starting User Slice of root.
Nov 20 20:01:01 linuxsysd systemd: Started Session 3 of user root.
Nov 20 20:01:01 linuxsysd systemd: Starting Session 3 of user root.
Nov 20 20:01:01 linuxsysd systemd: Removed slice User Slice of root.
Nov 20 20:01:01 linuxsysd systemd: Stopping User Slice of root.
Nov 20 20:10:56 linuxsysd vagrant: Wed Nov 20 20:10:56 UTC 2019: I found word, Master!
Nov 20 20:11:18 linuxsysd vagrant: Wed Nov 20 20:11:18 UTC 2019: I found word, Master!
[root@linuxsysd sysconfig]# tail -f /var/log/messages
Nov 20 19:20:18 linuxsysd systemd: Starting Run watchlog script every 30 second.
Nov 20 19:41:19 linuxsysd vagrant: Wed Nov 20 19:41:19 UTC 2019: I found word, Master!
Nov 20 20:01:01 linuxsysd systemd: Created slice User Slice of root.
Nov 20 20:01:01 linuxsysd systemd: Starting User Slice of root.
Nov 20 20:01:01 linuxsysd systemd: Started Session 3 of user root.
Nov 20 20:01:01 linuxsysd systemd: Starting Session 3 of user root.
Nov 20 20:01:01 linuxsysd systemd: Removed slice User Slice of root.
Nov 20 20:01:01 linuxsysd systemd: Stopping User Slice of root.
Nov 20 20:10:56 linuxsysd vagrant: Wed Nov 20 20:10:56 UTC 2019: I found word, Master!
Nov 20 20:11:18 linuxsysd vagrant: Wed Nov 20 20:11:18 UTC 2019: I found word, Master!
```

## Переделать init-скрипт для spawn-fcgi на unit-файл

Устанавливаем **spawn-fcgi** из репозитория **epel-release**. Для этого запускаем команду:
**yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y** если установка прошла успешно в конце получим вывод:

```bash
Installed:
  httpd.x86_64 0:2.4.6-90.el7.centos                           spawn-fcgi.x86_64 0:1.6.3-5.el7

Dependency Installed:
  apr.x86_64 0:1.4.8-5.el7            apr-util.x86_64 0:1.5.2-6.el7       httpd-tools.x86_64 0:2.4.6-90.el7.centos
  mailcap.noarch 0:2.1.41-2.el7

Complete!
```

Теперь необходимо раскомментировать переменные в файле **/etc/sysconfig/spawn-fcgi**. Делаем это при помощи редактора vi:

```bash
[root@linuxsysd init.d]# vi /etc/sysconfig/spawn-fcpi
```

Снимаем комментари со строк:

```bash
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"
```

В каталоге **/etc/systemd/system** создаем файл юнита **spawn-fcgi.service** командой:

```bash
[root@linuxsysd init.d]# vi /etc/systemd/system/spawn-fcgi.service
```

Листинг файла:

```bash
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```

Запускаем сервис:

```bash
[root@linuxsysd bin]# systemctl start spawn-fcgi
```

проверяем:

```bash
[root@linuxsysd bin]# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2019-11-20 21:53:29 UTC; 5s ago
 Main PID: 1624 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─1624 /usr/bin/php-cgi
           ├─1625 /usr/bin/php-cgi
           ├─1626 /usr/bin/php-cgi
           ├─1627 /usr/bin/php-cgi
           ├─1628 /usr/bin/php-cgi
           ├─1629 /usr/bin/php-cgi
           ├─1630 /usr/bin/php-cgi
           ├─1631 /usr/bin/php-cgi
           ├─1632 /usr/bin/php-cgi
           ├─1633 /usr/bin/php-cgi
           ├─1634 /usr/bin/php-cgi
           ├─1635 /usr/bin/php-cgi
           ├─1636 /usr/bin/php-cgi
           ├─1637 /usr/bin/php-cgi
           ├─1638 /usr/bin/php-cgi
           ├─1639 /usr/bin/php-cgi
           ├─1640 /usr/bin/php-cgi
           ├─1641 /usr/bin/php-cgi
           ├─1642 /usr/bin/php-cgi
           ├─1643 /usr/bin/php-cgi
           ├─1644 /usr/bin/php-cgi
           ├─1645 /usr/bin/php-cgi
           ├─1646 /usr/bin/php-cgi
           ├─1647 /usr/bin/php-cgi
           ├─1648 /usr/bin/php-cgi
           ├─1649 /usr/bin/php-cgi
           ├─1650 /usr/bin/php-cgi
           ├─1651 /usr/bin/php-cgi
           ├─1652 /usr/bin/php-cgi
           ├─1653 /usr/bin/php-cgi
           ├─1654 /usr/bin/php-cgi
           ├─1655 /usr/bin/php-cgi
           └─1656 /usr/bin/php-cgi

Nov 20 21:53:29 linuxsysd systemd[1]: Started Spawn-fcgi startup service by Otus.
Nov 20 21:53:29 linuxsysd systemd[1]: Starting Spawn-fcgi startup service by Otus...
```

## Дополнить unit-файл apache httpd возможностью запустить несколько инстансов сервера с разными конфигами

Для того чтобы запустить несколько инстансов **apache httpd** необходимо:
- скопировать юнит-файл из каталога **/usr/lib/systemd/system** в каталог **/etc/systemd/system** переделав его в шаблон
- изменить юнит-файл **httpd@.service**
- создать два файла окружения для каждого инстанса в каталоге **/etc/sysconfig**
- отредактировать файлы окружения
- создать файлы конфигурации **first.conf** и **second.conf**
- в файле **second.conf** изменить параметр **Listen** и добавить параметр **PidFile**

Копируем юнит-файл **apache httpd** из каталога **/usr/lib/systemd/system** в каталог **/etc/systemd/system** при этом в название файла добавляем символ **@**. Этот символ служит указателем на то что данный юнит файл является шаблоном.

```bash
[root@linuxsysd ~]# cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@.service
```

Далее чтобы преобразовать юнит-файл в шаблон изменяем параметр *EnvirinmentFile* добавляя в конце строки *%I* для изменения файла используем редактор **VI**

```bash
[root@linuxsysd ~]# vi /etc/systemd/system/httpd@.service
```

листинг файла:

```bash
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
# We want systemd to give httpd some time to finish gracefully, but still want
# it to kill httpd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
# httpd time to finish.
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

создаем файлы окружения **httpd-first** и **httpd-second** в каталоге **/etc/sysconfig** для этого копируем стандартный файл окружения **httpd** и переименовываем его при копировании.
Редактируем созданные файлы окружения прописывая в них параметры в *OPTIONS*

листинг файла **httpd-first**

```bash
#
# This file can be used to set additional environment variables for
# the httpd process, or pass additional options to the httpd
# executable.
#
# Note: With previous versions of httpd, the MPM could be changed by
# editing an "HTTPD" variable here.  With the current version, that
# variable is now ignored.  The MPM is a loadable module, and the
# choice of MPM can be changed by editing the configuration file
# /etc/httpd/conf.modules.d/00-mpm.conf.
#

#
# To pass additional options (for instance, -D definitions) to the
# httpd binary at startup, set OPTIONS here.
#
#/etc/sysconfig/httpd-first
OPTIONS=-f conf/first.conf

#
# This setting ensures the httpd process is started in the "C" locale
# by default.  (Some modules will not behave correctly if
# case-sensitive string comparisons are performed in a different
# locale.)
#
LANG=C
```

листинг файла **httpd-second**

```bash
#
# This file can be used to set additional environment variables for
# the httpd process, or pass additional options to the httpd
# executable.
#
# Note: With previous versions of httpd, the MPM could be changed by
# editing an "HTTPD" variable here.  With the current version, that
# variable is now ignored.  The MPM is a loadable module, and the
# choice of MPM can be changed by editing the configuration file
# /etc/httpd/conf.modules.d/00-mpm.conf.
#

#
# To pass additional options (for instance, -D definitions) to the
# httpd binary at startup, set OPTIONS here.
#
#/etc/sysconfig/httpd-second
OPTIONS=-f conf/second.conf

#
# This setting ensures the httpd process is started in the "C" locale
# by default.  (Some modules will not behave correctly if
# case-sensitive string comparisons are performed in a different
# locale.)
#
LANG=C
```

создаем файлы конфигурации **first.conf** и **second.conf** в каталоге **/etc/httpd/conf** для этого копируем стандартный файл окружения **httpd.conf** и переименовываем его при копировании.

меняем параметры в файле **second.conf** добавляем параметр **PidFile "/var/run/httpd-second.pid"** и меняем параметр **Listen** со значения **80** на значение **8080**

запускаем оба сервиса

```bash
[root@linuxsysd conf]# systemctl start httpd@first
[root@linuxsysd conf]# systemctl start httpd@second
```

проверяем что сервисы запустились и активны

```bash
[root@linuxsysd conf]# systemctl status httpd@first
● httpd@first.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2019-11-21 17:37:07 UTC; 5s ago
     Docs: man:httpd(8)
           man:apachectl(8)
  Process: 1288 ExecStop=/bin/kill -WINCH ${MAINPID} (code=exited, status=1/FAILURE)
 Main PID: 1302 (httpd)
   Status: "Processing requests..."
   CGroup: /system.slice/system-httpd.slice/httpd@first.service
           ├─1302 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─1303 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─1304 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─1305 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─1306 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─1307 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           └─1308 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND

Nov 21 17:37:07 linuxsysd systemd[1]: Starting The Apache HTTP Server...
Nov 21 17:37:07 linuxsysd httpd[1302]: AH00558: httpd: Could not reliably determine the server's fully qualifie...essage
Nov 21 17:37:07 linuxsysd systemd[1]: Started The Apache HTTP Server.
Hint: Some lines were ellipsized, use -l to show in full.
```

```bash
[root@linuxsysd conf]# systemctl status httpd@second
● httpd@second.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2019-11-21 17:37:43 UTC; 14s ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 1316 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@second.service
           ├─1316 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─1317 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─1318 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─1319 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─1320 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─1321 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           └─1322 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND

Nov 21 17:37:43 linuxsysd systemd[1]: Starting The Apache HTTP Server...
Nov 21 17:37:43 linuxsysd httpd[1316]: AH00558: httpd: Could not reliably determine the server's fully qualifie...essage
Nov 21 17:37:43 linuxsysd systemd[1]: Started The Apache HTTP Server.
Hint: Some lines were ellipsized, use -l to show in full.
```

```bash
[root@linuxsysd conf]# ss -tnulp | grep httpd
tcp    LISTEN     0      128      :::8080                 :::*                   users:(("httpd",pid=1322,fd=4),("httpd",pid=1321,fd=4),("httpd",pid=1320,fd=4),("httpd",pid=1319,fd=4),("httpd",pid=1318,fd=4),("httpd",pid=1317,fd=4),("httpd",pid=1316,fd=4))
tcp    LISTEN     0      128      :::80                   :::*                   users:(("httpd",pid=1308,fd=4),("httpd",pid=1307,fd=4),("httpd",pid=1306,fd=4),("httpd",pid=1305,fd=4),("httpd",pid=1304,fd=4),("httpd",pid=1303,fd=4),("httpd",pid=1302,fd=4))
```
