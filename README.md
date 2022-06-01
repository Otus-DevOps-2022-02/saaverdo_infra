# saaverdo_infra
saaverdo Infra repository

## Task 6 Terraform - 1

Отработали создание VM с помошью `Terraform`

Из нюансов: т.к. ssh-ключ я создавал с паролем, для его использования через ssh agent в секции `connection` надо выставлять `agent = true`
Иначе получаем ошибку у `provisioner'ов`:

```
Failed to parse ssh private key: ssh: this private key is passphrase protected
```

И т.к. параметр `agent = true` конфликтует с явным указанием `private_key`, последний параметр необходимо закомментировать.


## Task 5 Packer

для доступа к веб-морде нашего приложения создадим разрешающее правило для брандмауэра:

    gcloud compute firewall-rules create allow-puma-reddit --allow tcp:9292

Необходимые параметны вынесем в файл `variables.json` и создадим образ с установленными `ruby` и `mongodb`:

```
packer build -var-file=variables.json -var 'source_image=ubuntu-pro-1604-xenial-v20211213' -var 'project_id=black-machine-349109' ubuntu16.json
```

(`image_name` был зафиксирован, чтобы на него сслылаться в следующем образе)

create-reddit-vm.sh

#### Bake them all

Теперь на основе ранее созданного образа запечём новый, со всей начинкой - установим приложение и добавим systemd unit для его запуска.
Шаблон будет называться `immutable.json`

```
packer build -var-file=variables.json -var 'source_image=reddit-base-otus-w-hw5' -var 'project_id=black-machine-349109' -var 'image_description=full reddit app' ubuntu16.json
```

Создать ВМ со свежезапечённым образом с хрустящей корочкой можно запустив скрипт `create-reddit-vm.sh` в директории scripts/

#### Links
https://www.packer.io/plugins/builders/googlecompute
https://www.packer.io/docs/templates/legacy_json_templates/user-variables


## Task 4 deploy test app

testapp_IP = 34.141.209.116
testapp_port = 9292

### Создание ВМ
gcloud compute instances create \
  --boot-disk-size=10GB \
  --image=ubuntu-pro-1604-xenial-v20211213 \
  --image-project=ubuntu-os-pro-cloud \
  --machine-type=e2-medium \
  --tags puma-server --restart-on-failure \
  --zone=europe-west4-a reddit-app

### Установка приложения:

<details>
<summary>Установка ruby - `install_ruby.sh`</summary>

```
#!/bin/bash
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
```

</details>


<details>
<summary>Установка mongo - install_mongodb.sh</summary>

```
#!/bin/bash
wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl enable mongod --now
```

</details>

<details>
<summary>Установка и запуск приложения - deploy.sh</summary>

```
#!/bin/bash
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
puma -d
```

</details>


#### Запуск ВМ с Startup script
И вишенка - при создании ВМ деплоим в него прложение с помощью startup скрипта.
Для этого в команду запуска добавляем:
`--metadata-from-file=startup-script=startup_deploy.sh`

```
gcloud compute instances create \
  --boot-disk-size=10GB \
  --image=ubuntu-pro-1604-xenial-v20211213 \
  --image-project=ubuntu-os-pro-cloud \
  --machine-type=e2-medium \
  --metadata-from-file startup-script=startup_deploy.sh \
  --tags puma-server --restart-on-failure \
  --zone=europe-west4-a reddit-app
```

при этом надо будет подождать некоторое время, пока отработает скрипт

```
time ./startup_deploy.sh
real    1m4.081s
user    0m40.758s
sys     0m12.016s
```


<details>
<summary>Task 3</summary>

## Task 3 bastion homework

bastion_IP = 34.90.49.16
someinternalhost_IP = 10.164.0.5

pritunl TLS - enabled (Let's Encrypt)
url: https://bastion.bsvv.pp.ua

### connect to internal host in one line:
First we tried to connect to the internal host using `SSH Agent Forwarding` (`-A` key):

> $ ssh -i ~/.ssh/appuser -A appuser@34.90.49.16
> appuser@bastion:~$ ssh 10.164.0.5
> appuser@someinternalhost:~$

It works, but It isn't perfect.

#### Let's dive
тут мне надоело писать на английском. ну, почти )

