# Пользователи и группы. Авторизация и аутентификация.
## Подготовка стенда

Создаем 3х пользователей **day** - может входить в систему с 8:00 до 20:00, **night** может входить в систему с 20:00 до 8:00 **friday** может входить в систему в любое время, но только по пятницам

```bash
[root@web ~]# useradd day && useradd night && useradd friday
```

Назначим вновь созданным пользователям пароли

```bash
[root@web ~]# echo "Otus2019" | passwd --stdin day && echo "Otus2019" | passwd --stdin night && echo "Otus2019" | passwd --stdin friday
Changing password for user day.
passwd: all authentication tokens updated successfully.
Changing password for user night.
passwd: all authentication tokens updated successfully.
Changing password for user friday.
passwd: all authentication tokens updated successfully.
```

Разрешим вход по **ssh** с использованием пароля

```bash
[root@web ~]# bash -c "sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config && systemctl restart sshd.service"
```

## Настройка ограничений времени входа при помощи модуля pam_time

Данный модуль позволяет достаточно гибко настраивать время работы пользователя. Все настройки производятся путем редактирования конфигурационного файла ***/etc/security/time.conf***. Для реализации требуемой задачи добавим в конец файла следующие строки:

```bash
*;*;day;Al0800-2000
*;*;night;!Al0800-2000
*;*;friday;Fr
```

Поля в записи разделяются **;** формат записи означает следующее:
- первое поле - сервис (может быть указан любой сервис который разрешено запускать пользователю);
- второе поле - терминал с которого пользователю разрешен заход;
- третье поле - имя пользователя или группы
- четвертое поле - время в которое пользователь может входить в систему (указывается в формате день недели|время)

После настройки модуля необходимо подключить его в конфигурации РАМ. Для этого необходимо внести изменения в файл ***/etc/pam.d/sshd*** добавив в него строку
```bash
account    required     pam_time.so
```
листинг получившегося файла
```bash
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
account    required     pam_nologin.so
account    required     pam_time.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
# Used with polkit to reauthorize users in remote sessions
-session   optional     pam_reauthorize.so prepare
```

Проверим с другой машины с аналогичными пользователями попытаемся подключиться к нашей машине по **SSH**

```bash
[root@ansible /]# su night
[night@ansible /]$ ssh web
The authenticity of host 'web (192.168.11.151)' can't be established.
ECDSA key fingerprint is SHA256:RJbJAwj2ukp0gVxJGsW6zPFWvJiePnBaiuAweqHSRUI.
ECDSA key fingerprint is MD5:4b:18:09:60:cf:2b:14:4e:0d:f6:92:6b:60:d3:e5:2f.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'web,192.168.11.151' (ECDSA) to the list of known hosts.
night@web's password:
Authentication failed.
[root@ansible /]# su day
[day@ansible /]$ ssh web
The authenticity of host 'web (192.168.11.151)' can't be established.
ECDSA key fingerprint is SHA256:RJbJAwj2ukp0gVxJGsW6zPFWvJiePnBaiuAweqHSRUI.
ECDSA key fingerprint is MD5:4b:18:09:60:cf:2b:14:4e:0d:f6:92:6b:60:d3:e5:2f.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'web,192.168.11.151' (ECDSA) to the list of known hosts.
day@web's password:
Last login: Wed Dec 25 12:18:38 2019
[day@web ~]$
```
Как видно все работает пользователь **day** получает доступ к консоли, тогда как пользователь **night** получает ошибку аутентификации.

## Модуль pam_exec

Второй способ настроить ограничение во времени входа пользователя в систему использовать модуль **pam_exec**. При аутентификации пользователя данный модуль будет выполнять скрипт в котором будет прописана соответствующая проверка.
Для использования данного модуля нужно сначала убрать изменения внесенные для модуля **pam_time** в файле ***/etc/pam.d/sshd*** и добавить в него следующую строку:

```bash
account required pam_exec.so /usr/local/bin/test_login.sh
```

