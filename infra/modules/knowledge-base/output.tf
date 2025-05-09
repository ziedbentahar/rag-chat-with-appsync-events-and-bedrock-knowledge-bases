output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_arn" {
  value = aws_bedrockagent_knowledge_base.this.arn
}

output "generation_model_arn" {
  value = local.generation_model_arn
}
