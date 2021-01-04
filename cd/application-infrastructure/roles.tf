data "aws_iam_policy_document" "ecs_task_assume_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "notification_ecs_task_execution" {
  name               = "${var.environment_prefix}-notification-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = local.default_tags
}

resource "aws_iam_role_policy_attachment" "notification_ecs_task_execution" {
  role       = aws_iam_role.notification_ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "notification_ecs_task_ssm_fetch" {
  role       = aws_iam_role.notification_ecs_task_execution.name
  policy_arn = aws_iam_policy.notification_ecs_task_secrets_fetch.arn
}

resource "aws_iam_policy" "notification_ecs_task_secrets_fetch" {
  name   = "${var.environment_prefix}-notification-ecs-task-secrets-fetch"
  policy = data.aws_iam_policy_document.ssm_parameter_fetch.json
}

data "aws_iam_policy_document" "ssm_parameter_fetch" {
  statement {
    sid = "FetchNotificationSecrets"

    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "kms:Decrypt"
    ]

    resources = ["arn:aws:ssm:us-east-2:437518843863:parameter/${var.environment_prefix}/notification-api/*"]
  }
}

resource "aws_iam_role" "notification_api_task" {
  name = "${var.environment_prefix}-notification-api-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags = local.default_tags
}

data "aws_iam_policy_document" "notification_sqs" {
  statement {
    sid = "NotificationTaskSqs"

    actions = [
      "sqs:DeleteMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteQueue",
      "sqs:SendMessage",
      "sqs:CreateQueue",
      "sqs:ListQueues",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "notification_ecs_task_sqs" {
  name   = "${var.environment_prefix}-notification-ecs-task-sqs"
  policy = data.aws_iam_policy_document.notification_sqs.json
}

resource "aws_iam_role_policy_attachment" "notification_ecs_task_sqs" {
  role       = aws_iam_role.notification_api_task.name
  policy_arn = aws_iam_policy.notification_ecs_task_sqs.arn
}

data "aws_iam_policy_document" "notification_ses" {
  statement {
    sid = "NotificationTaskSes"

    actions = [
      "ses:SendRawEmail"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "notification_ecs_task_ses" {
  name   = "${var.environment_prefix}-notification-ecs-task-ses"
  policy = data.aws_iam_policy_document.notification_ses.json
}

resource "aws_iam_role_policy_attachment" "notification_ecs_task_ses" {
  role       = aws_iam_role.notification_api_task.name
  policy_arn = aws_iam_policy.notification_ecs_task_ses.arn
}

resource "aws_kms_grant" "ecs_decrypt_secrets" {
  name              = "${var.environment_prefix}-notification-ecs-decrypt-secrets"
  key_id            = data.terraform_remote_state.base_infrastructure.outputs.notification_kms_key_id
  grantee_principal = aws_iam_role.notification_ecs_task_execution.arn
  operations        = ["Decrypt"]
}