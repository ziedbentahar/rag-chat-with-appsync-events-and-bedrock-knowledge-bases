variable "application" {
  type = string
}

variable "environment" {
  type = string
}


variable "user_pool_id" {
  type = string
}

variable "manage_appsync_resources_function" {
  type = object({
    dist_dir = string
    handler  = string
    name     = string
  })
}

variable "handle_appsync_events_function" {
  type = object({
    dist_dir = string
    handler  = string
    name     = string
  })
}

variable "knowledge_base" {
  type = object({
    id                   = string
    arn                  = string
    generation_model_arn = string
  })
}
