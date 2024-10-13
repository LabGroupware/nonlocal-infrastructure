#!/bin/bash

# ロール名とセッション名を引数として受け取る
ROLE_NAME=$1
SESSION_NAME=$2

if [ -z "$ROLE_NAME" ] || [ -z "$SESSION_NAME" ]; then
  echo "Usage: $0 <role-name> <session-name>"
  exit 1
fi

# 現在のAWSアカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# AssumeRoleのためのロールARNを作成
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"

# AssumeRoleコマンドを実行して一時的な認証情報を取得
TEMP_ROLE=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $SESSION_NAME)

# 取得した認証情報を環境変数に設定
AWS_ACCESS_KEY_ID=$(echo $TEMP_ROLE | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $TEMP_ROLE | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo $TEMP_ROLE | jq -r '.Credentials.SessionToken')

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# 環境変数が正しく設定されたか確認
echo "AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN are set."

# ここで任意のAWS CLIコマンドを実行可能
# 例: S3のバケットリストを取得
# aws s3 ls