Создадим сам скрипт в каталоге ***/usr/local/bin/***
```bash
#!/bin/bash
if [ $PAM_USER = "friday" ]; then
 if [ $(date +%a) = "Fri" ]; then
 exit 0
 else
 exit 1
 fi
fi
hour=$(date +%H)
is_day_hours=$(($(test $hour -ge 8; echo $?)+$(test $hour -lt 20; echo $?)))
if [ $PAM_USER = "day" ]; then
 if [ $is_day_hours -eq 0 ]; then
 exit 0
 else
 exit 1
 fi
fi
if [ $PAM_USER = "night" ]; then
 if [ $is_day_hours -eq 1 ]; then
 exit 0
 else
 exit 1
 fi
fi
```

Добавим разрешение на исполнение для созданного файла

```bash
[root@web bin]# chmod +x test_login.sh
```

Так же проверим возможность подключения пользователей по **SSH**
```bash
[day@ansible root]$ ssh web
day@web's password:
/usr/local/bin/test_login.sh failed: exit code 1
Authentication failed.
[day@ansible root]$ exit
exit
[root@ansible ~]# su night
[night@ansible root]$ ssh web
night@web's password:
Last failed login: Wed Dec 25 12:28:20 UTC 2019 from 192.168.11.150 on ssh:notty
There was 1 failed login attempt since the last successful login.
Last login: Wed Dec 25 12:19:14 2019
[night@web ~]$
```

## Модуль pam_script

Еще один способ решения данной задачи использовать модуль **pam_script**. Работа данного модуля похожа на работу модуля **pam_exec**.
По умолчанию данный модуль не входит в базовый мсостав модулей **pam** поэтому его сначала нужно установить:
```bash
[root@web bin]# yum install -y pam_script
...
Installed:
  pam_script.x86_64 0:1.1.8-1.el7

Complete!
```

Для проверки данного модуля необходимо изменить строку используемую для проверки модуля **pam_exec** в файле ***/etc/pam.d/sshd*** на

```bash
account required pam_script.so /usr/local/bin/test_login.sh
```

для проверки будем использовать скрипт созданный для модуля **pam_exec**. проверим возможность пользователей подключиться по **SSH**

```bash
[day@ansible root]$ ssh web
day@web's password:
/usr/local/bin/test_login.sh failed: exit code 1
Authentication failed.
[day@ansible root]$ exit
exit
[root@ansible ~]# su night
[night@ansible root]$ ssh web
night@web's password:
Last failed login: Wed Dec 25 12:28:20 UTC 2019 from 192.168.11.150 on ssh:notty
There was 1 failed login attempt since the last successful login.
Last login: Wed Dec 25 12:19:14 2019
[night@web ~]$
```

## Модуль pam_cap

Установим дополнительный пакет **nmap-ncat**
```bash
[root@web pam.d]# yum install nmap-ncat
...
Installed:
  nmap-ncat.x86_64 2:6.40-19.el7

Dependency Installed:
  libpcap.x86_64 14:1.5.3-11.el7

Complete!
```

Залогинемся на машине под пользователем **day** и попробуем дать команду на открытие 80 порта
```bash
[day@web ~]$ ncat -l -p 80
Ncat: bind to :::80: Permission denied. QUITTING.
```

Получим сообщение об ошибке. Предоставим пользователю **day** возможность открыввать порт, для этого воспользуемся модулем **pam_cap** для того чтобы это было возможно еобходимо произвести соответсвующие настройки в **selinux** или отключить данный функционал. Т.к. мы работаем на стенде то воспользуемся отклячением **selinux**. Внесем изменения в файл ***/etc/pam.d/sshd***

```bash
auth       required     pam_cap.so
```

В каталоге **/etc/security** создадим файл ***capability.conf*** со следующим содержанием:
```bash
cap_net_bind_service     day
```

Выдаем программе **ncat** разрешение на открытие порта

```bash
[root@web pam.d]# setcap cap_net_bind_service=ei /usr/bin/ncat
```

Повторно выполним вход под пользователем **day** и проверим что необходимы права получены:

