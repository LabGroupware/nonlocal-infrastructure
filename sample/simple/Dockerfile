# 使用するベースイメージ
FROM golang:1.23-alpine

# アプリケーションディレクトリを設定
WORKDIR /app

# Goアプリケーションのソースコードをコンテナにコピー
COPY . .

# アプリケーションをビルド
RUN go build -o hostapp

# コンテナ起動時にアプリケーションを実行
CMD ["./hostapp"]
