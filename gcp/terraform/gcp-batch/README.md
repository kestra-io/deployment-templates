# Terraform GCP Batch and Cloud Run Infrastructure

This Terraform module provisions the Google Cloud resources needed by Kestra's Google Batch task runner and Cloud Run task runner: the required APIs, a GCS staging bucket, service accounts and IAM roles. It does not create a Kestra deployment, it only prepares your project so you can offload tasks to GCP.

## Prerequisites

- Terraform installed (v1.5+ recommended)
- gcloud CLI authenticated with a user or service account that can enable APIs, create service accounts and manage IAM in the project (for example `gcloud auth application-default login`)
- A GCP project with billing enabled

## Resources Created

- **Project APIs:** Batch, Compute Engine, IAM, Cloud Logging, Cloud Run and Cloud Storage.
- **GCS Bucket:** a staging bucket used by both runners for input and output files.
- **Kestra Service Account:** `kestra-task-runner`, used by Kestra to call the APIs. It gets Batch Jobs Editor, Cloud Run Developer, Logs Viewer and Storage Object Admin on the bucket.
- **Cloud Run Runtime Service Account:** `kestra-cloud-run-runtime`, the identity of the Cloud Run job containers. It gets Storage Object User on the bucket and Logs Writer. The Kestra service account can act as it.
- **Batch VM permissions:** Google Batch VMs run as the Compute Engine default service account. The module lets the Kestra service account act as it and grants it Batch Agent Reporter, Logs Writer and Storage Object Admin on the bucket.

## Usage

1. **Configuration:** copy the example variables file and set your values:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Initialization:**

   ```bash
   terraform init
   ```

3. **Planning:**

   ```bash
   terraform plan
   ```

4. **Apply Configuration:**

   ```bash
   terraform apply
   ```

5. **Service account key:** the Kestra service account needs a JSON key for the serviceAccount property. Create one yourself:

   ```bash
   gcloud iam service-accounts keys create key.json --iam-account=$(terraform output -raw kestra_service_account_email)
   ```

   Or set `create_service_account_key = true` and read it with `terraform output -raw kestra_service_account_key`. The key is then stored in the Terraform state, so protect the state accordingly.

## Using the Outputs in Kestra

Google Batch task runner:

```yaml
id: gcp_batch
namespace: company.team

tasks:
  - id: shell
    type: io.kestra.plugin.scripts.shell.Commands
    taskRunner:
      type: io.kestra.plugin.ee.gcp.runner.Batch
      projectId: my-gcp-project
      region: europe-west2
      bucket: my-kestra-task-runner-bucket
      serviceAccount: "{{ secret('GOOGLE_SA') }}"
    commands:
      - echo "Hello from Google Batch"
```

Cloud Run task runner:

```yaml
id: gcp_cloud_run
namespace: company.team

tasks:
  - id: shell
    type: io.kestra.plugin.scripts.shell.Commands
    taskRunner:
      type: io.kestra.plugin.ee.gcp.runner.CloudRun
      projectId: my-gcp-project
      region: europe-west2
      bucket: my-kestra-task-runner-bucket
      serviceAccount: "{{ secret('GOOGLE_SA') }}"
      runtimeServiceAccount: kestra-cloud-run-runtime@my-gcp-project.iam.gserviceaccount.com
    commands:
      - echo "Hello from Cloud Run"
```

Both runners are Kestra Enterprise features.

## Customization

- **Network:** Google Batch uses the default VPC of the project. If you do not have one, set networkInterfaces in the task runner. For Cloud Run, use the network, subnetwork or vpcAccessConnector properties.
- **Bucket:** `bucket_force_destroy` is false by default, set it to true if you want terraform destroy to remove a non-empty bucket.

## Cleanup

To remove the resources created by this module, use:

```bash
terraform destroy
```

## Support

For questions or issues regarding the use of this setup, reach out to us via Slack: https://kestra.io/slack
