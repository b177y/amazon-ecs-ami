#!/usr/bin/env bash
set -ex

sudo systemctl enable amazon-ssm-agent
sudo systemctl disable --now docker.service docker.socket
