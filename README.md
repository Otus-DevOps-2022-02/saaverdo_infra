![otus checks ](https://github.com/Otus-DevOps-2022-02/saaverdo_infra/actions/workflows/run-tests-2022-02.yml/badge.svg)
![validation checks ](https://github.com/Otus-DevOps-2022-02/saaverdo_infra/actions/workflows/run-checks.yml/badge.svg)

# saaverdo_infra
saaverdo Infra repository

## Task 11 Ansible - 4

#### предварительные ласки с `Vagrant`
Из нового - блок настроек `provision` для ansible, где задаём группу из inventory и передаём через `extra_vars` имя пользователя

```
  app.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/site.yml"
      ansible.groups = {
          "app" => ["appserver"],
          "app:vars" => {"db_host" => "10.10.10.10"}
      }
      ansible.extra_vars = {
          "deploy_user" => "vagrant"
      }
```

#### Собственно, тестирование роли

Создадим заготовку тестов для роли `db`
Перейдём для начала в папку роли `cd roles/db` и запустим:

```
molecule init scenario --scenario-name default -r db -d vagrant
```

Ага, щазз

```
molecule init scenario -r db
```

> (venv) serg@vagrant:~/otus/saaverdo_infra/ansible/roles/db$ molecule init scenario -r db
> INFO     Initializing new scenario default...
> INFO     Initialized scenario in /home/serg/otus/saaverdo_infra/ansible/roles/db/molecule/default successfully.

~~Другое дело!~~ всё равно хрень получается ((
И вот почему:
Согдасно документации (https://molecule.readthedocs.io/en/latest/installation.html)

> Molecule uses the “delegated” driver by default

Поэтому драйвер `molecule-vagrant` надо устанавливать отдельно

```
pip install molecule-vagrant
```

Вот теперь почистим ~~чакры~~ следы нашего безобразия и сделаем `molecule init` заново

```
molecule init scenario --scenario-name default -r db -d vagrant
```


Добавляем тесты `TestInfra` в `db/molecule/default/tests/test_default.py`

```
import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')

# check if MongoDB is enabled and running
def test_mongo_running_and_enabled(host):
    mongo = host.service("mongod")
    assert mongo.is_running
    assert mongo.is_enabled

# check if configuration file contains the required line
def test_config_file(host):
    config_file = host.file('/etc/mongod.conf')
    assert config_file.contains('bindIp: 0.0.0.0')
    assert config_file.is_file
```

теперь отредактируем `db/molecule/default/molecule.yml`

```
---
dependency:
  name: galaxy
driver:
  name: vagrant
  provider:
    name: virtualbox
lint:
  name: yamllint
platforms:
  - name: instance
    box: ubuntu/xenial64
provisioner:
  name: ansible
lint: |
  ansible-lint
verifier:
  name: testinfra
```

После чего выполняем команду `molecule create`
Получить список созданных `molecule` инстансов - `molecule list`
Подключиться к созданной при этом VM можно командой `molecule login -h instance`
Molecule прни этом генерит плейбуку для запуска тестов - `db/molecule/default/converge.yml`
Добавляем в него опцию `become: true` и переменную `mongo_bind_ip: 0.0.0.0`

#### Добавляем проверку
Проверим, слушает ли система на порту 27017.
Добавим  функцию в `db/molecule/default/tests/test_default.py`
Предложенный в лекции пример использует устаревшую конструкцию, поэтому покурив документацию получим:

```
def test_socket_listening(host):
    socket = host.socket('tcp://0.0.0.0:27017')
    assert socket.is_listening
```

Выполняем `molecule converge` и `molecule verify`

> ============================= test session starts ==============================
> platform linux -- Python 3.8.10, pytest-7.1.2, pluggy-1.0.0
> rootdir: /home/serg
> plugins: testinfra-6.0.0, testinfra-6.7.0
> collected 3 items
>
> molecule/default/tests/test_default.py ...                               [100%]
>
> ============================== 3 passed in 3.47s ===============================

Уря!)


### Links

Модули `TestInfra`
https://testinfra.readthedocs.io/en/latest/modules.html




## Task 10 Ansible - 3

#### Начинаем использовать роли

создаём роли командой `ansible-galaxy roles\<role_name>`

в `group_vars` могут лежать файлы без расширения - главное чтоб название соответствовало группе хостов
как то в `all`:

> env: stage

для вывода `diff` в случае если таска `changed` можем довавить в `ansible.cfg` такую секцию:

> [diff]
> # enable output of diff if chsnges occured and it will contain 5  lines of context
> always = True
> context = 5

#### Работаем с community-ролями

Удобным и логичным будет разделить зависимости ролей по окружениям.
К примеру, ложим файл `requirements.yml` в `environments/stage/requirements.yml`:

```
- src: jdauphant.nginx
  version: v2.21.1
```

Для установки данной роли воспользуемся командой:

```
ansible-galaxy install -r environments/stage/requirements.yml
```

Чтобы не коммитить community-роли в своюб репу, её название стоит добавить в `.gitignore`

И не забудем добавить переменные, необходимые для внешней роли в соответствующие файлы `group_vars`


###  Шифруемся

Создадим файл `vault.key` с паролем:

```
(venv) ✔ ~/otus/saaverdo_infra/ansible [ansible-3 L|✚ 21…4]
openssl rand -base64 12 > ../../vault.key
```

и добавим в `ansible.cfg` строку:

> vault_password_file = ../../vault.key

Зашифруем файлы с кредами:

```
ansible-vault encrypt environments/prod/credentials.yml
ansible-vault encrypt environments/stage/credentials.yml
```

глянем:

> (venv) ✔ ~/otus/saaverdo_infra/ansible [ansible-3 L|✚ 21…4]
> 17:47 $ head -n2 environments/stage/credentials.yml
> $ANSIBLE_VAULT;1.1;AES256
> 39396539663532353937336465663335333435373761306436393532316263653737383966343639

Уря, всё зашифровано!


### ** try

Добавим ингридиенты по рецепту:

```
Необходимо, чтобы для коммитов в master и PR выполнялись
как минимум эти действия:
 * packer validate для всех шаблонов
 * terraform validate и tflint для окружений stage и prod
 * ansible-lint для плейбуков Ansible
 * в README.md добавлен бейдж с статусом билда
```

#### Нужно больше ~~золота~~ проверок!

По аналогии с файлом `run-tests-2022-02.yml` сделаем новый.

зададим критерий - реагировать на `push` и `pull_request` к ветке `main`

> name: Run checks for OTUS homework
>
> on:
>   push:
>     branches-ignore: main
>   pull_request:
>     branches-ignore: main

Укажем имя нашей задачи - `validate`

> jobs:
>   validate:
>     runs-on: ubuntu-latest

и первым делом включим в шаги (`steps`) `uses: actions/checkout@v2`
(Эта штука необходима!)

>     steps:
>     # Important: This sets up your GITHUB_WORKSPACE environment variable
>     - name: Checkout this repo
>       uses: actions/checkout@v2

Далее добавляем шаги с необходимыми проверками, по рецепту:

Для `tflint` укажем проверять директории `prod` и `stage`

>     - name: Check linting of Terraform files
>       uses: devops-infra/action-tflint@v0.3
>       with:
>         dir_filter: terraform/stage/,terraform/prod/

Для `terraform validate` кажем проверять директорю `terraform`

>     - name: Validate Terraform modules
>       uses: devops-infra/action-terraform-validate@v0.3
>       with:
>         dir_filter: terraform/

Но!
т.к. это требует указания кредов для подключения, а безопасного варианта для этого в публичной репе я не нашёл, этот кусок будет закомментирован. ((


Для `packer validate` укажем проверять шаблоны для наших ВМ и выполняться с флагом `-syntax-only`

>     - name: Validate Packer Template
>       uses: hashicorp/packer-github-actions@master
>       with:
>         command: validate
>         arguments: -syntax-only
>         target: packer/app.json packer/db.json packer/ubuntu16.json packer/ immutable.json
>

И для `ansible-lint` укажем проверять плейбуки в дяректории `ansible/playbooks/`

>     - name: Run ansible-lint
>       # replace `main` with any valid ref, or tags like `v6`
>       uses: ansible-community/ansible-lint-action@main
>       with:
>         path: ansible/playbooks/

#### Последний штрих - ~~вишенка~~бейджик ~~на тортик~~ в README.md

По документации добавим в `README.md` строку для бейджика в формате:

> ![example workflow](https://github.com/<OWNER>/<REPOSITORY>/actions/workflows/<WORKFLOW_FILE>/badge.svg)

В нашем случае это будут:

```
![otus checks](https://github.com/Otus-DevOps-2022-02/saaverdo_infra/actions/workflows/run-tests-2022-02.yml/badge.svg)
![validation checks](https://github.com/Otus-DevOps-2022-02/saaverdo_infra/actions/workflows/run-checks.yml/badge.svg)
```

#### Links 2-3-4

https://docs.github.com/en/actions/quickstart

тулза для `tflint`:
https://github.com/devops-infra/action-tflint

для `terraform`:
https://github.com/devops-infra/action-terraform-validate
https://github.com/hashicorp/setup-terraform
https://acloudguru.com/blog/engineering/how-to-use-github-actions-to-automate-terraform


тулза для `packer validate`:
https://github.com/marketplace/actions/packer-github-actions

тулза для `ansible-lint`:
https://github.com/ansible-community/ansible-lint-action
Этот линтер сломался, несите следующего:
https://github.com/barolab/action-ansible-lint

Adding a workflow status badge:
https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/adding-a-workflow-status-badge


## Task 9 Ansible - 2

В процессе создали плейбук, который впоследствии разбили на три отдельных.
Что ранее не использовал - объединение их в один с помощью `import_playbook`:

```
---
- import_playbook: db.yml
- import_playbook: app.yml
- import_playbook: deploy.yml
```

Также ansible можно использовать в качестве provisioner'а для packer.
В таком случае конструкцию

```
            "type": "shell",
            "script": "scripts/install_ruby.sh"
```

меняем на

```
            "type": "ansible",
            "playbook_file": "ansible/packer_app.yml"
```

И, поскольку я работаю из-под `WSL`, и packer `игнорирует !!` директиву `remote_user` в настройках ansible, необходимо указывать параметр `"user"` в секции с настройками ansible
(https://www.packer.io/plugins/provisioners/ansible/ansible)


```
    "provisioners": [
        {
            "type": "ansible",
            "playbook_file": "ansible/packer_app.yml",
            "user": "appuser"
        }
    ]
```

После успешной пересборки образов задеплоим наш сетап:

> ansible-playbook site.yml

> PLAY RECAP *************************************************************************************************************
> appserver                  : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
> dbserver                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0



## Task 8 Ansible - 1

Работаем с `ini` и `yaml` форматами inventory.

первый запуск плейбука прошул с результатом

> appserver                  : ok=2    changed=0

т.к. нужный репозиторий был склонирован ранее.
Поэтому пришлось удалить его командой

```
ansible app -m command -a 'rm -rf ~/reddit'
```

и прогнать плейбук заново - теперь модуль git отработал нормально.

#### динамический inventory (не для * просто интересно)

Не мудрствуя лукаво, воспользуемся штатным функционалом ansible вместо написания костылей.
Для работы inventory plugin'а `gcp_compute` установим модули python `requests` и `google-auth`
и создадим файл описания динамического inventory `inventory.gcp.yml`

> ---
> plugin: gcp_compute
> projects:
>   - black-machine-349109
> zones:
>   - "europe-west4-a"
> filters: []
> auth_kind: application

если укажем его в `ansible.cfg`

> [defaults]
> inventory = ./inventory.gcp.yml

то команда `ansible all -m ping` у нас успешно отрабатывает:

```
01:23 $ ansible all -m ping
34.141.154.183 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
35.204.135.181 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

Уря!
#### LINKS 2-3-4!

https://nklya.medium.com/%D0%B4%D0%B8%D0%BD%D0%B0%D0%BC%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%BE%D0%B5-%D0%B8%D0%BD%D0%B2%D0%B5%D0%BD%D1%82%D0%BE%D1%80%D0%B8-%D0%B2-ansible-9ee880d540d6

https://medium.com/@Temikus/ansible-gcp-dynamic-inventory-2-0-7f3531b28434

https://www.ansible.com/blog/dynamic-inventory-past-present-future


## Task 7 Terraform - 2

Для начала вспомним `Packer` и создадим образы `reddit-base-otus-db` и `reddit-base-otus-app`
создадим файлы `app.json` и `db.json` на базе `ubuntu16.json`
где в `provisioners` оставим по одному скрипту и зададим `image_name`

При запуске воспользуемся готовым файлом с переменными `variables.json`, а значение `image_description` переопределим в командной строке:

```
packer build -var 'image_description=reddit app' -var-file=variables.json app.json
packer build -var 'image_description=reddit db' -var-file=variables.json db.json
```

тут вылез один нюанс - при старте базового образа запускается автообновление и ломает всю картину.
поэтому добавим в начало скрипта `install_mongodb.sh` строчку:

```
sudo systemctl stop apt-daily.timer
```

Вот теперь - отработало без вопросов!


Далее, разбиваем конфигурацию на модули и выносим настройки в `main` и `stage`

```
~/otus/saaverdo_infra/terraform [terraform-2 L|✚ 5…5]
00:01 $ tree
.
├── files
│   ├── deploy.sh
│   └── puma.service
├── modules
│   ├── app
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── db
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── prod
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── stage
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
└── terraform.tfvars.example
```

#### remote backend
В качестве бекенда используем `gcs`.
Для этого создадим в `google cloud storage` bucket `tf-otus-state-bucket` и в нём две папки - `prod` и `stage`
и используем их для хранения state'а. Настройки вынесем в файл `backend.tf`:

> terraform {
>     backend "gcs" {
>       bucket = "tf-otus-state-bucket"
>       prefix = "prod"
>     }
> }

Выполним в `prod` и `stage` `terraform init`, затем -  `terraform plan`
И посмотрим на наш bucket:

```
~/otus/saaverdo_infra/terraform/prod [terraform-2 L|✚ 5…5]
00:13 $ terraform init
Initializing modules...
- app in ../modules/app
- db in ../modules/db
- vpc in ../modules/vpc

Initializing the backend...
```

```
00:01 $ gcloud alpha storage ls --recursive gs://tf-otus-state-bucket/**
gs://tf-otus-state-bucket/prod/
gs://tf-otus-state-bucket/prod/default.tfstate
gs://tf-otus-state-bucket/stage/
gs://tf-otus-state-bucket/stage/default.tfstate
```

Уря!!!
У нас используется remote backend!

#### Let's deploy all!

Добавим `provisioner` для запуска приложения и реализуем его запуск через переменную - флаг `deploy_app`
Объявим её в `variables`:

```
variable "deploy_app" {
  description = "Enable app provisioning flag"
  type = bool
  default = false
}
```

Я не нашёл культурного способа звдвть условие для части скрипта в terraform, поэтому для того, чтобы завязаться на эту переменную вынесем секцию с `provisioner-ами` в отдельный ресурс `"null_resource` и воспользуемся конструкцией:

> count = var.deploy_app ? 1 : 0

кроме того, пришлось указать в модуле пути к файлам относительно директорий с tf-скриптами (stage, prod) что мне не нравится, но иначе не заработало (

> source      = "../modules/app/files/puma.service"

Для задания переменной окружения `DATABASE_URL` для приложения создал шаблон service-файла, где указал `DATABASE_URL` как переменную окружения для сервиса:

> Environment="DATABASE_URL=${db_url}:27017"

Теперь для запуска с деплоем приложения достаточно для модуля `app` в переменных указать `deploy_app = true` (прописано для `prod`)




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
