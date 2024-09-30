# – IAM – 

resource "aws_iam_role" "agent_role" {
  assume_role_policy = data.aws_iam_policy_document.agent_trust.json
  name_prefix        = var.name_prefix
}

resource "aws_iam_role_policy" "agent_policy" {
  policy = data.aws_iam_policy_document.agent_permissions.json
  role   = aws_iam_role.agent_role.id
}

resource "aws_iam_role_policy" "kb_policy" {
  count = var.create_kb ? 1 : 0
  policy = data.aws_iam_policy_document.knowledge_base_permissions[0].json
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
          "bedrock:InvokeModel",
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
  counter_kb        = var.create_kb ? [1] : []
  knowledge_base_id = var.create_kb ? (var.create_default_kb ? awscc_bedrock_knowledge_base.knowledge_base_default[0].id : (var.create_mongo_config ? awscc_bedrock_knowledge_base.knowledge_base_mongo[0].id : (var.create_opensearch_config ? awscc_bedrock_knowledge_base.knowledge_base_opensearch[0].id : (var.create_pinecone_config ? awscc_bedrock_knowledge_base.knowledge_base_pinecone[0].id : (var.create_rds_config ? awscc_bedrock_knowledge_base.knowledge_base_rds[0].id : null))))) : null
  knowledge_bases_value = {
    description          = var.kb_description
    knowledge_base_id    = var.create_kb ? local.knowledge_base_id : var.existing_kb
    knowledge_base_state = var.kb_state
  }
  kb_result = [for count in local.counter_kb : local.knowledge_bases_value]

  counter_action_group = var.create_ag ? [1] : []
  action_group_value = {
    action_group_name = var.action_group_name
    description       = var.action_group_description
    action_group_state = var.action_group_state
    parent_action_group_signature = var.parent_action_group_signature
    skip_resource_in_use_check_on_delete = var.skip_resource_in_use
    api_schema = {
      payload = var.api_schema_payload
      s3 = {
        s3_bucket_name = var.api_schema_s3_bucket_name
        s3_object_key  = var.api_schema_s3_object_key
      }
    }
    action_group_executor = {
      custom_control = var.custom_control
      lambda = var.lambda_action_group_executor
    }
    function_schema = {
      functions = [{
        name = var.function_name
        description = var.function_description
        parameters = {
          description = var.function_parameters_description
          required    = var.function_parameters_required
          type        = var.function_parameters_type
        }
      }]
    }
  }
  action_group_result = [for count in local.counter_action_group : local.action_group_value]

}

resource "awscc_bedrock_agent" "bedrock_agent" {
  agent_name                  = var.agent_name  
  foundation_model            = var.foundation_model  
  instruction                 = var.instruction       
  description                 = var.agent_description 
  idle_session_ttl_in_seconds = var.idle_session_ttl  
  agent_resource_role_arn     = aws_iam_role.agent_role.arn
  customer_encryption_key_arn = var.kms_key_arn 
  tags                        = var.tags        
  prompt_override_configuration = var.prompt_override == false ? null : {
     prompt_configurations = [{
       prompt_type = var.prompt_type
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
  auto_prepare    = true
  knowledge_bases = length(local.kb_result) > 0 ? local.kb_result : null
  action_groups   = length(local.action_group_result) > 0 ? local.action_group_result : null
}


# - Knowledge Base Data source –
resource "awscc_s3_bucket" "s3_data_source" {
  count = var.kb_s3_data_source == null ? 1 : 0
  bucket_name = "${var.kb_name}-default-bucket"

  tags = [{
    key   = "Name"
    value = "S3 Data Source"
  }]

}

resource "aws_bedrockagent_data_source" "knowledge_base_ds" {
  count             = 1
  knowledge_base_id = awscc_bedrock_knowledge_base.knowledge_base_default[0].id
  name              = "${var.kb_name}DataSource"
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.kb_s3_data_source == null ? awscc_s3_bucket.s3_data_source[0].arn : var.kb_s3_data_source # Create an S3 bucket or reference existing
    }
  }
}

# - Knowledge Base Default OpenSearch -

resource "awscc_bedrock_knowledge_base" "knowledge_base_default" {
  count       = var.create_default_kb ? 1 : 0
  name        = var.kb_name
  description = var.kb_description
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn

  storage_configuration = {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration = {
      collection_arn    = awscc_opensearchserverless_collection.default_collection.arn
      vector_index_name = var.vector_index_name 
      field_mapping = {
        metadata_field = var.metadata_field 
        text_field     = var.text_field     
        vector_field   = var.vector_field   
      }
    }
  }
  knowledge_base_configuration = {
    type = "VECTOR"
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn 
    }
  }
}

