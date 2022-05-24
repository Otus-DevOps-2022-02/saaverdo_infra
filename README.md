# saaverdo_infra
saaverdo Infra repository


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
