#!/bin/bash

REGION=$1

if [ -z "$REGION" ]; then
  echo "Usage: $0 <region>"
  exit 1
fi

case "$REGION" in
  "ap-northeast-1")
    SHORT_REGION="apne1"
    ;;
  "us-east-1")
    SHORT_REGION="use1"
    ;;
  "eu-west-1")
    SHORT_REGION="euw1"
    ;;
  # 必要に応じて他のマッピングを追加
  *)
    echo "Unknown region: $REGION"
    exit 1
    ;;
esac

BASTION_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=bastion-host-${SHORT_REGION}-prod-lg-state-infra" \
    --query "Reservations[*].Instances[*].PublicIpAddress" \
    --output text)
NODE_DOMAIN=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=instance-lg-state-infra-${SHORT_REGION}-prod-app-1" \
    --query "Reservations[*].Instances[*].PrivateDnsName | [0]" \
    --output text)
BASE_DIR="$(pwd)"

# SSH Configの保存先
SSH_CONFIG_DIR="${BASE_DIR}/.ssh"
SSH_CONFIG_FILE="${SSH_CONFIG_DIR}/config"

# 鍵ファイルのパス
BASTION_KEY="${BASE_DIR}/composition/lg-state-infra/${REGION}/prod/.keys/bastion.id_rsa"
NODE_KEY="${BASE_DIR}/composition/lg-state-infra/${REGION}/prod/.keys/eks-node.id_rsa"

# .sshディレクトリが存在しない場合は作成
if [ ! -d "${SSH_CONFIG_DIR}" ]; then
  mkdir -p "${SSH_CONFIG_DIR}"
  chmod 700 "${SSH_CONFIG_DIR}"
fi

# SSH Configの内容を生成
cat <<EOL > "${SSH_CONFIG_FILE}"
Host lg_bastion
    HostName ${BASTION_IP}
    User ec2-user
    IdentityFile ${BASTION_KEY}

Host lg_eks_node
    HostName ${NODE_DOMAIN}
    User ec2-user
    IdentityFile ${NODE_KEY}
    ProxyJump lg_bastion
EOL

# 設定ファイルに正しいパーミッションを設定
chmod 600 "${SSH_CONFIG_FILE}"

# メッセージ
echo "SSH config file has been created at ${SSH_CONFIG_FILE}"
