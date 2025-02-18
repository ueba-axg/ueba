#!/bin/bash

set -e  # エラー時にスクリプトを終了
exec >> /var/log/ueba/sendmail.log 2>&1

# ログ出力関数
log_message() {
    echo "`date '+%Y:%m:%d %H:%M:%S'` $0:$@"
}

# 環境変数のチェック
if [[ -z "$SMTP_TO" ]]; then
    log_message "ERROR: 環境変数 SMTP_TO（宛先メールアドレス）が設定されていません。"
    exit 1
fi

if [[ -z "$SMTP_SUBJECT" ]]; then
    log_message "ERROR: 環境変数 SMTP_SUBJECT（メール件名）が設定されていません。"
    exit 1
fi

if [[ -z "$1" ]]; then
    log_message "ERROR: パラメータが設定されていません。（usage: sendmail.sh <メール本文ファイルパス>）"
    exit 1
fi

if [[ ! -f "$1" ]]; then
    log_message "ERROR: 指定されたメール本文ファイル $1 が存在しません。"
    exit 1
fi

# メールヘッダーを作成（/tmp/配下に一時ファイル）
TEMP_MAIL=$(mktemp /tmp/mailXXXXXX)
echo "Subject: $SMTP_SUBJECT" > "$TEMP_MAIL"
echo "" >> "$TEMP_MAIL"
cat "$1" >> "$TEMP_MAIL"

# メール送信
cat "$TEMP_MAIL" | msmtp "$SMTP_TO"

# 一時ファイル削除
rm -f "$TEMP_MAIL"

log_message "INFO : メールを送信しました: 宛先=$SMTP_TO, 件名=$SMTP_SUBJECT"

