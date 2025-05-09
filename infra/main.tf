module "vpc" {
  source = "./modules/vpc"
}

module "knowledge_base" {
  source = "./modules/knowledge-base"

  application = var.application
  environment = var.environment

  db = {
    name            = "sampledb"
    master_username = "masteruser"
    min_capacity    = 1
    max_capacity    = 2
  }

  seed_db_function = {
    dist_dir = "../src/dist/table-seeding/lambda-handlers"
    handler  = "seed-db.handler"
    name     = "seed-db"
  }

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name

}


module "events-api" {
  source = "./modules/events-api"

  application = var.application
  environment = var.environment

  user_pool_id = module.auth.user_pool_id

  manage_appsync_resources_function = {
    dist_dir = "../src/dist/resource-management/lambda-handlers"
    handler  = "manage-appsync-resources.handler"
    name     = "manage-appsync-resources"
  }

  handle_appsync_events_function = {
    dist_dir = "../src/dist/chat/lambda-handlers"
    handler  = "handle-appsync-events.handler"
    name     = "handle-appsync-events"
  }

  knowledge_base = {
    id                   = module.knowledge_base.knowledge_base_id
    arn                  = module.knowledge_base.knowledge_base_arn
    generation_model_arn = module.knowledge_base.generation_model_arn
  }
}


module "auth" {
  source = "./modules/auth"

  application = var.application
  environment = var.environment

}
