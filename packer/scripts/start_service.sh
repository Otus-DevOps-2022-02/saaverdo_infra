#!/bin/bash
chmod 644 /etc/systemd/system/reddit.service
systemctl daemon-reload
systemctl enable reddit.service
