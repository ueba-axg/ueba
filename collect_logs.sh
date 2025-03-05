#!/bin/bash

set -e  # エラー時にスクリプトを終了

#!/bin/bash

LOG_DIR=./ueba-logs
TGZFILE=ueba-logs.tgz

# 既定のディレクトリでログ収集していることを確認
echo "ueba-eng のログを収集します..."
if [ ! -f "docker-compose.yml" ]; then
    echo "エラー: docker-compose.yml が見つかりません。スクリプトを終了します。"
    exit 1
fi

# ueba_engコンテナの /var/www/htpasswd をコピー
mkdir -p "$LOG_DIR/var/www/htpasswd"
docker cp ueba_eng:/var/www/htpasswd "$LOG_DIR/var/www/htpasswd"

# ueba_engコンテナの /home/ueba/.sshをコピー
mkdir -p "$LOG_DIR/home/ueba/.ssh"
docker cp ueba_eng:/home/ueba/.ssh "$LOG_DIR/home/ueba/.ssh"

# docker-compose.yml, .env ファイルをコピー
if [[ "$1" == "all" ]]; then
  echo "all が指定されました。処理を実行します。"
  cp -pR docker-compose.yml .env install.sh logs reports/*.xlsx uploads/* $LOG_DIR
else
  echo "all ではありません。通常処理を実行します。"
  cp -pR docker-compose.yml .env install.sh logs $LOG_DIR
  mkdir -p "$LOG_DIR/reports" "$LOG_DIR/uploads"
  cp -p reports/*.xlsx $LOG_DIR/reports
  cp -p uploads/*.log  $LOG_DIR/uploads
fi





# ログディレクトリを .tgz 形式で圧縮
tar -czf "$TGZFILE" -C "$LOG_DIR" .

# 完了メッセージ
echo "$TGZFILE にログを収集しました。"

