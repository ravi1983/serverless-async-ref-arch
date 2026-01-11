resource "google_service_account" "workflow_service_account" {
  account_id   = "workflow-service-account"
  display_name = "Workflow service account"
}

resource "google_workflows_workflow" "doc_processor" {
  name            = "doc_processor"
  region          = var.REGION
  description     = "Processes documents from GCS using Document AI and Vertex AI"
  service_account = google_service_account.workflow_service_account.id

  deletion_protection = false
  execution_history_level = "EXECUTION_HISTORY_DETAILED"

  source_contents = templatefile("${path.module}/workflow/workflow.yml", {
    project_id  = var.PROJECT_ID
    processor_id = google_document_ai_processor.ocr_processor.id
    results_bucket = google_storage_bucket.target_bucket.name
    topic_name = google_pubsub_topic.notifications.name
  })
}

locals {
  workflow_roles = [
    "roles/documentai.apiUser",
    "roles/aiplatform.user",
    "roles/storage.objectAdmin",
    "roles/pubsub.publisher",
    "roles/workflows.invoker",
    "roles/eventarc.eventReceiver",
    "roles/logging.logWriter",
    "roles/serviceusage.serviceUsageConsumer"
  ]
}
resource "google_project_iam_member" "workflow_iam" {
  for_each = toset(local.workflow_roles)
  project  = var.PROJECT_ID
  role     = each.key
  member   = "serviceAccount:${google_service_account.workflow_service_account.email}"
}
