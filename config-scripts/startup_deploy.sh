#!/bin/bash

echo "install ruby"
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential

echo "install mongo"
wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl enable mongod --now

echo "deploy app"
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
puma -d

APP=$(ps aux | grep puma | grep tcp)
if [[ -z $APP ]]; then
    echo "Oops... something get wrong"
    exit 1
else
    echo "App is running"
fi
