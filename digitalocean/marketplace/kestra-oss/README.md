# Kestra OSS — DigitalOcean Marketplace image

Packer template that builds a DigitalOcean Marketplace 1-Click Droplet image for Kestra OSS, following the process documented in [digitalocean/marketplace-partners](https://github.com/digitalocean/marketplace-partners).

## What the image contains

- Ubuntu 24.04 LTS base
- Docker Engine + the `docker compose` plugin
- A `docker compose` stack at `/opt/kestra/` running Kestra OSS (pinned version, see `kestra_version` variable) with a bundled Postgres 16 container as the repository/queue backend and local disk storage — self-contained, no external managed database required
- `ufw` enabled, allowing SSH (rate-limited) and port `8080` (Kestra web UI)

Kestra's basic-auth password and the Postgres password are **not** baked into the image. They're generated per-Droplet by a cloud-init first-boot script (`files/var/lib/cloud/scripts/per-instance/01-kestra-firstboot.sh`), which also writes them to `/root/.digitalocean_kestra_credentials` and starts the `kestra.service` systemd unit. A message-of-the-day entry points users at that credentials file on login.

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/install)
- A [DigitalOcean personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) exported as `DIGITALOCEAN_TOKEN`

## Build

```bash
export DIGITALOCEAN_TOKEN=your_token_here
packer init marketplace-image.json   # first run only, installs the digitalocean plugin
packer build marketplace-image.json
```

This creates a build Droplet, provisions it, runs DigitalOcean's official cleanup (`scripts/90-cleanup.sh`) and image validation (`scripts/99-img-check.sh`) scripts unmodified, then powers it down and snapshots it. Review the `[WARN]`/`[FAIL]` output from `99-img-check.sh` before submitting the image — see the [marketplace-partners README](https://github.com/digitalocean/marketplace-partners#build-automation-with-packer) for what's expected.

Override any variable with `-var`, e.g. to build in a different region or pin a different Kestra release:

```bash
packer build -var 'region=fra1' -var 'kestra_version=v1.3.30' marketplace-image.json
```

## Note on Droplet size

DigitalOcean recommends building on their smallest ($6) Droplet so the resulting snapshot works across all Droplet sizes. This template builds on `s-1vcpu-2gb` instead: Kestra's JVM needs more than 1GB of RAM to complete provisioning reliably. The built image itself has no size restriction baked in, but a 1GB Droplet is not expected to run Kestra well — call this out in the Marketplace listing's minimum requirements when submitting.

## Submitting the image

Building and snapshotting is fully automated by this template, but publishing is not: submit the resulting snapshot through DigitalOcean's [Vendor Portal](https://cloud.digitalocean.com/vendorportal) (or the Vendor API for updates to an already-published listing — see the marketplace-partners README).
