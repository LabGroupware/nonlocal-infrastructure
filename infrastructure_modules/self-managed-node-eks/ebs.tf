## EBS CSI Role and Policy
##########################################################################################
# Using Module
##########################################################################################
module "ebs_csi_iam_role" {
  source = "../../resource_modules/identity/iam/modules/iam-role-for-service-accounts-eks"

  create_role = var.create_eks && var.enable_ebs_csi

  role_name             = format("%s-ebs-csi", var.cluster_name)
  role_description      = "IAM role for EBS CSI Driver"
  role_path             = local.iam_role_path
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

##########################################################################################
# Manual
##########################################################################################
# # Datasource: EBS CSI IAM Policy get from EBS GIT Repo (latest)
# data "http" "ebs_csi_iam_policy" {
#   url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/docs/example-iam-policy.json"

#   # Optional request headers
#   request_headers = {
#     Accept = "application/json"
#   }
# }

# # Resource: Create EBS CSI IAM Policy
# resource "aws_iam_policy" "ebs_csi_iam_policy" {
#   name        = "tesst-AmazonEKS_EBS_CSI_Driver_Policy"
#   path        = "/"
#   description = "EBS CSI IAM Policy"
#   policy      = data.http.ebs_csi_iam_policy.response_body
# }

# # Resource: Create IAM Role and associate the EBS IAM Policy to it
# resource "aws_iam_role" "ebs_csi_iam_role" {
#   name = "tesst-ebs-csi-iam-role"

#   # Terraform's "jsonencode" function converts a Terraform expression result to valid JSON syntax.
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Effect = "Allow"
#         Sid    = ""
#         Principal = {
#           Federated = "${data.terraform_remote_state.eks.outputs.aws_iam_openid_connect_provider_arn}"
#         }
#         Condition = {
#           StringEquals = {
#             "${data.terraform_remote_state.eks.outputs.aws_iam_openid_connect_provider_extract_from_arn}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
#           }
#         }

#       },
#     ]
#   })
# }

# # Associate EBS CSI IAM Policy to EBS CSI IAM Role
# resource "aws_iam_role_policy_attachment" "ebs_csi_iam_role_policy_attach" {
#   policy_arn = aws_iam_policy.ebs_csi_iam_policy.arn
#   role       = aws_iam_role.ebs_csi_iam_role.name
# }


## EBS CSI Driver

##########################################################################################
# Using Addon
##########################################################################################
resource "aws_eks_addon" "ebs_eks_addon" {
  depends_on               = [module.ebs_csi_iam_role]
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_iam_role.iam_role_arn
}


##########################################################################################
# Using HELM
##########################################################################################
# Install EBS CSI Driver using HELM
# Resource: Helm Release
# resource "helm_release" "ebs_csi_driver" {
#   depends_on = [aws_iam_role.ebs_csi_iam_role]
#   name       = "${local.name}-aws-ebs-csi-driver"
#   repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
#   chart      = "aws-ebs-csi-driver"
#   namespace = "kube-system"

#   set {
#     name = "image.repository"
#     value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-ebs-csi-driver" # Changes based on Region - This is for us-east-1 Additional Reference: https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
#   }

#   set {
#     name  = "controller.serviceAccount.create"
#     value = "true"
#   }

#   set {
#     name  = "controller.serviceAccount.name"
#     value = "ebs-csi-controller-sa"
#   }

#   set {
#     name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = "${aws_iam_role.ebs_csi_iam_role.arn}"
#   }

# }
