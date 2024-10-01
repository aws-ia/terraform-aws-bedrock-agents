terraform {
  required_version = ">= 1.0.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
      region  = "us-east-1"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0.0"
      region  = "us-east-1"
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