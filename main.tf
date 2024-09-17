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
  name = "AmazonBedrockExecutionRoleForKnowledgeBase"
  
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "bedrock.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# Attach a policy to allow necessary permissions for the Bedrock Knowledge Base
resource "aws_iam_policy" "bedrock_knowledge_base_policy" {
  count = var.kb_role_arn != null ? 0 : 1
  name = "AmazonBedrockKnowledgeBasePolicy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "bedrock:*",
          "s3:*",
          "logs:*",
          "aoss:APIAccessAll"
        ],
        "Resource": "*"
      },
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "bedrock_knowledge_base_policy_attachment" {
  count = var.kb_role_arn != null ? 0 : 1
  role       = aws_iam_role.bedrock_knowledge_base_role[0].name
  policy_arn = aws_iam_policy.bedrock_knowledge_base_policy[0].arn
}

# – Bedrock Agent –

locals {
  counter = var.create_kb ? [1] : []
  knowledge_base_id = var.create_kb ? (var.create_default_kb ? awscc_bedrock_knowledge_base.knowledge_base_default[0].id : (var.create_mongo_config ? awscc_bedrock_knowledge_base.knowledge_base_mongo[0].id : (var.create_opensearch_config ? awscc_bedrock_knowledge_base.knowledge_base_opensearch[0].id : (var.create_pinecone_config ? awscc_bedrock_knowledge_base.knowledge_base_pinecone[0].id : (var.create_rds_config ? awscc_bedrock_knowledge_base.knowledge_base_rds[0].id : null))))) : null
  knowledge_bases_value  = {
    description     = var.kb_description
    knowledge_base_id  = var.create_kb ? local.knowledge_base_id : var.existing_kb
    knowledge_base_state = var.kb_state
  }
  result = [ for count in local.counter : local.knowledge_bases_value ]
}

resource "awscc_bedrock_agent" "bedrock_agent" {
  agent_name                  = var.agent_name # "BedrockAgent"
  foundation_model            = var.foundation_model # "anthropic.claude-v2"
  instruction                 = var.instruction # null
  description                 = var.agent_description # null
  idle_session_ttl_in_seconds = var.idle_session_ttl # 600
  agent_resource_role_arn     = aws_iam_role.agent_role.arn
  customer_encryption_key_arn = var.kms_key_arn # null
  tags                        = var.tags  # null
  prompt_override_configuration = {
    prompt_configurations = [{
        prompt_type          = var.prompt_type
        inference_configuration = {
              temperature    = var.temperature
              top_p          = var.top_p 
              top_k          = var.top_k
              stop_sequences = var.stop_sequences
              maximum_length = var.max_length
        }
        base_prompt_template = var.base_prompt_template
        parser_mode          = var.parser_mode
        prompt_creation_mode = var.prompt_creation_mode
        prompt_state         = var.prompt_state

    }]
    override_lambda = var.override_lambda_arn

  }
  # open issue: https://github.com/hashicorp/terraform-provider-awscc/issues/2004
  # auto_prepare needs to be set to true
  auto_prepare    =  true #var.should_prepare_agent 
  knowledge_bases = local.result != [] ? local.result : null
}
# – OpenSearch Serverless Default –

# Create a Collection
resource "awscc_opensearchserverless_collection" "default_collection" {
  name = "default-collection"
  type = "VECTORSEARCH"
  description = "Default collection created by Amazon Bedrock Knowledge base."
  depends_on = [
    awscc_opensearchserverless_security_policy.security_policy
  ]
}

# Encryption SecurityPolicy
resource "awscc_opensearchserverless_security_policy" "security_policy" {
  name        = "awscc-security-policy"
  description = "created via awscc"
  type        = "encryption"
  policy = jsonencode({
    "Rules" = [
      {
        "ResourceType" = "collection",
        "Resource" = [
          "collection/default-collection"
        ]
      }
    ],
    "AWSOwnedKey" = true
  })
}

# Network policy
resource "awscc_opensearchserverless_security_policy" "nw_policy" {
  name        = "awscc-security-policy"
  description = "created via awscc"
  type        = "network"
  policy = jsonencode([
  {
    "Rules": [
      {
        "Resource": [
          "collection/default-collection"
        ],
        "ResourceType": "dashboard"
      },
      {
        "Resource": [
          "collection/default-collection"
        ],
        "ResourceType": "collection"
      }
    ],
    "AllowFromPublic": true
  }
])
}

