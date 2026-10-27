# Kestra OSS on Azure with Terraform

This Terraform configuration deploys a standalone Kestra OSS server on Azure with PostgreSQL Flexible Server, Azure Blob Storage, and managed HTTPS ingress. It can also deploy an optional API Management model gateway backed by Azure OpenAI.

## Prerequisites

- Terraform 1.5 or newer
- Azure CLI authenticated to the target subscription
- An SSH public key
- A trusted source IP address or CIDR for SSH and Kestra web access
- Permission to register the API Management, CDN, Cognitive Services, Compute, Insights, Network, Storage, and PostgreSQL resource providers

## Resources created

- Resource group and virtual network
- VM and delegated PostgreSQL subnets
- Network security group restricted to the supplied source CIDR
- PostgreSQL Flexible Server with private networking
- Azure Storage account and private Blob container
- Ubuntu VM running Kestra in Docker
- Azure Front Door managed HTTPS endpoint
- Optional API Management model gateway, Azure OpenAI deployment, Application Insights, and Log Analytics workspace

Terraform generates a 256-bit Kestra encryption key by default so `SECRET` inputs and outputs are encrypted at rest. Set `kestra_encryption_key` to reuse an externally managed key when rebuilding or migrating an existing deployment.

The default `kestra_image` is pinned to an immutable release tag instead of the rolling `latest` tag. Test and set a newer exact version explicitly when upgrading.

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

Set `kestra_image` to a tested versioned image tag when upgrading. The default is pinned to `kestra/kestra:v1.3.33` for reproducible deployments.

The `kestra_url`, `ssh_command`, and `db_hostname` outputs are available after a successful apply. Initialization can take several minutes after the VM is created.

Azure Front Door is enabled by default so browsers can reach Kestra over managed HTTPS. Set `enable_front_door = false` to keep only the trusted-CIDR-restricted origin URL. Use `Premium_AzureFrontDoor` with a tuned WAF policy for production deployments that require managed WAF rule sets.

## Optional model gateway

Set `enable_model_gateway = true` to deploy a governed model-egress path for workflow AI calls:

```hcl
enable_model_gateway          = true
model_gateway_publisher_email = "platform-team@example.com"
```

The gateway requires an APIM subscription key, removes any caller-supplied Azure OpenAI API key, enforces a per-subscription request limit, injects a correlation ID, and authenticates to Azure OpenAI with its system-assigned managed identity. Subscription tracing is disabled. Application Insights and Log Analytics capture request metadata and dimensional token metrics without logging prompt or completion bodies, with a 1 GB daily Application Insights cap. Terraform uses the Microsoft AzAPI provider only for the Application Insights dimensional-metrics property and APIM diagnostic metrics switch that AzureRM does not currently expose.

Retrieve the generated endpoint and subscription key after apply:

```bash
terraform output -raw model_gateway_chat_completions_url
terraform output -raw model_gateway_subscription_key
```

The Kestra encryption key, database credentials, storage key, and model-gateway subscription key are sensitive Terraform state. Use encrypted remote state with restricted access and rotate credentials if state access is broadened. Preserve the Kestra encryption key when migrating existing encrypted executions.

`Consumption_0` is the default APIM validation tier. Use a supported non-Consumption tier for production controls that are unavailable in Consumption, including per-key token limits, and add an Azure AI Content Safety backend before enabling APIM's `llm-content-safety` policy. Azure OpenAI's deployment-level content filters remain active independently. Keep APIM on the workflow model-egress path only; Kestra UI, API, queue, and execution traffic stay on their normal paths.

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
