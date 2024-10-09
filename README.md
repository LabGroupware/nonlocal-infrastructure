## LabGroupware for API Composition + State Based Pattern Implementation

### Prerequire
- [asdf](./setup_asdf.md)


### Setup
#### コマンドセットアップ
``` sh
asdf plugin add terraform
asdf plugin add awscli
asdf install
```
#### IAMユーザー作成
AWS上にAdministratorAccessを持つユーザーを作成後, アクセスキーを取得する.
#### Profile登録
``` sh
aws configure --profile terraform
```
: 内容
``` sh
AWS Access Key ID [None]: {アクセスキー}
AWS Secret Access Key [None]: {シークレットキー}
Default region name [None]: ap-northeast-1
Default output format [None]: json
```
#### プロファイル切り替え
現在のプロファイルの確認
``` sh
aws configure list
```
プロファイル切り替え
``` sh
export AWS_DEFAULT_PROFILE=terraform
```

### Life Cycle
#### Set Up
##### BackendState管理のBackend作成
backend-stateを管理するterraformファイルをstate管理するストレージの作成.
``` sh
aws s3api create-bucket --bucket s3-apne1-lg-terraform-remote-backend-state-management --region ap-northeast-1 --create-bucket-configuration LocationConstraint=ap-northeast-1
```
バージョニングを有効化
``` sh
aws s3api put-bucket-versioning --bucket s3-apne1-lg-terraform-remote-backend-state-management --versioning-configuration Status=Enabled --region ap-northeast-1
```
アカウントIDの取得
``` sh
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```
KMS作成
``` sh
export TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID=$(sed "s/{{AWS_ACCOUNT_ID}}/$AWS_ACCOUNT_ID/g" kms_policy.json | \
aws kms create-key \
  --description "KMS key for Terraform backend S3 and DynamoDB lock" \
  --policy file:///dev/stdin \
  --tags TagKey=Name,TagValue=TerraformStateManagementKMSKey \
  --region ap-northeast-1 \
  --output json | jq -r '.KeyMetadata.KeyId')
```
DynamoDB作成
``` sh
aws dynamodb create-table \
    --table-name dynamo-apne1-lg-terraform-remote-backend-state-management-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PROVISIONED \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
    --table-class STANDARD_INFREQUENT_ACCESS \
    --region ap-northeast-1 \
    --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=$TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID
```

##### State-BasedのBackend作成
State-Basedの`init`.
``` sh
terraform -chdir=composition/state-terraform-remote-backend/ap-northeast-1/prod/ init
```
確認後, apply.
``` sh
terraform -chdir=composition/state-terraform-remote-backend/ap-northeast-1/prod/ plan
terraform -chdir=composition/state-terraform-remote-backend/ap-northeast-1/prod/ apply -auto-approve
```
バケット名確認.
``` sh
S3_LG_STATE_BUCKET=$(aws s3api list-buckets --query 'Buckets[?starts_with(Name, `s3-apne1-lg-state-prod-terraform-backend`)].Name | [0]' --output text)
sed "s/{{S3_LG_STATE_BUCKET}}/$S3_LG_STATE_BUCKET/g" composition/lg-state-infra/ap-northeast-1/prod/backend.tf.template > composition/lg-state-infra/ap-northeast-1/prod/backend.tf
```
Init
``` sh
terraform -chdir=composition/lg-state-infra/ap-northeast-1/prod init
```
##### Event-SourcingのBackend作成
State-Basedの`init`.
``` sh
terraform -chdir=composition/event-terraform-remote-backend/ap-northeast-1/prod/ init
```
確認後, apply.
``` sh
terraform -chdir=composition/event-terraform-remote-backend/ap-northeast-1/prod/ plan
terraform -chdir=composition/event-terraform-remote-backend/ap-northeast-1/prod/ apply -auto-approve
```
バケット名確認.
``` sh
S3_LG_EVENT_BUCKET=$(aws s3api list-buckets --query 'Buckets[?starts_with(Name, `s3-apne1-lg-event-prod-terraform-backend`)].Name | [0]' --output text)
sed "s/{{S3_LG_EVENT_BUCKET}}/$S3_LG_EVENT_BUCKET/g" composition/lg-event-infra/ap-northeast-1/prod/backend.tf.template > composition/lg-event-infra/ap-northeast-1/prod/backend.tf
```
Init
``` sh
terraform -chdir=composition/lg-event-infra/ap-northeast-1/prod init
```
#### State研究の開始時
terraform applyの実行
``` sh
terraform -chdir=composition/lg-state-infra/ap-northeast-1/prod apply
```

