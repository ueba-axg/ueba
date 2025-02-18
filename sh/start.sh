#!/usr/bin/env bash
set -e
exec >> /var/log/ueba/start.log 2>&1

# SSH ホストキーのディレクトリ
SSH_KEY_DIR="/etc/ssh"

# SSL 証明書とキーのパス
SSL_KEY="/etc/pki/tls/private/localhost.key"
SSL_CERT="/etc/pki/tls/certs/localhost.crt"

# ログ出力関数
log_message() {
    echo "`date '+%Y:%m:%d %H:%M:%S'` $0:$@"
}

# 環境変数チェック
## データ保持期間(数値であること)
if ! echo "${DATA_KEEP_DAYS}" | grep -qE '^[0-9]+$'; then
    log_message "ERROR: DATA_KEEP_DAYS must be an integer. Current value: '${DATA_KEEP_DAYS}'"
    exit 1
fi

## データ保持期間(>=1)
if [ "${DATA_KEEP_DAYS}" -lt 1 ]; then
    log_message "ERROR: DATA_KEEP_DAYS must be an integer greater than or equal to 1. Current value: '${DATA_KEEP_DAYS}'"
    exit 1
fi
log_message "INFO : データ保持日数 : ${DATA_KEEP_DAYS}日"
log_message "INFO : SMTP_SERVER : ${SMTP_SERVER}"
log_message "INFO : SMTP_PORT : ${SMTP_PORT}"
log_message "INFO : SMTP_AUTH : ${SMTP_AUTH}"
log_message "INFO : SMTP_AUTH_USER : ${SMTP_AUTH_USER}"
log_message "INFO : SMTP_AUTH_PASS: ${SMTP_AUTH_PASS}"
log_message "INFO : SMTP_FROM : ${SMTP_FROM}"
log_message "INFO : SMTP_TLS : ${SMTP_TLS}"
log_message "INFO : SMTP_STARTTLS : ${SMTP_STARTTLS}"

cat <<EOF > /etc/msmtprc
account default
host ${SMTP_SERVER}
port ${SMTP_PORT}
auth ${SMTP_AUTH}
user ${SMTP_AUTH_USER}
password ${SMTP_AUTH_PASS}
from ${SMTP_FROM}
tls ${SMTP_TLS}
tls_starttls ${SMTP_STARTTLS}
EOF
chmod 600 /etc/msmtprc

# SSH ホストキーの生成
if [ ! -f "${SSH_KEY_DIR}/ssh_host_rsa_key" ]; then
    log_message "INFO : SSH ホストキーが見つかりません。新しく生成します。"
    ssh-keygen -A
else
    log_message "INFO : 既存の SSH ホストキーが見つかりました。再生成は行いません。"
fi

# 自己署名証明書の生成例 (CN=localhost, 有効期限3650日) SSL 証明書の生成
if [ ! -f "$SSL_KEY" ] || [ ! -f "$SSL_CERT" ]; then
    log_message "INFO : SSL 証明書が見つかりません。新しく生成します。"
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout "$SSL_KEY" \
        -x509 -days 3650 \
        -out "$SSL_CERT" \
        -subj "/C=JP/ST=Tokyo/L=Chiyoda/O=MyOrg/CN=localhost"
else
    log_message "INFO : 既存の SSL 証明書が見つかりました。再生成は行いません。"
fi

# ファイル到着監視の起動
log_message "INFO : Starting File monitoring..."
/home/ueba/monitor.sh >> /var/log/ueba/monitoring.log 2>&1 &

# SSH サーバ起動 (フォアグラウンドではなくデーモン起動)
log_message "INFO : Starting SSH server..."
/usr/sbin/sshd

# crond サーバ起動
log_message "INFO : Starting crond..."
/usr/sbin/crond

# Apache をフォアグラウンドで起動（コンテナが落ちないように）
log_message "INFO : Starting Apache (httpd) in foreground..."
exec /usr/sbin/httpd -D FOREGROUND
log_message "INFO : Apache (httpd) down..."

