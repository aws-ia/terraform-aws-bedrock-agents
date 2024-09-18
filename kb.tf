# - Knowledge Base Default -

resource "awscc_bedrock_knowledge_base" "knowledge_base_default" {
  count       = var.create_default_kb ? 1 : 0
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
        text_field     = var.text_field     # "AMAZON_BEDROCK_TEXT_CHUNK"
        vector_field   = var.vector_field   # "bedrock-knowledge-base-default-vector"
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