```bash
[day@ansible root]$ ssh web
day@web's password:
Last login: Thu Dec 26 08:00:15 2019 from 192.168.11.150
[day@web ~]$ capsh --print
Current: = cap_net_bind_service+i
Bounding set =cap_chown,cap_dac_override,cap_dac_read_search,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_linux_immutable,cap_net_bind_service,cap_net_broadcast,cap_net_admin,cap_net_raw,cap_ipc_lock,cap_ipc_owner,cap_sys_module,cap_sys_rawio,cap_sys_chroot,cap_sys_ptrace,cap_sys_pacct,cap_sys_admin,cap_sys_boot,cap_sys_nice,cap_sys_resource,cap_sys_time,cap_sys_tty_config,cap_mknod,cap_lease,cap_audit_write,cap_audit_control,cap_setfcap,cap_mac_override,cap_mac_admin,cap_syslog,35,36
Securebits: 00/0x0/1'b0
 secure-noroot: no (unlocked)
 secure-no-suid-fixup: no (unlocked)
 secure-keep-caps: no (unlocked)
uid=1001(day)
gid=1001(day)
```
повторно выполним команду:
```bash
[day@web ~]$ ncat -l -p 80
```
Ошибки в этот раз не возникло и мы оказались в режиме прослушивания 80-го порта. Откроем еще один терминал и наберем с него следующую команду:
```bash
[day@web ~]$ echo "Make Linux greate again! " > /dev/tcp/127.0.0.7/80
```
результатом команды отобразится на терминале прослушивающем 80 порт:
```bash
[day@web ~]$ ncat -l -p 80
Make Linux greate again!
```

## Права администратора

Если мы введем команду **sudo -i** от имени пользователя не обладающего павами администратора мы получим следующее:

```bash
[day@web ~]$ sudo -i

We trust you have received the usual lecture from the local System
Administrator. It usually boils down to these three things:

    #1) Respect the privacy of others.
    #2) Think before you type.
    #3) With great power comes great responsibility.

[sudo] password for day:
day is not in the sudoers file.  This incident will be reported.
```

Для предоставлению пользователю прав администратора существует несколько способов.
- включить пользователя в группу **wheel**
- создать для пользователя соответствующую запись в файле ***/etc/sudoers***
- создать для пользователя отдельный файл в каталоге ***/etc/sudoers.d/***
Мы будем использовать последний вариант. Создадим  в каталоге ***/etc/sudoers.d/*** файл с именем пользователя которому мы предоставим право действовать от имени администратора

```bash
[root@web pam.d]# vi /etc/sudoers.d/day
```

содержимое файла будет следующим:
```bash
day        ALL=(ALL)        NOPASSWD: ALL
```
таким образом мы предоставляем пользователю **day** право использовать команду **sudo -i** без ввода пароля. Проверяем:
```bash
[day@web ~]$ sudo -i
[root@web ~]#
```

# Выполнение домашнего задания

Требуется запретить всем пользователям, кроме группы **admin** логин в выходные (суббота и воскресенье), без учета праздников.

Создаем пользователя **test** и группу **admin**
```bash
[root@web pam.d]# useradd test
[root@web pam.d]# groupadd admin
```
назначаем пользователю **test** пароль "Otus2019"
```bash
[root@web pam.d]# passwd test
Changing password for user test.
New password:
Retype new password:
passwd: all authentication tokens updated successfully.
```
добавляем пользователя **test** в группу **admin**
```bash
[root@web pam.d]# usermod -aG admin test
```
для решения нашей задачи воспользуемся модулем **pam_time**. Отредактируем файл ***/etc/security/time.conf*** добавим в него строки:
```bash
*;*;*;!Wd
*;*;admin;Al
```
отредактируем файлы ***/etc/pam.d/sshd*** и ***/etc/pam.d/login*** вставив в них следующую строку:
```bash
account    required     pam_time.so
```
листинг файла ***/etc/pam.d/sshd***
```bash
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
account    required     pam_nologin.so
account    required     pam_time.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
# Used with polkit to reauthorize users in remote sessions
-session   optional     pam_reauthorize.so prepare
```
листинг файла ***/etc/pam.d/login***
```bash
#%PAM-1.0
auth [user_unknown=ignore success=ok ignore=ignore default=bad] pam_securetty.so
auth       substack     system-auth
auth       include      postlogin
account    required     pam_nologin.so
account    required     pam_time.so
account    include      system-auth
password   include      system-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_console.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      system-auth
session    include      postlogin
-session   optional     pam_ck_connector.so
```
Таким образом пользователи не входящие в группу admin смогут входить локально и через ssh только порабочим дням
