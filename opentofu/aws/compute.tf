resource "aws_iam_role_policy" "lambda_bedrock_permissions" {
  name = "cart_function_claude_35_policy"
  role = aws_iam_role.cart_function_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:*:*:inference-profile/us.meta.llama3-3-70b-instruct-v1:0",
          "arn:aws:bedrock:us-east-1::foundation-model/meta.llama3-3-70b-instruct-v1:0",
          "arn:aws:bedrock:${var.AWS_REGION}::foundation-model/meta.llama3-3-70b-instruct-v1:0",
          "arn:aws:bedrock:us-west-2::foundation-model/meta.llama3-3-70b-instruct-v1:0"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "cart_function_exec_role" {
  name = "cart_function_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_lambda_function" "bedrock_invoker" {
  function_name = "bedrock_invoker"
  handler = "bedrock_invoker.handler"
  runtime = "python3.12"
  role = aws_iam_role.cart_function_exec_role.arn

  publish = true
  filename = "${path.module}/dummy.zip"


  lifecycle {
    ignore_changes = [
      layers,
      filename,
      source_code_hash
    ]
  }
}

resource "aws_iam_role" "doc-processor-step-func-role" {
  name = "StepFunctionAIPolicy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "doc-processor-step-func-policy" {
  role = aws_iam_role.doc-processor-step-func-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "bedrock:InvokeModel",
          "s3:GetObject",
          "s3:PutObject",
          "sns:Publish",
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sfn_state_machine" "doc-processor-step-func" {
  name     = "doc-processor-step-func"
  role_arn = aws_iam_role.doc-processor-step-func-role.arn

  definition = jsonencode({
    StartAt = "DetectText"
    States = {
      DetectText = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:textract:detectDocumentText"
        Parameters = {
          Document = {
            S3Object = {
              Bucket   = aws_s3_bucket.source-bucket.id
              "Name.$" = "$.file_key"
            }
          }
        }
        ResultPath = "$.textract_raw"
        Next       = "ProcessWithAI"
      }
      ProcessWithAI = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.bedrock_invoker.function_name
          Payload = {
            "blocks.$" = "$.textract_raw.Blocks"
            "file_key.$" = "$.file_key"
          }
        }
        ResultSelector = {
          "text_analysis.$" = "$.Payload.analysis_result"
        }
        ResultPath = "$.final_output"
        Next       = "StoreResult"
      }
      StoreResult = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:s3:putObject"
        Parameters = {
          Bucket = aws_s3_bucket.target-bucket.id
          "Key.$"  = "States.Format('{}-analysis.json', $.file_key)"
          "Body.$" = "$.final_output.text_analysis"
        }
        ResultPath = "$.s3_metadata"
        Next = "SendEmail"
      }
      SendEmail = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn   = aws_sns_topic.doc-processed-topic.arn
          "Message.$" = "States.Format('Your analysis is ready. View it here: https://{}.s3.amazonaws.com/{}-analysis.json', '${aws_s3_bucket.target-bucket.id}', $.file_key)"
        }
        End = true
      }
    }
  })
}