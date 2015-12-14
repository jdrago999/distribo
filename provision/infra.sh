#!/bin/bash

set -e

sudo apt-get -y update
sudo apt-get -y autoremove
sudo apt-get install -y ruby2.0 ruby2.0-dev build-essential git wget vim

if [ -f /etc/init.d/redis-server ]; then
  echo 'redis-server already installed'
else
  sudo apt-get install -y redis-server
fi

if grep -e "bind 0.0.0.0" /etc/redis/redis.conf; then
  echo "redis already willing to accept connections on 0.0.0.0"
else
  cat <<EOF | sudo tee -a /etc/redis/redis.conf
bind 0.0.0.0
EOF
fi

sudo service redis-server restart

if [ -d /data/rabbitmq ]; then
  echo "directory /data/rabbitmq already exists"
else
  sudo mkdir -p /data/rabbitmq
  sudo chmod 0777 -R /data/rabbitmq
  cat <<EOF | sudo tee -a /etc/bash.bashrc
export RABBITMQ_MNESIA_BASE=/data/rabbitmq
EOF
  sudo mkdir -p /etc/rabbitmq
  cat <<EOF | sudo tee /etc/rabbitmq/rabbitmq-env.conf
MNESIA_BASE=/data/rabbitmq
EOF
fi

if grep "www.rabbitmq.com" /etc/apt/sources.list; then
  echo "rabbitmq apt repository already in sources.list"
else
  cat <<EOF | sudo tee -a /etc/apt/sources.list
deb http://www.rabbitmq.com/debian/ testing main
EOF
  wget -O /tmp/rabbitmq-signing-key-public.asc https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
  sudo apt-key add /tmp/rabbitmq-signing-key-public.asc
fi

if which rabbitmqctl; then
  echo "rabbitmq already installed"
  sudo service rabbitmq-server start
else
  sudo apt-get update
  sudo apt-get install -y --force-yes rabbitmq-server
  sudo chown -R rabbitmq:rabbitmq /data/rabbitmq
  sudo service rabbitmq-server restart
  sudo rabbitmq-plugins enable rabbitmq_management
fi

if sudo rabbitmqctl list_users | grep $RABBITMQ_USERNAME; then
  echo "user '$RABBITMQ_USERNAME' already exists"
else
  sudo rabbitmqctl add_user $RABBITMQ_USERNAME $RABBITMQ_PASSWORD
fi

if sudo rabbitmqctl list_users | grep $RABBITMQ_USERNAME | grep -F "[administrator]"; then
  echo "user '$RABBITMQ_USERNAME' already tagged as 'administrator'"
else
  sudo rabbitmqctl set_user_tags $RABBITMQ_USERNAME administrator
fi

sudo rabbitmqctl set_permissions -p / $RABBITMQ_USERNAME ".*" ".*" ".*"

# Reset permissions back to rabbitmq:
if stat -c %U /data/rabbitmq | grep rabbitmq; then
  echo "/data/rabbitmq/ is already owned by rabbitmq"
else
  sudo chmod 0755 -R /data/rabbitmq
  sudo chown -R rabbitmq:rabbitmq /data/rabbitmq
fi
sudo wget -O /usr/bin/rabbitmqadmin http://localhost:15672/cli/rabbitmqadmin
sudo chmod +x /usr/bin/rabbitmqadmin