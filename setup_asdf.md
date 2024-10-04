## asdf

### インストール
``` sh
git clone https://github.com/asdf-vm/asdf.git ~/.asdf
echo -e "\n. $HOME/.asdf/asdf.sh" >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
source ~/.bashrc
```

### 確認
``` sh
asdf version
```

### 必要なプラグインをインストール(.tool-versionsより)
``` sh
asdf install
```

### プラグイン一覧取得
``` sh
asdf plugin-list-all
```

### プラグインの追加
``` sh
asdf plugin add <プラグイン名>
```

### インストール済みのプラグインを確認
``` sh
asdf plugin list
```

### プラグインの削除
``` sh
asdf plugin remove <プラグイン名>
```

### プラグインで使用可能なバージョンの一覧表示
``` sh
asdf list all <プラグイン名>
```

### プラグインのバージョンをインストールする
``` sh
asdf install <プラグイン名> <バージョン>
```

### グローバル環境で使うバージョンを固定
``` sh
asdf global <プラグイン名> <バージョン>
```

### ディレクトリ単位でバージョンを固定
``` sh
asdf local <プラグイン名> <バージョン>
```

### asdf自体のアップデート
``` sh
asdf update
```

### すべてのプラグインのアップデート
``` sh
asdf plugin-update --all
```

### 一部のプラグインのみのアップデート
``` sh
asdf plugin-update <プラグイン名>
```