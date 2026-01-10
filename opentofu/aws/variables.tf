variable "ENV" {
  description = "The environment name (e.g., dev, prod)"
  type = string
}

variable "AWS_REGION" {
  description = "The AWS region to deploy into"
  type = string
}

variable "USER_EMAIL" {
  description = ""
  type = string
}