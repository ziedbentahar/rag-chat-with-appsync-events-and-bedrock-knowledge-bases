locals {
  api_arn = awscc_appsync_api.this.id
  api_id  = element(split("/", local.api_arn), length(split("/", local.api_arn)) - 1)
}
