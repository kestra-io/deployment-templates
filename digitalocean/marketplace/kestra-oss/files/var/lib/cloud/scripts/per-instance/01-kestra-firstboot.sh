#!/bin/bash
set -o errexit

# Runs once, on this specific Droplet's first boot (cloud-init per-instance
# script). Generates the Postgres and Kestra basic-auth credentials here,
# not at image-build time, so every Droplet created from this snapshot gets
# its own unique secrets instead of sharing one baked into the image.

KESTRA_ADMIN_USERNAME="admin@kestra.local"
KESTRA_ADMIN_PASSWORD=$(gpg --gen-random --armor 2 18)
POSTGRES_PASSWORD=$(gpg --gen-random --armor 2 18)

cat > /opt/kestra/.env <<EOF
KESTRA_ADMIN_USERNAME=${KESTRA_ADMIN_USERNAME}
KESTRA_ADMIN_PASSWORD=${KESTRA_ADMIN_PASSWORD}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF
chmod 600 /opt/kestra/.env

DROPLET_IP=$(curl -fsSL http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address || echo "<your-droplet-ip>")

cat > /root/.digitalocean_kestra_credentials <<EOF
kestra_url=http://${DROPLET_IP}:8080
kestra_username=${KESTRA_ADMIN_USERNAME}
kestra_password=${KESTRA_ADMIN_PASSWORD}
EOF
chmod 600 /root/.digitalocean_kestra_credentials

systemctl enable --now kestra.service
