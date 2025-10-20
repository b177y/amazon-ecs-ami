#!/usr/bin/env bash
set -ex

sudo yum install -y iptables
sudo modprobe nf_tables

sudo useradd ecs-rootless
sudo loginctl enable-linger ecs-rootless

sudo su -l ecs-rootless -c "mkdir /home/ecs-rootless/.ssh && touch /home/ecs-rootless/.ssh/authorized_keys"
sudo su -l ecs-rootless -c "cat >> \$HOME/.bashrc <<EOF
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock
EOF"
sudo su -l ecs-rootless -c "curl -fsSL https://get.docker.com/rootless | sh"
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose


sudo su -l ecs-rootless -c "mkdir -p ~/.local/share/ecs-agent"
sudo su -l ecs-rootless -c "cat >> \$HOME/.local/share/ecs-agent/docker-compose.yml <<EOF
services:
  ecs-agent:
    container_name: ecs-agent
    init: true
    image: amazon/amazon-ecs-agent:latest
    restart: on-failure:10
    volumes:
      - /run/user/\$(id -u)/docker.sock:/var/run/docker.sock
      - /home/ecs-rootless/log/ecs:/log
      - /home/ecs-rootless/data:/data
    network_mode: host
    env_file: /etc/ecs/ecs.config
    environment:
      ECS_LOGFILE: /log/ecs-agent.log
      ECS_DATADIR: /data/
      ECS_ENABLE_TASK_ENI: true
      ECS_ENABLE_TASK_IAM_ROLE: true
      ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST: true
      ECS_AVAILABLE_LOGGING_DRIVERS: '[\"json-file\",\"awslogs\",\"syslog\",\"none\"]'
EOF"

sudo su -l ecs-rootless -c "cat >> \$HOME/.config/systemd/user/ecs-agent.service <<EOF
[Unit]
Description=ECS Agent With Rootless Docker
PartOf=docker.service
After=docker.service

[Service]
Environment=DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/home/ecs-rootless/.local/share/ecs-agent
ExecStart=/home/ecs-rootless/bin/docker compose up -d --remove-orphans
ExecStop=/home/ecs-rootless/bin/docker compose down

[Install]
WantedBy=default.target
EOF"
sudo su -l ecs-rootless -c "systemctl --user daemon-reload"
sudo su -l ecs-rootless -c "systemctl --user enable --now ecs-agent"
