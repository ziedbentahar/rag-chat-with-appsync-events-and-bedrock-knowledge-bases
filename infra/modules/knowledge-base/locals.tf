locals {
  generation_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/mistral.mistral-large-2402-v1:0"
  embedding_model_arn  = "arn:aws:bedrock:${data.aws_region.current.id}::foundation-model/amazon.titan-embed-text-v2:0"
  kb_folder            = "kb"
  db_schema            = "knowledge_base"
  vector_table         = "bedrock_kb"
}
