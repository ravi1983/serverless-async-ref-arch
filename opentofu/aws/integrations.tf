resource "aws_s3_bucket" "source-bucket" {
  bucket = "source-bucket-09873"

  tags = {
    Usage = "Step Func input"
    Environment = var.ENV
  }
}

resource "aws_s3_bucket_notification" "object_created_notification" {
  bucket = aws_s3_bucket.source-bucket.id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "s3_upload_rule" {
  name = "trigger-step-func-on-s3-upload"
  description = "Triggers Step Function when an object is created in S3"

  event_pattern = jsonencode({
    source = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.source-bucket.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "step_function_target" {
  rule = aws_cloudwatch_event_rule.s3_upload_rule.name
  arn = aws_sfn_state_machine.doc-processor-step-func.arn
  role_arn = aws_iam_role.event_bridge_to_sfn_role.arn

  # Map S3 event data to the format your Step Function expects ($.file_key)
  input_transformer {
    input_paths = {
      key = "$.detail.object.key"
    }
    input_template = "{\"file_key\": <key>}"
  }
}

resource "aws_iam_role" "event_bridge_to_sfn_role" {
  name = "eventbridge-sfn-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "event_bridge_sfn_policy" {
  role = aws_iam_role.event_bridge_to_sfn_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "states:StartExecution"
      Resource = aws_sfn_state_machine.doc-processor-step-func.arn
    }]
  })
}

resource "aws_s3_bucket" "target-bucket" {
  bucket = "target-bucket-09873"

  tags = {
    Usage = "Step Func output"
    Environment = var.ENV
  }
}


resource "aws_sns_topic" "doc-processed-topic" {
  name = "doc-processed-topic"
}

resource "aws_sns_topic_subscription" "user_updates_email_target" {
  topic_arn = aws_sns_topic.doc-processed-topic.arn
  protocol = "email"
  endpoint = var.USER_EMAIL
}