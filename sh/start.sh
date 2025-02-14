#!/usr/bin/env bash
set -e
exec >> /var/log/ueba/start.log 2>&1

# 初回起動時のみssh用公開鍵、秘密鍵の生成
if [ ! -f /home/ueba/.ssh/id_rsa ]; then
  echo "`date '+%Y:%m:%d %H:%M:%S'` start.sh:Setup keygen..."
  # Generate ssh key
  mkdir -p /home/ueba/.ssh
  ssh-keygen -t rsa -f /home/ueba/.ssh/id_rsa -N "" -q
  chown ueba:ueba /home/ueba/.ssh/id_rsa*
  chmod 600 /home/ueba/.ssh/id_rsa
  # Copy secret key
  cp -p /home/ueba/.ssh/id_rsa /var/www/html/.ueba
  chmod 644 /var/www/html/.ueba
  # Copy public key to authorized_keys
  cat /home/ueba/.ssh/id_rsa.pub > /home/ueba/.ssh/authorized_keys
  chown ueba:ueba /home/ueba/.ssh/authorized_keys
  chmod 600 /home/ueba/.ssh/authorized_keys
fi

# 初回起動時のみcleanup.shをボリュームにコピー
if [ ! -f /home/ueba/scripts/cleanup.sh ]; then
  cp -p /home/ueba/cleanup.sh /home/ueba/scripts/cleanup.sh
fi

# ファイル到着監視の起動
echo "`date '+%Y:%m:%d %H:%M:%S'` start.sh:Starting monitoring..."
/home/ueba/monitor.sh >> /var/log/ueba/monitoring.log 2>&1 &

# SSH サーバ起動 (フォアグラウンドではなくデーモン起動)
echo "`date '+%Y:%m:%d %H:%M:%S'` start.sh:Starting SSH server..."
/usr/sbin/sshd

# crond サーバ起動
echo "`date '+%Y:%m:%d %H:%M:%S'` start.sh:Starting crond..."
/usr/sbin/crond

# Apache をフォアグラウンドで起動（コンテナが落ちないように）
echo "`date '+%Y:%m:%d %H:%M:%S'` start.sh:Starting Apache (httpd) in foreground..."
exec /usr/sbin/httpd -D FOREGROUND
echo "`date '+%Y:%m:%d %H:%M:%S'` start.sh:Apache (httpd) down..."

