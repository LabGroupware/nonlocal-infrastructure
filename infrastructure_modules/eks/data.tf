locals {
  ## Key Pair ##
  # key_pair_name = "eks-workers-keypair-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  # public_key    = "REPLACE_HERE"

  ## cluster_autoscaler_iam_role ##
  # cluster_autoscaler_iam_role_name = "EKSClusterAutoscaler"

  ## cluster_autoscaler_iam_policy ##
  # cluster_autoscaler_iam_policy_description = "EKS cluster-autoscaler policy for cluster ${module.eks_cluster.cluster_id}"
  # cluster_autoscaler_iam_policy_name        = "${local.cluster_autoscaler_iam_role_name}Policy"
  # cluster_autoscaler_iam_policy_path        = "/"

  ## test_irsa_iam_assumable_role ##
  # test_irsa_iam_role_name = "TestIrsaS3ReadOnlyRole"

  ## EFS SG ##
  # efs_security_group_name                         = "scg-${var.region_tag[var.region]}-${var.env}-efs"
  # efs_security_group_description                  = "Security group for EFS"
  # efs_ingress_with_cidr_blocks_local              = []
  # efs_ingress_with_cidr_blocks                    = []
  # efs_number_of_computed_ingress_with_cidr_blocks = 1
  # efs_computed_ingress_with_cidr_blocks = [
  #   {
  #     rule        = "nfs-tcp"
  #     cidr_blocks = var.vpc_cidr_block
  #     description = "Allow NFS 2049 from within the VPC"
  #   },
  # ]
  # efs_computed_ingress_with_source_security_group_count = 1
  # efs_computed_ingress_with_source_security_group_id = [
  #   {
  #     rule                     = "nfs-tcp"
  #     source_security_group_id = module.eks_cluster.worker_security_group_id
  #     description              = "Allow NFS 2049 from EKS worker nodes"
  #   },
  # ]
  # efs_security_group_tags = merge(
  #   var.tags,
  #   tomap({
  #     "Name" = local.efs_security_group_name
  #   })
  # )

  ## EFS ##
  # efs_encrypted = true
  # efs_tags = merge(
  #   var.tags,
  #   tomap({
  #     "Name" = "efs-${var.region_tag[var.region]}-${var.app_name}-${var.env}"
  #   })
  # )

  ########################################
  ## Access Entry
  ########################################
  access_entries = {
    cluster-administrator = {
      principal_arn     = "arn:aws:iam::123456789012:role/eks-admin"
      type              = "STANDARD"
      kubernetes_groups = []

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    developer = {
      principal_arn     = "arn:aws:iam::123456789012:role/eks-developer"
      type              = "STANDARD"
      kubernetes_groups = []

      policy_associations = {
        default-service = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSServicePolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
        cluster-read-only = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterReadOnlyPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  ########################################
  ##  KMS for K8s secret's DEK (data encryption key) encryption
  ########################################
  k8s_secret_kms_key_name                    = "alias/cmk-${var.region_tag[var.region]}-${var.env}-k8s-secret-dek"
  k8s_secret_kms_key_description             = "Kms key used for encrypting K8s secret DEK (data encryption key)"
  k8s_secret_kms_key_deletion_window_in_days = "30"
  k8s_secret_kms_key_tags = merge(
    var.tags,
    tomap({
      "Name" = local.k8s_secret_kms_key_name
    })
  )

  ########################################
  ##  KMS For EKS CloudWatch logging
  ########################################
  eks_cloudwatch_kms_key_name                    = "alias/cmk-${var.region_tag[var.region]}-${var.env}-eks-cloudwatch-logs"
  eks_cloudwatch_kms_key_description             = "Kms key used for encrypting EKS CloudWatch logs"
  eks_cloudwatch_kms_key_deletion_window_in_days = "30"
  eks_cloudwatch_kms_key_tags = merge(
    var.tags,
    tomap({
      "Name" = local.eks_cloudwatch_kms_key_name
    })
  )

  ########################################
  ##  EKS CloudWatch logging
  ########################################
  create_cloudwatch_log_group = var.create_eks && length(var.cluster_enabled_log_types) > 0 ? true : false

  ########################################
  ## EKS Security Group
  ########################################
  cluster_security_group_name        = "scg-${var.app_name}-${var.region_tag[var.region]}-${var.env}-cluster"
  cluster_security_group_description = "Security group for cluster subnets"

  ########################################
  ## EKS Node Security Group
  ########################################
  node_security_group_name        = "scg-${var.app_name}-${var.region_tag[var.region]}-${var.env}-node"
  node_security_group_description = "Security group for node subnets"

  ########################################
  ## EKS Node Group
  ########################################
  node_instance_name_prefix = "instance-${var.app_name}-${var.region_tag[var.region]}-${var.env}-"
  node_groups = { for ng in var.node_groups : ng.name => {
    create_autoscaling_group = ng.create_autoscaling_group
    name                     = "${local.node_instance_name_prefix}${ng.name}"
    ami_type                 = ng.ami_type
    instance_type            = ng.instance_type
    max_size                 = ng.max_capacity
    min_size                 = ng.min_capacity
    desired_size             = ng.desired_size # this will be ignored if cluster autoscaler is enabled

    # create_access_entry
    iam_role_arn = ""

    create_schedule = length(keys(ng.schedules)) > 0 ? true : false
    schedules       = ng.schedules

    tags = {
      "unmanaged-node"                    = "true"
      "k8s.io/cluster-autoscaler/enabled" = ng.create_autoscaling_group ? "true" : "false"
      "InstanceName"                     = "${local.node_instance_name_prefix}${ng.name}"
    }

    # # use KMS key to encrypt EKS worker node's root EBS volumes
    # # ref: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/self_managed_node_group/main.tf#L204C11-L215
    # block_device_mappings = {
    #   xvda = {
    #     device_name = "/dev/xvda"
    #     ebs = {
    #       volume_size           = 100
    #       volume_type           = "gp3"
    #       encrypted             = true
    #       delete_on_termination = true
    #     }
    #   }
    # }
    # # STEP 2 # for unmanaged nodes, taints and labels work only with extra-arg, not ASG tags. Ref: https://aws.amazon.com/blogs/opensource/improvements-eks-worker-node-provisioning/
    # bootstrap_extra_args = "--kubelet-extra-args '--node-labels=env=prod,unmanaged-node=true,k8s_namespace=prod  --register-with-taints=prod-only=true:NoSchedule'"

    # # this userdata will 1) block access to metadata to avoid pods from using node's IAM instance profile, 2) create /mnt/efs and auto-mount EFS to it using fstab, 3) install AWS Inspector agent, 4) install SSM agent. Note: userdata script doesn't resolve shell variable defined within
    # # UPDATE: Datadog agent needs to ping the EC2 metadata endpoint to retrieve the instance id and resolve duplicated hosts to be a single host, and currently no altenative solution so need to allow access to instance metadata unfortunately otherwise infra hosts get counted twice
    # #additional_userdata = "yum install -y iptables-services; iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP; iptables-save | tee /etc/sysconfig/iptables; systemctl enable --now iptables; sudo mkdir /mnt/efs; sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-02940981.efs.us-east-1.amazonaws.com:/ /mnt/efs; echo 'fs-02940981.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs defaults,vers=4.1 0 0' >> /etc/fstab; sudo yum install -y https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm; sudo systemctl enable amazon-ssm-agent; sudo systemctl start amazon-ssm-agent"
    # # escape double qoute in TF variable to avoid /bin/bash not found error when executing install-linx.sh. Ref: https://discuss.hashicorp.com/t/how-can-i-escape-double-quotes-in-a-variable-value/4697/2
    # post_bootstrap_user_data = <<-EOT
    #   # mount EFS
    #   sudo mkdir /mnt/efs; sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-XXX.efs.us-east-1.amazonaws.com:/ /mnt/efs; echo 'fs-XXX.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs defaults,vers=4.1 0 0' >> /etc/fstab;

    #   # install Inspector agent
    #   curl -O https://inspector-agent.amazonaws.com/linux/latest/install; sudo bash install;

    #   # install SSM agent
    #   sudo yum install -y https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm; sudo systemctl enable amazon-ssm-agent; sudo systemctl start amazon-ssm-agent;
    #   EOT

    # # This is not required - demonstrates how to pass additional configuration to nodeadm
    # # Ref https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
    # cloudinit_pre_nodeadm = [
    #   {
    #     content_type = "application/node.eks.aws"
    #     content      = <<-EOT
    #         ---
    #         apiVersion: node.eks.aws/v1alpha1
    #         kind: NodeConfig
    #         spec:
    #           kubelet:
    #             config:
    #               shutdownGracePeriod: 30s
    #               featureGates:
    #                 DisableKubeletCloudCredentialProviders: true
    #       EOT
    #   }
    # ]
  } }
}

# current account ID
data "aws_caller_identity" "this" {}

# data "aws_iam_policy_document" "cluster_autoscaler" {
#   statement {
#     sid    = "clusterAutoscalerAll"
#     effect = "Allow"

#     actions = [
#       "autoscaling:DescribeAutoScalingGroups",
#       "autoscaling:DescribeAutoScalingInstances",
#       "autoscaling:DescribeLaunchConfigurations",
#       "autoscaling:DescribeTags",
#       "ec2:DescribeLaunchTemplateVersions",
#       "ec2:DescribeInstanceTypes"
#     ]

#     resources = ["*"]
#   }

#   statement {
#     sid    = "clusterAutoscalerOwn"
#     effect = "Allow"

#     actions = [
#       "autoscaling:SetDesiredCapacity",
#       "autoscaling:TerminateInstanceInAutoScalingGroup",
#       "autoscaling:UpdateAutoScalingGroup",
#     ]

#     resources = ["*"]

#     # limit who can assume the role
#     # ref: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts-technical-overview.html
#     # ref: https://www.terraform.io/docs/providers/aws/r/eks_cluster.html#enabling-iam-roles-for-service-accounts

#     # [FIXED by using correct tag] ISSUE with below: SetDesiredCapacity operation: User: arn:aws:sts::XXX:assumed-role/EKSClusterAutoscaler/botocore-session-1588872862 is not authorized to perform: autoscaling:SetDesiredCapacity on resource: arn:aws:autoscaling:us-east-1:XXX:autoScalingGroup:b44f55c0-a6a9-4689-8651-7a72b7c6300a:autoScalingGroupName/eks-ue1-prod-XXX-api-infra-worker-group-staging-120200507173038542300000005
#     condition {
#       test     = "StringEquals"
#       variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks_cluster.cluster_id}"
#       values   = ["shared"]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
#       values   = ["true"]
#     }
#   }
# }

# # ref: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/launch_templates_with_managed_node_groups/disk_encryption_policy.tf
# # This policy is required for the KMS key used for EKS root volumes, so the cluster is allowed to enc/dec/attach encrypted EBS volumes
# data "aws_iam_policy_document" "ebs_decryption" {
#   # Copy of default KMS policy that lets you manage it
#   statement {
#     sid    = "Allow access for Key Administrators"
#     effect = "Allow"

#     principals {
#       type        = "AWS"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
#     }

#     actions = [
#       "kms:*"
#     ]

#     resources = ["*"]
#   }

#   # Required for EKS
#   statement {
#     sid    = "Allow service-linked role use of the CMK"
#     effect = "Allow"

#     principals {
#       type = "AWS"
#       identifiers = [
#         "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
#         module.eks_cluster.cluster_iam_role_arn,
#         "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root", # required for the cluster / persistentvolume-controller to create encrypted PVCs
#       ]
#     }

#     actions = [
#       "kms:Encrypt",
#       "kms:Decrypt",
#       "kms:ReEncrypt*",
#       "kms:GenerateDataKey*",
#       "kms:DescribeKey"
#     ]

#     resources = ["*"]
#   }

#   statement {
#     sid    = "Allow attachment of persistent resources"
#     effect = "Allow"

#     principals {
#       type = "AWS"
#       identifiers = [
#         "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
#         module.eks_cluster.cluster_iam_role_arn,                                                                                                 # required for the cluster / persistentvolume-controller to create encrypted PVCs
#       ]
#     }

#     actions = [
#       "kms:CreateGrant"
#     ]

#     resources = ["*"]

#     condition {
#       test     = "Bool"
#       variable = "kms:GrantIsForAWSResource"
#       values   = ["true"]
#     }

#   }
# }

# data "aws_iam_policy_document" "k8s_api_server_decryption" {
#   # Copy of default KMS policy that lets you manage it
#   statement {
#     sid    = "Allow access for Key Administrators"
#     effect = "Allow"

#     principals {
#       type        = "AWS"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
#     }

#     actions = [
#       "kms:*"
#     ]

#     resources = ["*"]
#   }

#   # Required for EKS
#   statement {
#     sid    = "Allow service-linked role use of the CMK"
#     effect = "Allow"

#     principals {
#       type = "AWS"
#       identifiers = [
#         module.eks_cluster.cluster_iam_role_arn, # required for the cluster / persistentvolume-controller
#         "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root",
#       ]
#     }

#     actions = [
#       "kms:Encrypt",
#       "kms:Decrypt",
#       "kms:ReEncrypt*",
#       "kms:GenerateDataKey*",
#       "kms:DescribeKey"
#     ]

#     resources = ["*"]
#   }

#   statement {
#     sid    = "Allow attachment of persistent resources"
#     effect = "Allow"

#     principals {
#       type = "AWS"
#       identifiers = [
#         module.eks_cluster.cluster_iam_role_arn, # required for the cluster / persistentvolume-controller to create encrypted PVCs
#       ]
#     }

#     actions = [
#       "kms:CreateGrant"
#     ]

#     resources = ["*"]

#     condition {
#       test     = "Bool"
#       variable = "kms:GrantIsForAWSResource"
#       values   = ["true"]
#     }
#   }
# }

# data "aws_iam_policy_document" "assume_role_policy" {
#   statement {
#     sid     = "EKSClusterAssumeRole"
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["eks.amazonaws.com"]
#     }
#   }
# }

############################################
## IAM Policy
############################################

# For EKS Secret Encryption
# data "aws_iam_policy" "s3_read_only_access_policy" {
#   arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }

# For CloudWatch logging
data "aws_iam_policy_document" "cloudwatch" {
  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        format(
          "logs.%s.amazonaws.com",
          var.region
        )
      ]
    }
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        format(
          "arn:aws:logs:%s:%s:log-group:*",
          var.region,
          data.aws_caller_identity.this.account_id
        )
      ]
    }
  }
}