resource "awscc_opensearchserverless_access_policy" "os-access-policy" {
  name        = "os-access-policy"
  type        = "data"
  description = "Custom data access policy to allow a created IAM role to have permissions on Amazon Open Search collections and indexes."
  policy = jsonencode([{
    "Description" = "Custom data access policy to allow a created IAM role to have permissions on Amazon Open Search collections and indexes.",
    "Rules" = [
      {
        "ResourceType" = "index",
        "Resource" = [
          "index/${awscc_opensearchserverless_collection.default_collection.name}/*"
        ],
        "Permission" = [
          "aoss:UpdateIndex",
          "aoss:DescribeIndex",
          "aoss:ReadDocument",
          "aoss:WriteDocument",
          "aoss:CreateIndex"
        ]
      },
      {
        "ResourceType" = "collection",
        "Resource" = [
          "collection/${awscc_opensearchserverless_collection.default_collection.name}"
        ],
        "Permission" = [
          "aoss:DescribeCollectionItems",
          "aoss:CreateCollectionItems",
          "aoss:UpdateCollectionItems"
        ]
    }],
    "Principal" = [
      aws_iam_role.bedrock_knowledge_base_role[0].arn
    ]
  }])
}

# - Knowledge Base Default -

resource "awscc_bedrock_knowledge_base" "knowledge_base_default" {
  count = var.create_default_kb ? 1 : 0
  name        = var.kb_name
  description = var.kb_description 
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn

  storage_configuration = {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration = {
      collection_arn    = awscc_opensearchserverless_collection.default_collection.arn 
      vector_index_name = var.vector_index_name # bedrock-knowledge-base-default-index
      field_mapping = {
        metadata_field = var.metadata_field # "AMAZON_BEDROCK_METADATA
        text_field     = var.text_field # "AMAZON_BEDROCK_TEXT_CHUNK"
        vector_field   = var.vector_field # "bedrock-knowledge-base-default-vector"
      }
    }
  }
  knowledge_base_configuration = {
    type = "VECTOR"
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn # "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
    }
  }
}
# - Mongo –

resource "awscc_bedrock_knowledge_base" "knowledge_base_mongo" {
  count       = var.create_mongo_config ? 1 : 0
  name        = var.kb_name
  description = var.kb_description 
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn
  tags        = var.kb_tags

  storage_configuration = {
    type = var.kb_storage_type 

    mongo_db_atlas_configuration = {
      collection_name = var.collection_name
      credentials_secret_arn = var.credentials_secret_arn
      database_name = var.database_name
      endpoint = var.endpoint
      vector_index_name = var.vector_index_name
      field_mapping = {   
        metadata_field = var.metadata_field
        text_field     = var.text_field
        vector_field   = var.vector_field
      }
      endpoint_service_name = var.endpoint_service_name
    }
  }
  knowledge_base_configuration = {
    type = var.kb_type
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn
    }
  }
}

# – OpenSearch –
resource "awscc_bedrock_knowledge_base" "knowledge_base_opensearch" {
  count       = var.create_opensearch_config ? 1 : 0
  name        = var.kb_name
  description = var.kb_description 
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn
  tags        = var.kb_tags

  storage_configuration = {
    type = var.kb_storage_type 
    opensearch_serverless_configuration = {
      collection_arn    = var.collection_arn
      vector_index_name = var.vector_index_name
      field_mapping = {
        metadata_field = var.metadata_field
        text_field     = var.text_field
        vector_field   = var.vector_field
      }
    }
  }
  knowledge_base_configuration = {
    type = var.kb_type
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn
    }
  }
}

# – Pinecone –
resource "awscc_bedrock_knowledge_base" "knowledge_base_pinecone" {
  count       = var.create_pinecone_config ? 1 : 0
  name        = var.kb_name
  description = var.kb_description 
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn
  tags        = var.kb_tags

  storage_configuration = {
    type = var.kb_storage_type 
    pinecone_configuration = {
      connection_string = var.connection_string
      credentials_secret_arn = var.credentials_secret_arn
      field_mapping = {
        metadata_field = var.metadata_field
        text_field     = var.text_field
      }
      namespace = var.namespace 
    }
  }
  knowledge_base_configuration = {
    type = var.kb_type
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn
    }
  }
}
# – RDS –
resource "awscc_bedrock_knowledge_base" "knowledge_base_rds" {
  count       = var.create_rds_config ? 1 : 0
  name        = var.kb_name
  description = var.kb_description 
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn
  tags        = var.kb_tags

  storage_configuration = {
    type = var.kb_storage_type 
    rds_configuration = {
        credentials_secret_arn = var.credentials_secret_arn
        database_name = var.database_name
        resource_arn = var.resource_arn
        table_name  = var.table_name
        field_mapping = {
          metadata_field = var.metadata_field
          primary_key_field = var.primary_key_field
          text_field     = var.text_field
          vector_field   = var.vector_field
        }
    }
  }
  knowledge_base_configuration = {
    type = var.kb_type
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn
    }
  }
}

# – Action Group – 
