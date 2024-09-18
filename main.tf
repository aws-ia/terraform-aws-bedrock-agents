# – IAM – 

resource "aws_iam_role" "agent_role" {
  assume_role_policy = data.aws_iam_policy_document.agent_trust.json
  name_prefix        = var.name_prefix
}

resource "aws_iam_role_policy" "agent_policy" {
  policy = data.aws_iam_policy_document.agent_permissions.json
  role   = aws_iam_role.agent_role.id
}

# Define the IAM role for Amazon Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_knowledge_base_role" {
  count = var.kb_role_arn != null ? 0 : 1
  name  = "AmazonBedrockExecutionRoleForKnowledgeBase"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "bedrock.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Attach a policy to allow necessary permissions for the Bedrock Knowledge Base
resource "aws_iam_policy" "bedrock_knowledge_base_policy" {
  count = var.kb_role_arn != null ? 0 : 1
  name  = "AmazonBedrockKnowledgeBasePolicy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "bedrock:*",
          "s3:*",
          "logs:*",
          "aoss:*"
        ],
        "Resource" : "*"
      },
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "bedrock_knowledge_base_policy_attachment" {
  count      = var.kb_role_arn != null ? 0 : 1
  role       = aws_iam_role.bedrock_knowledge_base_role[0].name
  policy_arn = aws_iam_policy.bedrock_knowledge_base_policy[0].arn
}

# – Bedrock Agent –

locals {
  counter           = var.create_kb ? [1] : []
  knowledge_base_id = var.create_kb ? (var.create_default_kb ? awscc_bedrock_knowledge_base.knowledge_base_default[0].id : (var.create_mongo_config ? awscc_bedrock_knowledge_base.knowledge_base_mongo[0].id : (var.create_opensearch_config ? awscc_bedrock_knowledge_base.knowledge_base_opensearch[0].id : (var.create_pinecone_config ? awscc_bedrock_knowledge_base.knowledge_base_pinecone[0].id : (var.create_rds_config ? awscc_bedrock_knowledge_base.knowledge_base_rds[0].id : null))))) : null
  knowledge_bases_value = {
    description          = var.kb_description
    knowledge_base_id    = var.create_kb ? local.knowledge_base_id : var.existing_kb
    knowledge_base_state = var.kb_state
  }
  result = [for count in local.counter : local.knowledge_bases_value]
}

resource "awscc_bedrock_agent" "bedrock_agent" {
  agent_name                  = var.agent_name        # "BedrockAgent"
  foundation_model            = var.foundation_model  # "anthropic.claude-v2"
  instruction                 = var.instruction       # null
  description                 = var.agent_description # null
  idle_session_ttl_in_seconds = var.idle_session_ttl  # 600
  agent_resource_role_arn     = aws_iam_role.agent_role.arn
  customer_encryption_key_arn = var.kms_key_arn # null
  tags                        = var.tags        # null
#   prompt_override_configuration = {
#     prompt_configurations = [{
#       prompt_type = var.prompt_type
#       inference_configuration = {
#         temperature    = var.temperature
#         top_p          = var.top_p
#         top_k          = var.top_k
#         stop_sequences = var.stop_sequences
#         maximum_length = var.max_length
#       }
#       base_prompt_template = var.base_prompt_template
#       parser_mode          = var.parser_mode
#       prompt_creation_mode = var.prompt_creation_mode
#       prompt_state         = var.prompt_state
#
#     }]
#     override_lambda = var.override_lambda_arn
#
#   }
  # open issue: https://github.com/hashicorp/terraform-provider-awscc/issues/2004
  # auto_prepare needs to be set to true
  auto_prepare    = true #var.should_prepare_agent 
  knowledge_bases = local.result != [] ? local.result : null
}

# - Knowledge Base Data source

resource "aws_bedrockagent_data_source" "knowledge_base_ds" {
  count             = 1
  knowledge_base_id = awscc_bedrock_knowledge_base.knowledge_base_default[0].id
  name              = "${var.kb_name}DataSource"
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = "arn:aws:s3:::###" # Create an S3 bucket or reference existing
    }
  }
}



# – Action Group – 

