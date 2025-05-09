variable "application" {
  type = string
}

variable "environment" {
  type = string
}

variable "db" {
  type = object({
    name            = string
    master_username = string
    min_capacity    = number
    max_capacity    = number
  })
}

variable "seed_db_function" {
  type = object({
    dist_dir = string
    handler  = string
    name     = string
  })
}



variable "vpc_id" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}
