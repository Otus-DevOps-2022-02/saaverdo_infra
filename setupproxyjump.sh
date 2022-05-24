#!/bin/bash
# adds jump host setup to ssh config

write_ssh_config(){
cat <<EOF>> ~/.ssh/config
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
}

touch ~/.ssh/config
if [[ -s ~/.ssh/config ]]; then
  if [[ $1 == "-f" ]]; then
    write_ssh_config
    exit 0
  else
    echo "ssh config already exist and wouldn't be written"
    echo 'To alter ssh config use "-f" key'
    exit 1
  fi
fi
write_ssh_config
