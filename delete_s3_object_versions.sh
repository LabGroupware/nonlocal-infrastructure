#!/bin/bash

# バケット名とキー名を引数から取得
BUCKET_NAME=$1
OBJECT_KEY=$2
REGION=$3

# バケット名とキー名が指定されているかを確認
if [ -z "$BUCKET_NAME" ] || [ -z "$OBJECT_KEY" ] || [ -z "$REGION" ]; then
  echo "Usage: $0 <bucket_name> <object_key> <region>"
  exit 1
fi

# すべてのバージョンを削除
echo "Deleting all versions of the object $OBJECT_KEY in bucket $BUCKET_NAME..."
aws s3api list-object-versions --bucket "$BUCKET_NAME" --prefix "$OBJECT_KEY" --query 'Versions[].{Key:Key,VersionId:VersionId}' --region "$REGION" --output json | \
jq -c '.[]' | \
while read -r item; do
  key=$(echo "$item" | jq -r .Key)
  versionId=$(echo "$item" | jq -r .VersionId)
  echo "Deleting version $versionId of $key..."
  aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$versionId" --region "$REGION"
done

# 削除マーカーを削除
echo "Deleting all delete markers of the object $OBJECT_KEY in bucket $BUCKET_NAME..."
aws s3api list-object-versions --bucket "$BUCKET_NAME" --prefix "$OBJECT_KEY" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --region "$REGION" --output json | \
jq -c '.[]' | \
while read -r item; do
  key=$(echo "$item" | jq -r .Key)
  versionId=$(echo "$item" | jq -r .VersionId)
  echo "Deleting delete marker $versionId of $key..."
  aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$versionId" --region "$REGION"
done

echo "All versions and delete markers of $OBJECT_KEY in bucket $BUCKET_NAME have been deleted."
