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
**yum install epel-release -y && yum install spawn-fcgi php-climod_gcgid httpd -y** если установка прошла успешно в конце получим вывод:

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
