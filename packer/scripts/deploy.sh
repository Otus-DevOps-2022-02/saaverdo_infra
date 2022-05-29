#!/bin/bash
mkdir -p /home/appuser/reddit
git clone -b monolith https://github.com/express42/reddit.git /home/appuser/reddit
cd /home/appuser/reddit && bundle install
