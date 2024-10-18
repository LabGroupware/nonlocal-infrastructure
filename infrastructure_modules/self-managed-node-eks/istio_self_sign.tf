# ##############################################
# # Self Signed Certificate
# ##############################################
# resource "tls_private_key" "ca_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }

# # CA証明書の作成
# resource "tls_self_signed_cert" "ca_cert" {
#   allowed_uses    = ["cert_signing", "key_encipherment", "digital_signature"]
#   private_key_pem = tls_private_key.ca_key.private_key_pem
#   subject {
#     common_name  = var.public_root_domain_name
#     organization = var.cluster_name
#   }

#   validity_period_hours = 365 * 24
#   is_ca_certificate     = true
# }

# # ドメインの秘密鍵
# resource "tls_private_key" "domain_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }

# # ドメイン証明書の署名要求 (CSR) を生成
# resource "tls_cert_request" "domain_csr" {
#   private_key_pem = tls_private_key.domain_key.private_key_pem

#   subject {
#     common_name  = var.public_root_domain_name
#     organization = var.cluster_name
#   }

#   dns_names = [
#     var.public_root_domain_name,
#     "*.${var.public_root_domain_name}"
#   ]
# }

# # ドメイン証明書をCAで署名
# resource "tls_locally_signed_cert" "signed_domain_cert" {
#   cert_request_pem   = tls_cert_request.domain_csr.cert_request_pem
#   ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem
#   ca_private_key_pem = tls_private_key.ca_key.private_key_pem

#   allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
#   validity_period_hours = 30 * 24
# }

# # Kubernetes Secretに保存
# resource "kubernetes_secret" "istio_tls_secret" {
#   depends_on = [helm_release.istio_base]
#   metadata {
#     name      = local.cert_secret_name
#     namespace = local.istio_namespace
#   }

#   data = {
#     "tls.crt" = tls_locally_signed_cert.signed_domain_cert.cert_pem
#     "tls.key" = tls_private_key.domain_key.private_key_pem
#   }

#   type = "kubernetes.io/tls"
# }

# ##############################################
# # Private Certificate CronJob
# ##############################################
# # ConfigMapに証明書更新スクリプトを保存
# resource "kubernetes_config_map_v1" "cert_renewal_script" {
#   depends_on = [helm_release.istio_base]
#   metadata {
#     name      = "cert-renewal-script"
#     namespace = local.istio_namespace
#   }

#   data = {
#     "cert-renewal.sh" = <<EOT
# #!/bin/bash
# # 一時ディレクトリを作成
# mkdir -p /tmp/certs

# # CA秘密鍵と証明書の生成
# openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
#   -keyout /tmp/certs/ca_key.pem \
#   -out /tmp/certs/ca_cert.pem \
#   -subj "/CN=${var.public_root_domain_name}/O=${var.cluster_name}" \
#   -sha256

# # ドメインの秘密鍵を生成
# openssl genrsa -out /tmp/certs/domain_key.pem 2048

# # ドメイン証明書のCSRを生成
# openssl req -new -key /tmp/certs/domain_key.pem -out /tmp/certs/domain.csr -subj "/CN=${var.public_root_domain_name}/O=${var.cluster_name}"

# # ドメイン証明書をCAで署名
# openssl x509 -req -in /tmp/certs/domain.csr -CA /tmp/certs/ca_cert.pem -CAkey /tmp/certs/ca_key.pem -CAcreateserial \
#   -out /tmp/certs/domain_cert.pem -days 365 -sha256 -extensions v3_req -extfile <(echo "[v3_req]\nsubjectAltName=DNS:${var.public_root_domain_name},DNS:*.${var.public_root_domain_name}")

# # Kubernetes Secretの更新
# kubectl create secret tls ${local.cert_secret_name} --key=/tmp/certs/domain_key.pem --cert=/tmp/certs/domain_cert.pem -n ${local.istio_namespace} --dry-run=client -o yaml | kubectl apply -f -
# EOT
#   }
# }

# resource "kubernetes_cron_job_v1" "cert_renewal_job" {
#   depends_on = [helm_release.istio_base]
#   metadata {
#     name      = "cert-renewal-job"
#     namespace = local.istio_namespace
#   }

#   spec {
#     schedule = "0 0 */10 * *"
#     job_template {
#       metadata {
#         name = "cert-renewal-job"
#       }
#       spec {
#         template {
#           metadata {
#             name = "cert-renewal-job"
#           }
#           spec {
#             container {
#               name    = "cert-renewal"
#               image   = "bitnami/kubectl:latest" # kubectlが含まれた軽量イメージ
#               command = ["/bin/bash", "-c"]
#               args    = ["/tmp/cert-renewal.sh"] # ConfigMapに保存されたスクリプトを実行
#               volume_mount {
#                 name       = "script-volume"
#                 mount_path = "/tmp"
#               }
#             }
#             restart_policy = "OnFailure"

#             volume {
#               name = "script-volume"
#               config_map {
#                 name = kubernetes_config_map_v1.cert_renewal_script.metadata[0].name # ConfigMapの参照
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }
