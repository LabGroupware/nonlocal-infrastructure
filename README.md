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

``` sh
AWS Access Key ID [None]: {アクセスキー}
AWS Secret Access Key [None]: {シークレットキー}
Default region name [None]: ap-northeast-1
Default output format [None]: json
```
