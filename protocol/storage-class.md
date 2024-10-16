## Storage Class

### ブロックストレージ
- `block-general`: 一般ワークロード向け(gp3, ext4)
- `block-performance`: 高性能ワークロード向け(io1, xfs)
- `block-backup`: バックアップ・アーカイブ向け(st1, ext4)
- `block-devtest`: 開発・テスト用(gp2, ext4)

### ファイルストレージ
- `file-standard`: 標準アクセス向け
- `file-ia`: 低頻度アクセス向け(EFS Infrequent Access)
- `file-dev`: 開発用(低コスト)
- `file-secure`: 共有データアクセス向け(TLS対応)
