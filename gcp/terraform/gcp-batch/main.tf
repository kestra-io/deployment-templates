terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  labels = {
    project = "kestra"
  }
}

# Enable the APIs used by the Google Batch and Cloud Run task runners
resource "google_project_service" "services" {
  for_each = toset([
    "batch.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Staging bucket used by both task runners for input and output files
resource "google_storage_bucket" "kestra_bucket" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = var.bucket_force_destroy
  uniform_bucket_level_access = true
  labels                      = local.labels

  depends_on = [google_project_service.services]
}

# Service account that Kestra uses to call the Batch and Cloud Run APIs.
# Put its JSON key in the serviceAccount property of the task runner.
resource "google_service_account" "kestra" {
  account_id   = "kestra-task-runner"
  display_name = "Kestra task runner"
  description  = "Used by Kestra to submit Google Batch jobs and Cloud Run jobs"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "kestra_batch_jobs_editor" {
  project = var.project_id
  role    = "roles/batch.jobsEditor"
  member  = "serviceAccount:${google_service_account.kestra.email}"
}

resource "google_project_iam_member" "kestra_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.kestra.email}"
}

resource "google_project_iam_member" "kestra_logging_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.kestra.email}"
}

resource "google_storage_bucket_iam_member" "kestra_bucket_admin" {
  bucket = google_storage_bucket.kestra_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.kestra.email}"
}

# Service account the Cloud Run job containers run as (runtimeServiceAccount)
resource "google_service_account" "cloud_run_runtime" {
  account_id   = "kestra-cloud-run-runtime"
  display_name = "Kestra Cloud Run task runner runtime"
  description  = "Identity of the containers started by the Kestra Cloud Run task runner"

  depends_on = [google_project_service.services]
}

resource "google_storage_bucket_iam_member" "cloud_run_runtime_bucket" {
  bucket = google_storage_bucket.kestra_bucket.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.cloud_run_runtime.email}"
}

resource "google_project_iam_member" "cloud_run_runtime_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_runtime.email}"
}

# Kestra must be able to start Cloud Run jobs as the runtime service account
resource "google_service_account_iam_member" "kestra_acts_as_cloud_run_runtime" {
  service_account_id = google_service_account.cloud_run_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.kestra.email}"
}

# Google Batch VMs run as the Compute Engine default service account
data "google_compute_default_service_account" "default" {
  depends_on = [google_project_service.services]
}

resource "google_service_account_iam_member" "kestra_acts_as_batch_vm" {
  service_account_id = data.google_compute_default_service_account.default.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.kestra.email}"
}

resource "google_project_iam_member" "batch_vm_agent_reporter" {
  project = var.project_id
  role    = "roles/batch.agentReporter"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "batch_vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_storage_bucket_iam_member" "batch_vm_bucket" {
  bucket = google_storage_bucket.kestra_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

# Optional JSON key for the Kestra service account. The key ends up in the
# Terraform state, so prefer workload identity or create the key yourself.
resource "google_service_account_key" "kestra" {
  count              = var.create_service_account_key ? 1 : 0
  service_account_id = google_service_account.kestra.name
}
