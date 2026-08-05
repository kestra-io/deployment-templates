# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Collection of independent Kestra deployment recipes across cloud providers. Not an app — no shared build, no shared runtime, no cross-module dependencies. Each subfolder is a standalone infra-as-code template a user copies/runs on its own cloud account. Changes to one module never affect another.

## Layout

```
aws/cloudformation/ec2-rds-s3/   CloudFormation template: EC2 + RDS Postgres + S3 (Kestra OSS on AWS)
aws/terraform/aws-batch/         AWS Batch (ECS Fargate) compute env + job queue, for Kestra's AWS Batch task runner
aws/terraform/aws-ec2/           EC2 + RDS + S3 via Terraform (alternative to the CloudFormation template above)
azure/arm-template/              Standalone ARM template, deploy directly via CLI/portal
azure/marketplace/               Same deployment repackaged for Azure Marketplace publishing (adds createUiDefinition.json + _artifactsLocation params required by the marketplace pipeline) — keep both in sync when changing the underlying VM deployment
azure/terraform/azure-batch/     Azure Batch node pool, for Kestra's Azure Batch task runner
azure/terraform/kestra-oss/      Kestra OSS on an Azure VM via Terraform
gcp/terraform/gcp-aiven/         Kestra on GCP with Aiven-managed data backend, two flavors:
  opensource/                      Kestra OSS + Aiven for Postgres
  enterprise/                      Kestra Enterprise + Aiven for Kafka + Aiven for OpenSearch (needs an EE license)
gcp/terraform/infrastructure-manager/vm-sql-gcs/   VM + Cloud SQL + GCS template meant for GCP Infrastructure Manager
```

Every terraform module has its own `README.md` with prerequisites, resources created, and exact `terraform apply` invocation (secrets/tfvars file needed, required CLI profile, etc.) — read the module's own README before changing or running it, not just this file.

## Commands

Toolchain is asdf-pinned (`.tool-versions`: terraform 1.13.2, task 3.44.1). Install via:
```bash
bash scripts/install-dependencies.sh
```

Terraform commands run through `Taskfile.yml`, which always runs `terraform fmt -recursive` before the actual command. The task's working dir is `terraform/{{.TF_WORKING_DIR}}` **relative to the cloud provider folder**, so `cd` into `aws/`, `azure/`, or `gcp/` first:

```bash
cd aws && task terraform TF_WORKING_DIR=aws-batch -- init
cd aws && task terraform TF_WORKING_DIR=aws-batch -- plan
cd azure && task terraform TF_WORKING_DIR=kestra-oss -- plan
cd gcp && task terraform TF_WORKING_DIR=gcp-aiven/opensource -- plan
```

`TF_WORKING_DIR` value is the module path under that provider's `terraform/` folder (matches the directory names in Layout above).

No lint/test suite beyond `terraform fmt`. Validate changes with `terraform plan` and by reading the module's README for the expected resources/outputs.

## Gotchas specific to this repo

- **`azure/terraform/kestra-oss/` has a committed `terraform.tfstate` and `.terraform.lock.hcl`.** `.gitignore` excludes `terraform.tfstate*` repo-wide, but this file is already tracked from before that rule existed. Treat it as live state, not a throwaway fixture — don't `terraform apply`/`destroy` against it without checking with the user first, and don't assume other modules behave the same way (they don't have committed state).
- `azure/arm-template/` and `azure/marketplace/` contain two versions of the same underlying VM deployment — the marketplace one adds `createUiDefinition.json` and marketplace-required parameters (`_artifactsLocation`, `_artifactsLocationSasToken`). A change to the deployment logic (VM sizing, extensions, outputs) generally needs to land in both, or the two will drift.
- Only one CI workflow exists (`.github/workflows/upload-templates.yaml`): on push to `main`, if `aws/cloudformation/ec2-rds-s3/kestra-oss.yaml` changed, it's uploaded to the `kestra-deployment-templates` S3 bucket. No other template in the repo is auto-published — everything else is consumed by users copying the module directly.
- `.gitignore` also excludes `Taskfile.yml`, `.tool-versions`, and `scripts/install-dependencies.sh` even though they're tracked (pre-existing exception) — don't be surprised these show as untracked-looking in some tooling despite being committed.
