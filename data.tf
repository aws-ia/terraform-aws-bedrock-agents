data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

data "aws_iam_policy_document" "agent_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["bedrock.amazonaws.com"]
      type        = "Service"
    }
    condition {
      test     = "StringEquals"
      values   = [local.account_id]
      variable = "aws:SourceAccount"
    }
    condition {
      test     = "ArnLike"
      values   = ["arn:${local.partition}:bedrock:${local.region}:${local.account_id}:agent/*"]
      variable = "AWS:SourceArn"
    }
  }
}

data "aws_iam_policy_document" "agent_permissions" {
  statement {
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:${local.partition}:bedrock:${local.region}::foundation-model/${var.foundation_model}",
    ]
  }
}

data "aws_iam_policy_document" "knowledge_base_permissions" {
  count = var.create_kb ? 1 : 0

  statement {
    actions   = ["bedrock:Retrieve"]
    resources = ["arn:${local.partition}:bedrock:${local.region}:${local.account_id}:knowledge-base/*"]
  }
}
