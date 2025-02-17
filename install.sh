#!/bin/bash

set -e  # エラー時にスクリプトを終了

# データ保持期間の入力
DEFAULT_DAYS=90
while true; do
    read -p "データ保持期間（日数）を入力してください（デフォルト: $DEFAULT_DAYS）: " DATA_KEEP_DAYS
    
    # デフォルト値を適用
    if [ -z "$DATA_KEEP_DAYS" ]; then
        DATA_KEEP_DAYS=$DEFAULT_DAYS
    fi
    
    # 数値チェック
    if ! [[ "$DATA_KEEP_DAYS" =~ ^[0-9]+$ ]]; then
        echo "エラー: 数値を入力してください。"
        continue
    fi
    
    # 範囲チェック（1以上）
    if [ "$DATA_KEEP_DAYS" -lt 1 ]; then
        echo "エラー: 1以上の日数を入力してください。"
        continue
    fi
    
    break
done

# .env ファイルの作成
echo "DATA_KEEP_DAYS=$DATA_KEEP_DAYS" > .env

echo ".env ファイルが作成されました:"
cat .env

# SMTP 設定の入力とチェック
echo "SMTP サーバーの設定を行います。"

# SMTP サーバー
while true; do
    read -p "SMTP サーバーを入力してください（例: smtp.example.com）: " SMTP_SERVER
    if [[ -z "$SMTP_SERVER" ]]; then
        echo "エラー: SMTP サーバーは必須です。"
        continue
    fi
    break
done

# SMTP ポート（587, 465, 25 など）
DEFAULT_SMTP_PORT=587
while true; do
    read -p "SMTP ポートを入力してください（デフォルト: $DEFAULT_SMTP_PORT）: " SMTP_PORT
    if [ -z "$SMTP_PORT" ]; then
        SMTP_PORT=$DEFAULT_SMTP_PORT
    fi
    if ! [[ "$SMTP_PORT" =~ ^[0-9]+$ ]]; then
        echo "エラー: 数値を入力してください。"
        continue
    fi
    if [ "$SMTP_PORT" -lt 1 ] || [ "$SMTP_PORT" -gt 65535 ]; then
        echo "警告: 通常のポート範囲（1-65535）外のポートが指定されています。"
        continue
    fi
    break
done

# SMTP 認証の有無
DEFAULT_SMTP_AUTH="on"
while true; do
    read -p "SMTP 認証を使用しますか？ (on/off, デフォルト: $DEFAULT_SMTP_AUTH): " SMTP_AUTH
    SMTP_AUTH=${SMTP_AUTH:-$DEFAULT_SMTP_AUTH}
    if [[ "$SMTP_AUTH" != "on" && "$SMTP_AUTH" != "off" ]]; then
        echo "エラー: on または off を入力してください。"
        continue
    fi
    break
done

# SMTP 認証ユーザー名（認証が "on" の場合のみ入力）
SMTP_AUTH_USER=""
SMTP_AUTH_PASS=""
if [[ "$SMTP_AUTH" == "on" ]]; then
    while true; do
        read -p "SMTP 認証ユーザー名を入力してください（例: user@example.com または user123）: " SMTP_AUTH_USER
        if [[ -z "$SMTP_AUTH_USER" ]]; then
            echo "エラー: SMTP 認証ユーザー名は必須です。"
            continue
        fi
        break
    done

    # SMTP 認証パスワード（入力を非表示）
    while true; do
        read -sp "SMTP 認証パスワードを入力してください（入力は非表示）: " SMTP_AUTH_PASS
        echo
        if [[ -z "$SMTP_AUTH_PASS" ]]; then
            echo "エラー: SMTP 認証パスワードは必須です。"
            continue
        fi
        break
    done
fi

