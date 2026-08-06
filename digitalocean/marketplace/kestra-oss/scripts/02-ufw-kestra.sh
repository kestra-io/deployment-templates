#!/bin/sh

# DigitalOcean Marketplace Image Validation Tool
# Adapted from digitalocean/marketplace-partners scripts/02-ufw-nginx.sh:
# opens Kestra's web UI port instead of Nginx.

ufw limit ssh
ufw allow 8080/tcp

ufw --force enable