#### State研究の終了時
terraform destroyの実行
``` sh
terraform -chdir=composition/lg-state-infra/ap-northeast-1/prod destroy
```

#### Clean Up
> クリーンアップ開始前に研究終了時の手順が完了していることを確認する.
##### State-BasedのBackend削除
S3内オブジェクトの削除
``` sh
sudo chmod +x delete_s3_object_versions.sh
S3_LG_STATE_BUCKET=$(aws s3api list-buckets --query 'Buckets[?starts_with(Name, `s3-apne1-lg-state-prod-terraform-backend`)].Name | [0]' --output text)
./delete_s3_object_versions.sh $S3_LG_STATE_BUCKET lg-state-infra/ap-northeast-1/prod/terraform.tfstate
```
State-Basedの`destroy`.
``` sh
terraform -chdir=composition/state-terraform-remote-backend/ap-northeast-1/prod/ destroy
```

##### Event-SourcingのBackend削除
S3内オブジェクトの削除
``` sh
S3_LG_EVENT_BUCKET=$(aws s3api list-buckets --query 'Buckets[?starts_with(Name, `s3-apne1-lg-event-prod-terraform-backend`)].Name | [0]' --output text)
./delete_s3_object_versions.sh $S3_LG_EVENT_BUCKET lg-event-infra/ap-northeast-1/prod/terraform.tfstate
```
State-Basedの`destroy`.
``` sh
terraform -chdir=composition/event-terraform-remote-backend/ap-northeast-1/prod/ destroy
```
##### BackendState管理のBackend削除
DynamoDB削除
``` sh
aws dynamodb delete-table --table-name dynamo-apne1-lg-terraform-remote-backend-state-management-lock --region ap-northeast-1
```
KMS削除
``` sh
# Keys Retrieve
TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID=$(aws kms list-keys --query 'Keys[*].KeyId' --output text | tr '\t' ' ')

# Tag Filtering
tag_hit_keys=$(echo $TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID | tr -d '\n' | xargs -I{} -d ' ' \
aws kms list-resource-tags --key-id {} --query 'length(Tags[?TagKey==`Name` && TagValue==`TerraformStateManagementKMSKey`])')
tag_hit_indexes=$(echo $tag_hit_keys | awk '{for(i=1; i<=NF; i++) if($i != 0) print i}' | xargs)
TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID=$(echo $TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID | awk -v indices="$tag_hit_indexes" '{split(indices, idx, " "); for(i in idx) printf $idx[i]" "}')

# Enabled Filtering
enabled_keys=$(echo $TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID | tr -d '\n' | xargs -I{} -d ' ' \
aws kms describe-key --key-id {} --query 'KeyMetadata.KeyState==`Enabled`' --output text | sed 's/False/0/g; s/True/1/g')
enabled_indexes=$(echo $enabled_keys | awk '{for(i=1; i<=NF; i++) if($i != 0) print i}' | xargs)
TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID=$(echo $TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID | awk -v indices="$enabled_indexes" '{split(indices, idx, " "); for(i in idx) printf $idx[i]" "}')

# Cut
TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID=$(echo $TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID | cut -d' ' -f1)

aws kms schedule-key-deletion --key-id $TERRAFORM_BACKEND_MANAGEMENT_KMS_KEY_ID --pending-window-in-days 7 --region ap-northeast-1
```
S3削除
``` sh
S3_LG_STATE_MANAGE_BUCKET="s3-apne1-lg-terraform-remote-backend-state-management"
./delete_s3_object_versions.sh $S3_LG_STATE_MANAGE_BUCKET lg-state-infra/ap-northeast-1/prod/terraform.tfstate
./delete_s3_object_versions.sh $S3_LG_STATE_MANAGE_BUCKET lg-event-infra/ap-northeast-1/prod/terraform.tfstate

aws s3api delete-bucket --bucket $S3_LG_STATE_MANAGE_BUCKET --region ap-northeast-1
```
