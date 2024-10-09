output "default_collection" {
  value =  awscc_opensearchserverless_collection.default_collection[0]
  description = "Opensearch default collection value."
}