# – Existing KBs –

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
      collection_name        = var.collection_name
      credentials_secret_arn = var.credentials_secret_arn
      database_name          = var.database_name
      endpoint               = var.endpoint
      vector_index_name      = var.vector_index_name
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
      connection_string      = var.connection_string
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
      database_name          = var.database_name
      resource_arn           = var.resource_arn
      table_name             = var.table_name
      field_mapping = {
        metadata_field    = var.metadata_field
        primary_key_field = var.primary_key_field
        text_field        = var.text_field
        vector_field      = var.vector_field
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

# – OpenSearch Serverless Default –

# Create a Collection
resource "awscc_opensearchserverless_collection" "default_collection" {
  name        = "default-collection"
  type        = "VECTORSEARCH"
  description = "Default collection created by Amazon Bedrock Knowledge base."
  depends_on = [
    aws_opensearchserverless_security_policy.security_policy
  ]
}

# Encryption Security Policy
resource "aws_opensearchserverless_security_policy" "security_policy" {
  name = "awscc-security-policy"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = ["collection/default-collection"]
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}

# Network policy
resource "aws_opensearchserverless_security_policy" "nw_policy" {
  name = "nw-policy"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = ["collection/default-collection"]
        },
        {
          ResourceType = "dashboard"
          Resource = ["collection/default-collection"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}


# Data policy
resource "aws_opensearchserverless_access_policy" "hashicorp_kb" {
  name = "os-access-policy"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource = [
            "index/${awscc_opensearchserverless_collection.default_collection.name}/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex", # Required for Terraform
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:UpdateIndex",
            "aoss:WriteDocument"
          ]
        },
        {
          ResourceType = "collection"
          Resource = [
            "collection/${awscc_opensearchserverless_collection.default_collection.name}"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DescribeCollectionItems",
            "aoss:UpdateCollectionItems"
          ]
        }
      ],
      Principal = [
        aws_iam_role.bedrock_knowledge_base_role[0].arn,
        data.aws_caller_identity.current.arn
      ]
    }
  ])
}

# OpenSearch index
provider "opensearch" {
  url         = awscc_opensearchserverless_collection.default_collection.collection_endpoint
  healthcheck = false
}

resource "time_sleep" "wait_before_index_creation" {
  depends_on      = [awscc_opensearchserverless_collection.default_collection]
  create_duration = "60s" # Wait for 60 seconds before creating the index
}

resource "opensearch_index" "default_oss_index" {
  name                           = "bedrock-knowledge-base-default-index"
  number_of_shards               = "1"
  number_of_replicas             = "0"
  index_knn                      = true
  index_knn_algo_param_ef_search = "512"
  mappings                       = <<-EOF
    {
      "properties": {
        "bedrock-knowledge-base-default-vector": {
          "type": "knn_vector",
          "dimension": 1536,
          "method": {
            "name": "hnsw",
            "engine": "faiss",
            "parameters": {
              "m": 16,
              "ef_construction": 512
            },
            "space_type": "l2"
          }
        },
        "AMAZON_BEDROCK_METADATA": {
          "type": "text",
          "index": "false"
        },
        "AMAZON_BEDROCK_TEXT_CHUNK": {
          "type": "text",
          "index": "true"
        }
      }
    }
  EOF
  force_destroy                  = true
  depends_on                     = [time_sleep.wait_before_index_creation]
}
