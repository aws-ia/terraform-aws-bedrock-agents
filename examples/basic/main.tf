#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################
variable "region" {
  type        = string
  description = "AWS region to deploy the resources"
  default     = "us-east-1"
}

provider "aws" {
  region = var.region
}

provider "awscc" {
  region = var.region
}

provider "opensearch" {
  url         = module.terraform-agents.default_collection.collection_endpoint != [] ? module.terraform-agents.default_collection[0].collection_endpoint : "https://localhost:8501"
  healthcheck = false
}

module "terraform-agents" {
  source = "../.." # local example
  create_kb = false
  create_default_kb = false
}