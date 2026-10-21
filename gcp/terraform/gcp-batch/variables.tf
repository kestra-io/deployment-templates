variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for the bucket and the task runners"
  default     = "europe-west2"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name of the GCS staging bucket to create"
}

variable "bucket_force_destroy" {
  type        = bool
  description = "Delete the bucket with its content on terraform destroy"
  default     = false
}

variable "create_service_account_key" {
  type        = bool
  description = "Create a JSON key for the Kestra service account (stored in the Terraform state)"
  default     = false
}