# 送信先メールアドレス
while true; do
    read -p "送信先メールアドレス（Toアドレス）を入力してください: " SMTP_TO
    if [[ -z "$SMTP_TO" ]]; then
        echo "エラー: 送信先メールアドレスは必須です。"
        continue
    fi
    if ! [[ "$SMTP_TO" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "エラー: 有効なメールアドレスを入力してください。"
        continue
    fi
    break
done

# 送信元メールアドレス
while true; do
    read -p "送信元メールアドレス（Fromアドレス）を入力してください: " SMTP_FROM
    if [[ -z "$SMTP_FROM" ]]; then
        echo "エラー: 送信元メールアドレスは必須です。"
        continue
    fi
    if ! [[ "$SMTP_FROM" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "エラー: 有効なメールアドレスを入力してください。"
        continue
    fi
    break
done

# Subject (デフォルト：UEBA 結果レポート)
DEFAULT_SUBJECT="UEBA 結果レポート"
while true; do
    read -p "結果レポートメールの件名(タイトル)を入力してください（デフォルト: $DEFAULT_SUBJECT）: " SMTP_SUBJECT
    if [[ -z "$SUBJECT" ]]; then
        SMTP_SUBJECT=$DEFAULT_SUBJECT
    fi
    break
done

# TLS の有効化
DEFAULT_SMTP_TLS="on"
while true; do
    read -p "SMTP TLS を有効にしますか？ (on/off, デフォルト: $DEFAULT_SMTP_TLS): " SMTP_TLS
    SMTP_TLS=${SMTP_TLS:-$DEFAULT_SMTP_TLS}
    if [[ "$SMTP_TLS" != "on" && "$SMTP_TLS" != "off" ]]; then
        echo "エラー: on または off を入力してください。"
        continue
    fi
    break
done

# STARTTLS の設定
DEFAULT_SMTP_STARTTLS="on"
while true; do
    read -p "SMTP STARTTLS を有効にしますか？ (on/off, デフォルト: $DEFAULT_SMTP_STARTTLS): " SMTP_STARTTLS
    SMTP_STARTTLS=${SMTP_STARTTLS:-$DEFAULT_SMTP_STARTTLS}
    if [[ "$SMTP_STARTTLS" != "on" && "$SMTP_STARTTLS" != "off" ]]; then
        echo "エラー: on または off を入力してください。"
        continue
    fi
    break
done

# .env に書き込み
cat <<EOF >> .env
SMTP_SERVER=${SMTP_SERVER}
SMTP_PORT=${SMTP_PORT}
SMTP_AUTH=${SMTP_AUTH}
SMTP_AUTH_USER=${SMTP_AUTH_USER}
SMTP_AUTH_PASS=${SMTP_AUTH_PASS}
SMTP_FROM=${SMTP_FROM}
SMTP_TLS=${SMTP_TLS}
SMTP_STARTTLS=${SMTP_STARTTLS}
SMTP_TO=${SMTP_TO}
SMTP_SUBJECT=${SMTP=SUBJECT}
EOF

echo ".env ファイルに SMTP 設定を保存しました。"


# ueba-eng のインストール
echo "ueba-eng をインストールします..."
if [ ! -f "docker-compose.yml" ]; then
    echo "エラー: docker-compose.yml が見つかりません。スクリプトを終了します。"
    exit 1
fi

docker compose up -d

echo "ueba-eng のインストールが完了しました。"

# MSActivator のインストール確認
read -p "MSActivator をインストールしますか？ (デフォルト: yes) [yes/no]: " INSTALL_MSA
INSTALL_MSA=${INSTALL_MSA:-yes}

if [[ "$INSTALL_MSA" =~ ^(yes|y|Y|Yes|YES)$ ]]; then
    echo "MSActivator をインストールします..."
    sysctl -w vm.max_map_count=262144
    echo 'vm.max_map_count = 262144' > /etc/sysctl.d/50-msa.conf
    sysctl -p /etc/sysctl.d/50-msa.conf
    
    git clone https://github.com/ubiqube/quickstart.git
    cd quickstart
    ./scripts/install.sh
    echo "MSActivator のインストールが完了しました。"
else
    echo "MSActivator のインストールをスキップしました。"
fi

echo "すべての処理が完了しました。"

