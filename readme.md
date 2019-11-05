# **Введение**

Все ниже описанные действия производятся на компьютере с установленным `Windows 10`
Для выполнения работы потребуются следующие инструменты:

- **VirtualBox** - среда виртуализации, позволяет создавать и выполнять виртуальные машины;
- **Vagrant** - ПО для создания и конфигурирования виртуальной среды. В данном случае в качестве среды виртуализации используется *VirtualBox*;
- **Packer** - ПО для создания образов виртуальных машин;
- **Git** - система контроля версий

А так же аккаунты:

- **GitHub** - https://github.com/
- **Vagrant Cloud** - https://app.vagrantup.com


---
# **Установка ПО**

### **Vagrant**
Переходим на https://www.vagrantup.com/downloads.html выбираем соответствующую версию. В нашем случае Windows 64-bit и версия 2.2.6.
Запускаем файл установки vagrant 2.2.6_x86_64.msi

После успешного окончания будет установлен Vagrant.

### **Packer**
Переходим на https://www.packer.io/downloads.html выбираем соответствующую версию. В нашем случае Windows 64-bit и версия 1.4.4.
Добавляем packer в переменные среды для чего выбираем
```
Пуск/Служебные Windows/Панель управления/Система и безопасность\Система\Дополнительные параметры\Переменные среды
```
В системных переменных находим переменную 'Path' и жмем кнопку 'Изменить' Добавляем путь к папке с 'packer'

После этого Packer начинает запускаться в консоле без укзания точного пути расположения файла.

---

# **Kernel update**

### **Клонирование и запуск**

Для запуска рабочего виртуального окружения необходимо зайти через браузер в GitHub под своей учетной записью и выполнить `fork` данного репозитория: https://github.com/dmitry-lyutenko/manual_kernel_update

После этого данный репозиторий необходимо склонировать к себе на рабочую машину, для чего можно воспользоваться кнопкой 'Clone or download'.
Выбираем опцию 'Download ZIP' и сохраняем архив в директорию на локальном диске компьютера.
Распаковываем архив в текущей директории появится папка с именем репозитория. В данном случае `manual_kernel_update`.
В папке располагаются каталоги:
```
manual
packer
```
и файл
```
Vagrantfile
```
Здесь:
- `manual` - директория с руководством
- `packer` - директория со скриптами для `packer`'а
- `Vagrantfile` - файл описывающий виртуальную инфраструктуру для `Vagrant`

Запускаем виртуальную машину и логинимся:
```
vagrant up
...
==> kernel-update: Importing base box 'centos/7'...
...
==> kernel-update: Booting VM...
...
==> kernel-update: Setting hostname...

vagrant ssh
[vagrant@kernel-update ~]$ uname -r
3.10.0-957.12.2.el7.x86_64
```
Теперь приступим к обновлению ядра.

### **kernel update**


Подключаем репозиторий, откуда возьмем необходимую версию ядра.
```
sudo yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
```

В репозитории есть две версии ядер **kernel-ml** и **kernel-lt**. Первая является наиболее свежей стабильной версией, вторая это стабильная версия с длительной поддержкой, но менее свежая, чем первая. В данном случае ядро 5й версии будет в  **kernel-ml**.

Поскольку мы ставим ядро из репозитория, то установка ядра похожа на установку любого другого пакета, но потребует явного включения репозитория при помощи ключа ```--enablerepo```.

Ставим последнее ядро:

```
sudo yum --enablerepo elrepo-kernel install kernel-ml -y
```

### **grub update**
После успешной установки нам необходимо сказать системе, что при загрузке нужно использовать новое ядро. В случае обновления ядра на рабочих серверах необходимо перезагрузиться с новым ядром, выбрав его при загрузке. И только при успешно прошедших загрузке нового ядра и тестах сервера переходить к загрузке с новым ядром по-умолчанию. В тестовой среде можно обойти данный этап и сразу назначить новое ядро по-умолчанию.

Обновляем конфигурацию загрузчика:
```
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```
Выбираем загрузку с новым ядром по-умолчанию:
```
sudo grub2-set-default 0
```

Перезагружаем виртуальную машину:
```
sudo reboot
```

После перезагрузки виртуальной машины (3-4 минуты, зависит от мощности хостовой машины) заходим в нее и выполняем:

```
uname -r
```

---

# **Packer**
Теперь необходимо создать свой образ системы, с уже установленым ядром 5й версии. Для это воспользуемся ранее установленной утилитой `packer`. В директории `packer` есть все необходимые настройки и скрипты для создания необходимого образа системы.

### **packer provision config**
Файл `centos.json` содержит описание того, как произвольный образ. Полное описание можно найти в документации к `packer`. Обратим внимание на основные секции или ключи.

Создаем переменные (`variables`) с версией и названием нашего проекта (artifact):
```
    "artifact_description": "CentOS 7.7 with kernel 5.x",
    "artifact_version": "7.7.1908",
```

