#!/bin/bash

# 引数チェック
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <secret-name> <secret-value-path> <service-account-name> <namespace> <clustername> <region>"
  exit 1
fi

SECRET_NAME="$1"
SECRET_FILE_PATH="$2"
SERVICE_ACCOUNT_NAME="$3"
NAMESPACE="$4"
CLUSTERNAME="$5"
REGION="$6"

if [ ! -f "$SECRET_FILE_PATH" ]; then
  echo "Secret file $SECRET_FILE_PATH does not exist."
  exit 1
fi

SECRET_CONTENT=$(cat "$SECRET_FILE_PATH")

# Secrets Managerにシークレットが既に存在するか確認
SECRET_EXISTS=$(aws --region "$REGION" secretsmanager describe-secret --secret-id "$SECRET_NAME" --query 'ARN' --output text 2>/dev/null)

if [ "$SECRET_EXISTS" == "None" ] || [ -z "$SECRET_EXISTS" ]; then
  echo "Secret does not exist. Creating new secret..."

  if ! SECRET_ARN=$(aws --region "$REGION" secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$SECRET_CONTENT" --query 'ARN' --output text); then
    echo "Failed to create secret in AWS Secrets Manager."
    exit 1
  fi

  echo "Secret created successfully with ARN: $SECRET_ARN"
else
  # シークレットが存在する場合、その削除スケジュールの状態を確認
  DELETION_DATE=$(aws --region "$REGION" secretsmanager describe-secret --secret-id "$SECRET_NAME" --query 'DeletedDate' --output text 2>/dev/null)

  if [ "$DELETION_DATE" != "None" ]; then
    echo "Secret is scheduled for deletion. Restoring the secret..."

    # シークレットの削除スケジュールを取り消し
    if ! aws --region "$REGION" secretsmanager restore-secret --secret-id "$SECRET_NAME"; then
      echo "Failed to restore secret in AWS Secrets Manager."
      exit 1
    fi

    echo "Secret restored successfully."
  fi

  # シークレットの値を更新
  echo "Updating the secret value..."

  if ! aws --region "$REGION" secretsmanager update-secret --secret-id "$SECRET_NAME" --secret-string "$SECRET_CONTENT"; then
    echo "Failed to update secret in AWS Secrets Manager."
    exit 1
  fi

  echo "Secret updated successfully for: $SECRET_NAME"
fi

POLICY_NAME="${SECRET_NAME}-access-policy"

POLICY_DOCUMENT=$(
  cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": ["$SECRET_ARN"]
        }
    ]
}
EOF
)

# IAMポリシーが既に存在するか確認
POLICY_ARN=$(aws --region "$REGION" iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
    # ポリシーが存在しない場合、新規作成
    echo "IAM policy does not exist. Creating new policy..."

    if ! POLICY_ARN=$(aws --region "$REGION" iam create-policy --policy-name "$POLICY_NAME" --policy-document "$POLICY_DOCUMENT" --query 'Policy.Arn' --output text); then
        echo "Failed to create IAM policy."
        exit 1
    fi

    echo "IAM policy $POLICY_NAME created successfully with ARN: $POLICY_ARN"
else
    # ポリシーが存在する場合、更新
    echo "IAM policy already exists. Updating policy..."

    if ! aws --region "$REGION" iam create-policy-version --policy-arn "$POLICY_ARN" --policy-document "$POLICY_DOCUMENT" --set-as-default; then
        echo "Failed to update IAM policy."
        exit 1
    fi

    echo "IAM policy $POLICY_NAME updated successfully."
fi

if ! eksctl create iamserviceaccount --name "$SERVICE_ACCOUNT_NAME" --region "$REGION" --namespace "$NAMESPACE" --cluster "$CLUSTERNAME" --attach-policy-arn "$POLICY_ARN" --approve --override-existing-serviceaccounts; then
  echo "Failed to create IAM service account."
  exit 1
fi

echo "IAM service account $SERVICE_ACCOUNT_NAME created successfully."