Воспользуемся `ProxyJump` ssh option:

    ssh -i ~/.ssh/appuser -J appuser@34.90.49.16 appuser@10.164.0.5

> Welcome to Ubuntu 20.04.4 LTS (GNU/Linux 5.13.0-1024-gcp x86_64)
>
> <output omitted>
>
> Last login: Tue May 24 00:09:07 2022 from 10.164.0.4
> appuser@someinternalhost:~$

Т.к. мы используем то же имя для подключения к someinternalhost, его можно не указывать.
good, but not perfect

#### Let's go deeper
Теперь воспользуемся файлом  `~/.ssh/config` где опишем хосты `bastion` и `someinternalhost`

```
touch ~/.ssh/config

cat <<EOF> ~/.ssh/config
## bastion
Host bastion
  HostName 34.90.49.16
  User appuser
  IdentityFile ~/.ssh/appuser

## internal host
Host someinternalhost
  HostName 10.164.0.5
  User appuser
  ProxyJump bastion
EOF
```

Тот же результат можно получить выполнив файл `setupproxyjump.sh`

Теперь возможно подключиться к `someinternalhost (10.164.0.5)` одной короткой командой:

    ssh someinternalhost

> 03:59 $ ssh someinternalhost
> Welcome to Ubuntu 20.04.4 LTS (GNU/Linux 5.13.0-1024-gcp x86_64)
>
> <output omitted>
>
> Last login: Tue May 24 00:22:34 2022 from 10.164.0.4
> appuser@someinternalhost:~$


### We can go even more deeper...

С лёгким приступом нашей паранои для реализации `jump-host` запустим дополнительный ssh-сервис на нестандартном порту.
Стандартный ма оставим для административного доступа (мало ли, обновление какое сломает второй ssh, а так стандартный останется)
А дополнительный повесим на порт `22822` и запретим `appuser` логиниться непосредственно на `bastion`.

```
# создадим конфиг для нового ssh-сервиса
cp /etc/ssh/sshd{,-second}_config
sed -i -E "s/Port.+/Port 22822/g" /etc/ssh/sshd-second_config
cat <<EOF>> /etc/ssh/sshd-second_config
Match User appuser
       X11Forwarding no
       AllowTcpForwarding yes
       PermitTTY no
       ForceCommand /bin/false
EOF

# скопируем systemd.service файл
cp /usr/lib/systemd/system/ssh.service  /etc/systemd/system/sshd-second.service
sed -i -E "s/Description=.+/Description=OpenBSD Secure Shell server second instance/g" /etc/systemd/system/sshd-second.service
sed -i -E 's/ExecStart=.+/ExecStart=\/usr\/sbin\/sshd -D -f \/etc\/ssh\/sshd-second_config $SSHD_OPTS/g' /etc/systemd/system/sshd-second.service
sed -i -E "s/Alias=.+/Alias=sshd-second.service/g" /etc/systemd/system/sshd-second.service
# и перезапустим демона
systemctl enable sshd-second.service
systemctl restart sshd-second.service
```
Проверяем:

    $ ssh -i ~/.ssh/appuser appuser@34.90.49.16 -p 22822

> PTY allocation request failed on channel 0
> Connection to 34.90.49.16 closed.

    ssh -i ~/.ssh/appuser -J appuser@34.90.49.16:22822 appuser@10.164.0.5

> Welcome to Ubuntu 20.04.4 LTS (GNU/Linux 5.13.0-1024-gcp x86_64)
>
> <output omitted>
>
> appuser@someinternalhost:~$

Работает!

теперь можно модифицировать  `~/.ssh/config` для удобства

```
cat <<EOF> ~/.ssh/config
## bastion
Host bastion
  HostName 34.90.49.16
  User appuser
  Port 22822
  IdentityFile ~/.ssh/appuser

## internal host
Host someinternalhost
  HostName 10.164.0.5
  User appuser
  ProxyJump bastion
EOF
```

### to be done...
запретить логин юзеру `appuser` на  ssh сервис на стандартном порту

### Links
https://www.redhat.com/sysadmin/ssh-proxy-bastion-proxyjump
https://linuxize.com/post/using-the-ssh-config-file/
https://man.openbsd.org/OpenBSD-current/man5/ssh_config.5
https://man.openbsd.org/OpenBSD-current/man5/sshd_config.5
https://access.redhat.com/solutions/1166283
</details>
