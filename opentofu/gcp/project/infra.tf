resource "google_project" "serverless_project" {
  name            = "serverless-project"
  project_id      = "serverless-project-143"
  billing_account = var.BILLING_ACCOUNT
}

output "project_id" {
  value = google_project.serverless_project.id
}