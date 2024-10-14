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
  url         = length(module.terraform-agents.default_collection.collection_endpoint) > 0 ? module.terraform-agents.default_collection[0].collection_endpoint : null
}

module "terraform-agents" {
  source = "../.." # local example
  create_kb = true
  create_default_kb = true
}