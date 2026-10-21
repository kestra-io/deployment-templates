output "project_id" {
  value       = var.project_id
  description = "projectId property of the task runners"
}

output "region" {
  value       = var.region
  description = "region property of the task runners"
}

output "bucket" {
  value       = google_storage_bucket.kestra_bucket.name
  description = "bucket property of the task runners"
}

output "kestra_service_account_email" {
  value       = google_service_account.kestra.email
  description = "Service account Kestra uses to call the Batch and Cloud Run APIs"
}

output "kestra_service_account_key" {
  value       = var.create_service_account_key ? base64decode(google_service_account_key.kestra[0].private_key) : null
  description = "JSON key for serviceAccount property (only when create_service_account_key is true)"
  sensitive   = true
}

output "cloud_run_runtime_service_account_email" {
  value       = google_service_account.cloud_run_runtime.email
  description = "runtimeServiceAccount property of the Cloud Run task runner"
}
