#!/bin/bash
set -e

apt-get update
apt-get install -y docker.io
systemctl start docker
systemctl enable docker

usermod -aG docker ${admin_username}

mkdir -p /home/${admin_username}/config

cat <<EOF > /home/${admin_username}/config/application-azure-vm.yml
datasources:
  postgres:
    url: jdbc:postgresql://${db_host}:5432/${db_name}
    driverClassName: org.postgresql.Driver
    username: ${db_admin}
    password: ${db_password}

kestra:
  server:
    basic-auth:
      enabled: true
      username: admin@kestra.io
      password: ${kestra_password}
  repository:
    type: postgres
  queue:
    type: postgres
  storage:
    type: azure
    azure:
      endpoint: https://${storage_account_name}.blob.core.windows.net
      container: ${storage_container_name}
      connection-string: "DefaultEndpointsProtocol=https;AccountName=${storage_account_name};AccountKey=${storage_account_key};EndpointSuffix=core.windows.net"
  tasks:
    tmp-dir:
      path: "/tmp/kestra-wd/tmp"
EOF

chmod 600 /home/${admin_username}/config/application-azure-vm.yml

docker run --pull=always -d \
  -p 8080:8080 \
  --user=root \
  --restart=always \
  -e MICRONAUT_ENVIRONMENTS=application-azure-vm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/${admin_username}/config/application-azure-vm.yml:/etc/config/application-azure-vm.yml \
  --name kestra \
  ${kestra_image} server standalone --config /etc/config/application-azure-vm.yml
