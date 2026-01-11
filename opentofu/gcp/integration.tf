resource "google_storage_bucket" "source_bucket" {
  name = "${var.PROJECT_ID}-source"
  location = var.REGION
  uniform_bucket_level_access = true

  force_destroy = true
}

resource "google_storage_bucket" "target_bucket" {
  name = "${var.PROJECT_ID}-target"
  location = var.REGION
  uniform_bucket_level_access = true

  force_destroy = true
}

resource "google_pubsub_topic" "notifications" {
  name = "doc-processing-complete"
}

resource "google_document_ai_processor" "ocr_processor" {
  display_name = "workflow-ocr-processor"
  type = "OCR_PROCESSOR"
  location = "us"
}

resource "google_eventarc_trigger" "storage_trigger" {
  name = "trigger-storage-workflow"
  location = var.REGION

  matching_criteria {
    attribute = "type"
    value = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value = google_storage_bucket.source_bucket.name
  }

  destination {
    workflow = google_workflows_workflow.doc_processor.id
  }
  service_account = google_service_account.workflow_service_account.email
}

resource "google_project_service_identity" "eventarc_service_account" {
  provider = google-beta
  project  = var.PROJECT_ID
  service  = "eventarc.googleapis.com"
}

resource "google_storage_bucket_iam_member" "eventarc_storage_viewer" {
  bucket = google_storage_bucket.source_bucket.name
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_project_service_identity.eventarc_service_account.email}"
}

data "google_project" "project" {}

resource "google_project_iam_member" "gcs_pubsub_publishing" {
  project = data.google_project.project.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_project_service_identity" "docai_service_agent" {
  provider = google-beta
  project  = var.PROJECT_ID
  service  = "documentai.googleapis.com"
}

resource "google_storage_bucket_iam_member" "docai_source_reader" {
  bucket = google_storage_bucket.source_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_project_service_identity.docai_service_agent.email}"
}

resource "google_storage_bucket_iam_member" "docai_target_writer" {
  bucket = google_storage_bucket.target_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_project_service_identity.docai_service_agent.email}"
}