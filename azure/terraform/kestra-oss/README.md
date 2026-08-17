# Kestra OSS on Azure with Terraform

This Terraform configuration deploys a standalone Kestra OSS server on Azure with PostgreSQL Flexible Server and Azure Blob Storage.

## Prerequisites

- Terraform 1.5 or newer
- Azure CLI authenticated to the target subscription
- An SSH public key
- A trusted source IP address or CIDR for SSH and Kestra web access
- Permission to register the CDN, Compute, Network, Storage, and PostgreSQL resource providers

## Resources created

- Resource group and virtual network
- VM and delegated PostgreSQL subnets
- Network security group restricted to the supplied source CIDR
- PostgreSQL Flexible Server with private networking
- Azure Storage account and private Blob container
- Ubuntu VM running Kestra in Docker
- Azure Front Door managed HTTPS endpoint

## Deploy

```bash
terraform init
terraform plan \
  -var="subscription_id=<azure_subscription_id>" \
  -var="ssh_public_key=$(cat <path_to_public_key>)" \
  -var="postgres_password=<postgres_password>" \
  -var="kestra_password=<kestra_password>" \
  -var="authorized_source_ip=<trusted_ip_or_cidr>"
terraform apply \
  -var="subscription_id=<azure_subscription_id>" \
  -var="ssh_public_key=$(cat <path_to_public_key>)" \
  -var="postgres_password=<postgres_password>" \
  -var="kestra_password=<kestra_password>" \
  -var="authorized_source_ip=<trusted_ip_or_cidr>"
```

Use a `terraform.tfvars` file or environment variables for repeated deployments. Do not commit credentials or generated state.

Set `kestra_image` to a versioned image tag for reproducible production deployments. Its default remains `kestra/kestra:latest` for quick-start use.

The `kestra_url`, `ssh_command`, and `db_hostname` outputs are available after a successful apply. Initialization can take several minutes after the VM is created.

Azure Front Door is enabled by default so browsers can reach Kestra over managed HTTPS. Set `enable_front_door = false` to keep only the trusted-CIDR-restricted origin URL. Use `Premium_AzureFrontDoor` with a tuned WAF policy for production deployments that require managed WAF rule sets.

## Cleanup

```bash
terraform destroy \
  -var="subscription_id=<azure_subscription_id>" \
  -var="ssh_public_key=$(cat <path_to_public_key>)" \
  -var="postgres_password=<postgres_password>" \
  -var="kestra_password=<kestra_password>" \
  -var="authorized_source_ip=<trusted_ip_or_cidr>"
```

Destroy unused validation environments to avoid ongoing Azure charges.
