
resource "aws_cognito_user_pool" "main" {
  name = "${var.application}-${var.environment}-user-pool"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }
}

resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.application}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = ["http://localhost:5173/callback"]
  logout_urls                          = ["http://localhost:5173/logout"]

  supported_identity_providers = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.application}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}


