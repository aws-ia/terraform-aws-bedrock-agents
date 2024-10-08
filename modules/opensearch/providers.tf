terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.8.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.78.0"
    }
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = "= 2.2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.6"
    }
  }
}

provider "opensearch" {
  url         = awscc_opensearchserverless_collection.default_collection.collection_endpoint
  healthcheck = false
}