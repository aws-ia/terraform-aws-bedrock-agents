variable "solution_prefix" { 
  description = "This value is appended at the beginning of resource names."
  type        = string
  default     = "BedrockAgents"
}

variable "kb_role_arn" {
  description = "The ARN of the IAM role with permission to invoke API operations on the knowledge base."
  type        = string
  default     = null
}