В секции `builders` задаем исходный образ, для создания своего в виде ссылки и контрольной суммы. Параметры подключения к создаваемой виртуальной машине.

```
    "iso_url": "http://mirror.yandex.ru/centos/7.7.1908/isos/x86_64/CentOS-7-x86_64-Minimal-1908.iso",
    "iso_checksum": "9a2c47d97b9975452f7d582264e9fc16d108ed8252ac6816239a3b58cef5c53d",
    "iso_checksum_type": "sha256",
```
В секции `post-processors` указываем имя файла, куда будет сохранен образ, в случае успешной сборки

```
    "output": "centos-{{user `artifact_version`}}-kernel-5-x86_64-Minimal.box",
```

В секции `provisioners` указываем каким образом и какие действия необходимо произвести для настройки виртуальой машины. Именно в этой секции мы и обновим ядро системы, чтобы можно было получить образ с 5й версией ядра. Настройка системы выполняется несколькими скриптами, заданными в секции `scripts`.

```
    "scripts" :
      [
        "scripts/stage-1-kernel-update.sh",
        "scripts/stage-2-clean.sh"
      ]
```
Скрипты будут выполнены в порядке указания. Первый скрипт включает себя набор команд, которые ранее были выполнены вручную, чтобы обновить ядро. Второй скрипт занимается подготовкой системы к упаковке в образ. Она заключается в очистке директорий с логами, временными файлами, кешами. Это позволяет уменьшить результирующий образ.

Секция `post-processors` описывает постобработку виртуальной машины при ее выгрузке. Мы указыаем имя файла, в который будет сохранен результат (artifact). Обратите внимание, что имя задается на основе ранее созданной пользовательской переменной `artifact_version` значение которой мы задали ранее:

```
    "output": "centos-{{user `artifact_version`}}-kernel-5-x86_64-Minimal.box",
```

### **packer build**
Для создания образа системы переходим в директорию `packer` и в ней выполняем команду:

```
packer build centos.json
```

Если все в порядке, то, согласно файла `config.json` будет скачан исходный iso-образ CentOS, установлен на виртуальную машину в автоматическом режиме, обновлено ядро и осуществлен экспорт в указанный нами файл. Если не вносилось изменений в предложенные файлы, то в текущей директории мы увидим файл `centos-7.7.1908-kernel-5-x86_64-Minimal.box`. Он и является результатом работы `packer`.

### **vagrant init (тестирование)**
Проведем тестирование созданного образа. Выполним его импорт в `vagrant`:

```
vagrant box add --name centos-7-5 centos-7.7.1908-kernel-5-x86_64-Minimal.box
```

Проверим его в списке имеющихся образов:

```
vagrant box list
centos-7-5            (virtualbox, 0)
```

Он будет называться `centos-7-5`, данное имя было задано в параметре `name` при импорте.

Теперь необходимо провести тестирование полученного образа. Для этого создадим новый Vagrantfile. Для нового создадим директорию `test` и в ней выполним:

```
vagrant init centos-7-5
```

Теперь запустим виртуальную машину, подключимся к ней и проверим, что у нас в ней новое ядро:

```
vagrant up
...
vagrant ssh
```

и внутри виртуальной машины:

```
[vagrant@kernel-update ~]$ uname -r
5.3.1-1.el7.elrepo.x86_64
```

Если все в порядке, то машина будет запущена и загрузится с новым ядром. В данном примере это `5.3.1`.

Удалим тестовый образ из локального хранилища:
```
vagrant box remove centos-7-5
```
---
# **Vagrant cloud**

Полученный образ заливаем в Vagrant Cloud. Можно залить через web-интерфейс, но так же `vagrant` позволяет это проделать через CLI.
Логинимся в `vagrant cloud`, указывая e-mail, пароль и описание выданого токена (можно оставить по-умолчанию)
```
vagrant cloud auth login
Vagrant Cloud username or email: <user_email>
Password (will be hidden):
Token description (Defaults to "Vagrant login from DS-WS"):
You are now logged in.
```
Теперь публикуем полученный бокс:
```
vagrant cloud publish --release <username>/centos-7-5 1.0 virtualbox \
        centos-7.7.1908-kernel-5-x86_64-Minimal.box
```
Здесь:
 - `cloud publish` - загрузить образ в облако;
 - `release` - указывает на необходимость публикации образа после загрузки;
 - `<username>/centos-7-5` - `username`, указаный при публикации и имя образа;
 - `1.0` - версия образа;
 - `virtualbox` - провайдер;
 - `centos-7.7.1908-kernel-5-x86_64-Minimal.box` - имя файла загружаемого образа;

После успешной загрузки получаем сообщение:

```
Complete! Published <username>/centos-7-5
tag:             <username>/centos-7-5-cli
username:        <username>
name:            centos-7-5
private:         false
...
providers:       virtualbox
```

В результате создан и загружен в `vagrant cloud` образ созданной виртуальной машины.
