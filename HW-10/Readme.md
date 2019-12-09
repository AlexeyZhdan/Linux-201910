# Автоматизация администрирования Ansible
## Подготовка стенда

Для стенда с **Ansible** запускаем ***Vagrantfile*** формирующий две виртуальных машины:
- **Ansible** - виртуальная машина с установленным на ней *Ansible* для управления развертыванием
- **Web** - виртуальная машина где будет посредством *Ansible* производиться развертывание *Nginx*

На машине с *Ansible* проверяем что установлен пакет *Python* с версией не ниже 2.6

```bash
[root@ansible ~]# python -V
Python 2.7.5
```

Проверяем что при развертывании *Ansible* установился

```bash
[root@ansible ~]# ansible --version
ansible 2.9.1
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/root/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/site-packages/ansible
  executable location = /bin/ansible
  python version = 2.7.5 (default, Apr  9 2019, 14:30:50) [GCC 4.8.5 20150623 (Red Hat 4.8.5-36)]
```

### Настройка Ansible

Ansible использует SSH поэтому для начала нужно убедиться что хост Web будет доступен по SSH

```bash
  [vagrant@ansible ~]$ ssh web
  The authenticity of host 'web (192.168.11.151)' can't be established.
  ECDSA key fingerprint is SHA256:PWk7U7lG3svitIhpv5MTlPsVDNMPZMdM7Ixw4C1vt60.
  ECDSA key fingerprint is MD5:93:eb:67:1e:b1:36:d5:81:58:74:74:0d:bd:89:b8:4c.
  Are you sure you want to continue connecting (yes/no)? yes
  Warning: Permanently added 'web,192.168.11.151' (ECDSA) to the list of known hosts.
  [vagrant@web ~]$
  '
```

После  этого необходимо проверить что на хосте Web установлен Python версии не ниже чем 2.x

```bash
[vagrant@web ~]$ python -V
Python 2.7.5
```

Создаем в корне каталог **Ansible** в нем создаем каталог **staging** и в нем создаем *inventory* файл *hosts* в файле задаем следующие параметры:

```bash
[web]
web ansible_host=192.168.11.151 ansible_port=22 ansible_user=vagrant ansible_private_key_file=/home/vagrant/.ssh/id_rsa
```

здесь используются следующие параметры:
- **[web]** - секция для развертывания веб серверов
- **web** - псевдоним используемый для развертываемого сервера (в напшем случае используем такй же псевдоним как в Vagrantfile)
- **ansible_host** - IP адрес сервера (может быть использовано также DNS имя соответствующего сервера)
- **ansible_port** - порт который будет использован для *ssh* подключения посредством *Ansible*
- **ansible_user** - пользователь от имени которого будет подключаться *Ansible*
- **ansible_private_key_file** - указывается путь к каталогу в котором размещен приватный ключ пользователя

Запускаем Ansible и проверяем что он может управлять нашим хостом

```bash
[root@ansible Ansible]# ansible web -i staging/hosts -m ping
[WARNING]: Found both group and host with same name: web

web | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

Для того чтобы при запуске *Ansible* не указывать каждый раз *inventory* файл создадим в корне каталога **/Ansible** файл конфигурации *ansible.cfg* со следующими параметрами

```bash
[defaults]
inventory = staging/hosts
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
```

после этого из *inventory* файла можно убрать информацию о пользователе

```bash
[web]
web ansible_host=192.168.11.151 ansible_port=22 ansible_private_key_file=/home/vagrant/.ssh/id_rsa
```

Еще раз убедимся что управляемый хост доступен, но уже без указания файла

```bash
[root@ansible Ansible]# ansible web -m ping
[WARNING]: Found both group and host with same name: web

web | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

### Конфигурирование хоста с помощью Ansible

Выполним через **Ansible** несколько **Ad-Hoc** команд. Проверим конфигурацию ядра:

```bash
[root@ansible Ansible]# ansible web -m command -a "uname -r"
[WARNING]: Found both group and host with same name: web

web | CHANGED | rc=0 >>
3.10.0-957.12.2.el7.x86_64
```

Проверим статус файрвола (*iptables*):

```bash
[root@ansible Ansible]# ansible web -m systemd -a name=firewalld
[WARNING]: Found both group and host with same name: web

web | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "name": "firewalld",
    "status": {
        "ActiveEnterTimestampMonotonic": "0",
        "ActiveExitTimestampMonotonic": "0",
        "ActiveState": "inactive",
```

Проверим наличие репозитория **epel-release** и если его нет,то произведем его установку:

```bash
[root@ansible Ansible]# ansible web -m yum -a "name=epel-release state=present" -b
[WARNING]: Found both group and host with same name: web

web | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
```

Создаем простой плейбук в котором прописываем установку **epel-release**. Создадим в каталоге **/Ansible** каталог **provision** в котором будут размещаться наши плейбуки. В каталоге **/Ansible/provision** создадим файл epel.yml со следующим содержимым:

```bash
---
-name: Install EPEL Repo
 hosts: web
 become: true
 tasks:
   -name: Install EPEL Repo package from standard repo
    yum:
      name: epel-release
      state: present
...
```

