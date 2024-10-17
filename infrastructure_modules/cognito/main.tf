###########################################
## SES Email
###########################################
data "aws_ses_domain_identity" "main" {
  domain = var.ses_domain
}

###########################################
## IAM role for cognito email
###########################################
# IAM role for cognito sms
resource "aws_iam_role" "cognito_sms" {
  name        = "${var.admin_pool_name}-SMS"
  description = "IAM role for cognito sms - ${var.admin_pool_name}"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Condition = {
            StringEquals = {
              "sts:ExternalId" = "${var.sms_external_id}"
            }
          }
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "cognito-idp.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  force_detach_policies = false
  max_session_duration  = 3600
}

resource "aws_iam_role_policy" "cognito_sms" {
  name = "cognito_sms"
  role = aws_iam_role.cognito_sms.name
  policy = jsonencode(
    {
      Statement = [
        {
          Action   = ["sns:publish"]
          Effect   = "Allow"
          Resource = ["*"]
        },
      ]
      Version = "2012-10-17"
    }
  )
}

###########################################
## Cognito User Pool
###########################################
resource "aws_cognito_user_pool" "admin_pool" {
  name = var.admin_pool_name

  auto_verified_attributes = ["email"]
  alias_attributes         = ["email"]
  mfa_configuration        = "OPTIONAL"

  # # ユーザー登録時の検証メッセージの内容
  verification_message_template {
    # 検証にはトークンではなく、リンクを使用する
    default_email_option  = "CONFIRM_WITH_LINK"
    email_message         = " 検証コードは {####} です。"
    email_message_by_link = " E メールアドレスを検証するには、次のリンクをクリックしてください。{##Verify Email##} "
    email_subject         = " 検証コード"
    email_subject_by_link = " 検証リンク"
    sms_message           = " 検証コードは {####} です。"
  }

  sms_authentication_message = " 認証コードは {####} です。"
  sms_configuration {
    external_id    = var.sms_external_id
    sns_caller_arn = aws_iam_role.cognito_sms.arn
  }

  # メール設定
  email_configuration {
    email_sending_account = "DEVELOPER"
    from_email_address    = var.cognito_from_address
    source_arn            = data.aws_ses_domain_identity.main.arn
  }

  # schema {
  #   attribute_data_type      = "String"
  #   developer_only_attribute = false
  #   mutable                  = true
  #   name                     = "email"
  #   required                 = true

  #   string_attribute_constraints {
  #     max_length = "2048"
  #     min_length = "0"
  #   }
  # }

  # パスワードを忘れたときのemailでのアカウント復元可能
  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }

  # 任意ユーザーの作成を許可しない(管理者のみ作成可能)
  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_message = " ユーザー名は {username}、仮パスワードは {####} です。"
      email_subject = " 仮パスワード"
      sms_message   = " ユーザー名は {username}、仮パスワードは {####} です。"
    }
  }

  username_configuration {
    # ユーザー名(Email)で大文字小文字を区別しない
    case_sensitive = false
  }

  # 登録するユーザーのパスワードポリシー。
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true # 英小文字
    require_numbers                  = true # 数字
    require_symbols                  = true # 記号
    require_uppercase                = true # 英大文字
    temporary_password_validity_days = 7    # 初期登録時の一時的なパスワードの有効期限
  }

  tags = var.tags

  software_token_mfa_configuration {
    enabled = true
  }
}

###########################################
## ACM Certificate
###########################################
data "aws_route53_zone" "route53_zone" {
  name = var.route53_zone_domain_name
}

resource "aws_acm_certificate" "public_auth" {
  domain_name               = "*.${var.auth_domain}"
  subject_alternative_names = [var.auth_domain]
  validation_method         = "DNS"

  provider = aws.virginia

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "auth_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.public_auth.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = var.aws_route53_record_ttl

  zone_id = data.aws_route53_zone.route53_zone.id

  depends_on = [aws_acm_certificate.public_auth]
}

resource "aws_acm_certificate_validation" "auth_cert_valid" {
  certificate_arn         = aws_acm_certificate.public_auth.arn
  validation_record_fqdns = [for record in aws_route53_record.auth_cert_validation : record.fqdn]

  provider = aws.virginia
}

###########################################
## Cognito User Pool Domain
###########################################
# Custom domain is not a valid subdomain: Was not able to resolve the root domain, please ensure an A record exists for the root domain.
resource "aws_route53_record" "root" {
  count = var.has_root_domain_a_record ? 0 : 1

  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = var.admin_domain
  type    = "A"
  ttl     = 300
  records = ["127.0.0.1"]
}

resource "aws_cognito_user_pool_domain" "main" {
  domain          = var.auth_domain
  certificate_arn = aws_acm_certificate.public_auth.arn
  user_pool_id    = aws_cognito_user_pool.admin_pool.id

  depends_on = [aws_route53_record.root]
}

resource "aws_route53_record" "auth_public_root" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = var.auth_domain
  type    = "A"

  alias {
    evaluate_target_health = false

    name    = aws_cognito_user_pool_domain.main.cloudfront_distribution
    zone_id = aws_cognito_user_pool_domain.main.cloudfront_distribution_zone_id
  }
}

resource "aws_route53_record" "auth_public_sub" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "*.${var.auth_domain}"
  type    = "A"

  alias {
    evaluate_target_health = false

    name    = aws_cognito_user_pool_domain.main.cloudfront_distribution
    zone_id = aws_cognito_user_pool_domain.main.cloudfront_distribution_zone_id
  }
}

###########################################
## Default Admin User
###########################################
resource "aws_cognito_user" "admin_user" {
  user_pool_id = aws_cognito_user_pool.admin_pool.id
  username     = lookup(var.default_admin, "username", "admin")

  attributes = {
    email          = lookup(var.default_admin, "email", "")
    email_verified = "true"
  }

  temporary_password = lookup(var.default_admin, "temp_password", "Password123!!!")

  # パスワード設定
  # password = var.admin_password

  # 既存のメールや電話番号が他のユーザーで使用されていた場合に, ユーザーの上書きを防ぐ
  force_alias_creation = false
  # ユーザーの招待時に送信されるメッセージの配信方法（EメールやSMS）を指定
  desired_delivery_mediums = ["EMAIL"]

  # ユーザー作成時に確認メールやSMSを送信するかどうか
  # 確認メッセージが送信されないようにする
  message_action = "SUPPRESS"

  lifecycle {
    ignore_changes = [temporary_password, enabled] # 仮パスワードの変更を無視
  }
}

###########################################
## Group(Minimal)
## AWS Resourceの操作の許可などは行わない(Cognito Identity Poolとの連携)
## 単なる外部のIDPとしてのみ利用する
###########################################

resource "aws_cognito_user_group" "admin" {
  name         = "Admin"
  user_pool_id = aws_cognito_user_pool.admin_pool.id
  description  = "Admin Group"
}

resource "aws_cognito_user_group" "user" {
  name         = "User"
  user_pool_id = aws_cognito_user_pool.admin_pool.id
  description  = "User Group"
}

###########################################
## Cognito User In Group
###########################################
resource "aws_cognito_user_in_group" "admin" {
  user_pool_id = aws_cognito_user_pool.admin_pool.id
  username     = aws_cognito_user.admin_user.username
  group_name   = aws_cognito_user_group.admin.name
}
