# Secret

## Secret関連作成
作成するSAは, 作成するPodと同じNamespaceにする.
``` sh
./create_secret.sh <secret-name> <secret-value-path> <service-account-name> <namespace> <clustername> <region>
```

## Secret関連削除
``` sh
./cleanup_resources.sh <secret-name> <service-account-name> <namespace> <clustername> <region>
```

## Secret Provider Class

- `SecretProviderClass は、必ずそれを参照する Pod と同じ Namespace に作成`すること.
- objectTypeが`secretsmanager`であること.
``` yml
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aws-secrets
spec:
  provider: aws
  parameters:                    # プロバイダー固有のパラメーター
    objects:  |
      - objectName: "MySecret2"
        objectType: "secretsmanager"
```

## Podからの参照方法
- NamespaceがSA, Secret Provider Classと同一であること
- serviceAccountNameが先ほど作成したserviceaccountと一致すること
- secretProviderClassの名前が先ほど作成したSecretProviderClassと一致すること
``` yml
kind: Pod
apiVersion: v1
metadata:
  name: nginx-secrets-store-inline
spec:
  serviceAccountName: aws-node
  containers:
  - image: nginx
    name: nginx
    volumeMounts:
    - name: mysecret2
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
    - name: mysecret2
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "aws-secrets"
```

## K8S Secretとの同期

> オプションの secretObjects フィールドを使用して、同期された Kubernetes Secret オブジェクトの目的の状態を定義
> 同期にはボリュームマウントが必要

``` yml
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aws-secrets
  provider: aws
  secretObjects: #K8s Secret オブジェクトの望ましい状態を定義
    - secretName: secret-from-aws  # K8s secret名
      type: Opaque
      data:
        - objectName: test-api-key  # オブジェクト名またはオブジェクトのエイリアス
          key: api_key
  parameters:
    objects: |
        - objectName: "test-api-key"  # SecretManagerの名前、ID、ARN
          objectType: "secretsmanager"
```
以下をサポート
- Opaque
- kubernetes.io/basic-auth
- bootstrap.kubernetes.io/token
- kubernetes.io/dockerconfigjson
- kubernetes.io/dockercfg
- kubernetes.io/ssh-auth
- kubernetes.io/service-account-token
- kubernetes.io/tls


以下は、同期された Kubernetes Secret から環境変数を作成する Deployment YAML.
``` yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envtest-deployment
  namespace: secret-ns
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      serviceAccountName: secret-demo-sa
      volumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "secrets-from-env"
      containers:
      - name: envtest-deployment
        image: nginx
        ports:
        - containerPort: 80
        env: # 環境変数として利用
          - name: API_KEY
            valueFrom:
              secretKeyRef:
                name: secret-from-aws # test_api_keyの中にあるapi_keyの値にアクセス
                key: api_key
        volumeMounts: # volumeとしてマウント
        - name: secrets-store-inline
          mountPath: "/mnt/secrets-store"
          readOnly: true
```