Запустим плейбук на исполнение:

```bash
[root@ansible Ansible]# ansible-playbook ./provision/epel.yml
[WARNING]: Found both group and host with same name: web


PLAY [Install EPEL Repo] ***********************************************************************************************

TASK [Gathering Facts] *************************************************************************************************
ok: [web]

TASK [Install EPEL Repo package from standard repo] ********************************************************************
ok: [web]

PLAY RECAP *************************************************************************************************************
web                        : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Создаем плейбук для установки **NGINX**. В каталоге **/Ansible/provision** создадим файл nginx.yml со следующим содержимым:

```bash
---
- name: NGINX | Install and configure NGINX
  hosts: web
  become: true

  tasks:
    - name: NGINX | Install EPEL Repo package from standart repo
      yum:
        name: epel-release
        state: present
      tags:
        - epel-package
        - packages

    - name: NGINX | Install NGINX package from EPEL Repo
      yum:
        name: nginx
        state: latest
      tags:
        - nginx-package
        - packages
```

Добавим шаблон для конфигурации **NGINX** и модуль который будет копировать этот шаблон на хост.

```bash
---
- name: NGINX | Install and configure NGINX
  hosts: web
  become: true

  tasks:
    - name: NGINX | Install EPEL Repo package from standart repo
      yum:
        name: epel-release
        state: present
      tags:
        - epel-package
        - packages

    - name: NGINX | Install NGINX package from EPEL Repo
      yum:
        name: nginx
        state: latest
      tags:
        - nginx-package
        - packages

    - name: NGINX | Create NGINX config file from template
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify:
        - reload nginx
      tags:
        - nginx-configuration
...
```

Добавим в плэйбук необходимую переменную чтобы **NGINX** слушал на нестандартном порту 8080.

```bash
---
- name: NGINX | Install and configure NGINX
  hosts: web
  become: true
  vars:
   nginx_listen_port: 8080

  tasks:
    - name: NGINX | Install EPEL Repo package from standart repo
      yum:
        name: epel-release
        state: present
      tags:
        - epel-package
        - packages

    - name: NGINX | Install NGINX package from EPEL Repo
      yum:
        name: nginx
        state: latest
      tags:
        - nginx-package
        - packages

    - name: NGINX | Create NGINX config file from template
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      tags:
        - nginx-configuration
...
```

В каталоге **/Ansible/provision** создаем каталог **templates** для хранения файлов шаблонов. И в этом каталоге создаем файл *nginx.conf.j2*

```bash
# {{ ansible_managed }}
events {
    worker_connections 1024;
}

http {
    server {
        listen       {{ nginx_listen_port }} default_server;
        server_name  default_server;
        root         /usr/share/nginx/html;

        location / {
        }
    }
}
```

Создаем в плейбук секцию ***handlers*** и добавляем в секции установки и конфигурирования **NGINX** соответствующие ***notyfi***

```bash
---
- name: NGINX | Install and configure NGINX
  hosts: web
  become: true
  vars:
   nginx_listen_port: 8080

  tasks:
    - name: NGINX | Install EPEL Repo package from standart repo
      yum:
        name: epel-release
        state: present
      tags:
        - epel-package
        - packages

    - name: NGINX | Install NGINX package from EPEL Repo
      yum:
        name: nginx
        state: latest
      notify:
        - restart nginx
      tags:
        - nginx-package
        - packages

    - name: NGINX | Create NGINX config file from template
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify:
        - reload nginx
      tags:
        - nginx-configuration

  handlers:
    - name: restart nginx
      systemd:
        name: nginx
        state: restarted
        enabled: yes

    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded
...
```

Запускаем получившийся плейбук:

```bash
[root@ansible ansible]# ansible-playbook provision/nginx.yml
[WARNING]: Found both group and host with same name: web


PLAY [NGINX | Install and configure NGINX] *****************************************************************************

TASK [Gathering Facts] *************************************************************************************************
ok: [web]

TASK [NGINX | Install EPEL Repo package from standart repo] ************************************************************
changed: [web]

TASK [NGINX | Install NGINX package from EPEL Repo] ********************************************************************
changed: [web]

TASK [NGINX | Create NGINX config file from template] ******************************************************************
changed: [web]

RUNNING HANDLER [restart nginx] ****************************************************************************************
changed: [web]

RUNNING HANDLER [reload nginx] *****************************************************************************************
changed: [web]

PLAY RECAP *************************************************************************************************************
web                        : ok=6    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Проверяем что у нас есть доступ к веб серверу по порту 8080

```bash
[vagrant@ansible ~]$ curl http://192.168.11.151:8080
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
  <title>Welcome to CentOS</title>
  <style rel="stylesheet" type="text/css">

        html {
        background-image:url(img/html-background.png);
        background-color: white;
        font-family: "DejaVu Sans", "Liberation Sans", sans-serif;
        font-size: 0.85em;
        line-height: 1.25em;
        margin: 0 4% 0 4%;
        }
```
