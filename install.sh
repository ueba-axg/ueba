#!/bin/bash

set -e  # エラー時にスクリプトを終了

#!/bin/bash

# 固定のDocker Hubユーザー名
DOCKER_USER="axgueba"

# 必要な最低バージョン
MIN_DOCKER_VERSION="1.27.0"

# Docker がインストールされているか確認
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Docker のバージョンを取得
DOCKER_VERSION=$(sudo docker version --format '{{.Server.Version}}')

# バージョンの比較 (新しいバージョンが必要)
if [ "$(printf '%s\n' "$MIN_DOCKER_VERSION" "$DOCKER_VERSION" | sort -V | head -n1)" != "$MIN_DOCKER_VERSION" ]; then
    echo "Error: Docker version must be $MIN_DOCKER_VERSION or later. Current version: $DOCKER_VERSION"
    exit 1
fi

# docker compose コマンドが利用可能か確認
if ! docker compose version &> /dev/null; then
    echo "Error: docker compose is not available. Please install the docker-compose-plugin."
    exit 1
fi

echo "Success: Docker and docker compose are properly installed."

# .envファイルが存在する場合、読み込む
if [ -f .env ]; then
    echo ".env ファイルを読み込みます..."
    set -a
    source .env
    set +a
fi

while true; do
    # 操作者にアクセストークンを入力させる（入力は非表示）
    read -s -p "お客様に払い出されたDocker Hubのアクセストークンを入力してください: " DOCKER_TOKEN
    echo ""

    # Docker Hubにログイン
    echo "${DOCKER_TOKEN}" | sudo docker login --username "${DOCKER_USER}" --password-stdin

    # ログイン成功した場合はループを抜ける
    if [ $? -eq 0 ]; then
        echo "有効なアクセストークンが入力されました"
        break
    else
        echo "無効なアクセストークンが入力されました。正しいアクセストークンを入力してください。"
    fi
done

# データ保持期間の入力
default_value=${DATA_KEEP_DAYS:-90}
while true; do
    read -p "データ保持期間（日数）を入力してください（デフォルト: $default_value）: " DATA_KEEP_DAYS
    DATA_KEEP_DAYS=${DATA_KEEP_DAYS:-$default_value}
    if ! [[ "$DATA_KEEP_DAYS" =~ ^[0-9]+$ ]]; then
        echo "エラー: 数値を入力してください。"
        continue
    fi
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
SMTP_SERVER=${SMTP_SERVER:-}
while true; do
    read -p "SMTP サーバーを入力してください（現在の値: ${SMTP_SERVER:-なし}）: " input
    SMTP_SERVER=${input:-$SMTP_SERVER}
    if [[ -z "$SMTP_SERVER" ]]; then
        echo "エラー: SMTP サーバーは必須です。"
        continue
    fi
    # ドメイン or IP アドレスの基本チェック
    if ! [[ "$SMTP_SERVER" =~ ^[a-zA-Z0-9.-]+$ ]] || [[ "$SMTP_SERVER" =~ (^-|-$|^\.) ]]; then
        echo "エラー: 無効なSMTPサーバー名です（特殊文字や不正なフォーマット）。"
        continue
    fi

    # IPアドレスかホスト名か判定
    if [[ "$SMTP_SERVER" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # IPアドレスの範囲チェック（0.0.0.0 ～ 255.255.255.255）
        IFS='.' read -r -a octets <<< "$SMTP_SERVER"
        valid=true
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                valid=false
                break
            fi
        done
        if ! $valid; then
            echo "エラー: 無効なIPアドレス範囲です。"
            continue
        fi
    else
        # DNS解決チェック（ICMPではなくDNSベースのチェック）
        if ! nslookup "$SMTP_SERVER" > /dev/null 2>&1 && ! dig +short "$SMTP_SERVER" > /dev/null 2>&1; then
            echo "エラー: SMTPサーバー '$SMTP_SERVER' のDNS解決ができません。正しいホスト名またはIPアドレスを入力してください。"
            continue
        fi
    fi

    break
done

# SMTP ポート（587, 465, 25 など）
SMTP_PORT=${SMTP_PORT:-587}
while true; do
    read -p "SMTP ポートを入力してください（デフォルト: $SMTP_PORT）: " input
    SMTP_PORT=${input:-$SMTP_PORT}
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
SMTP_AUTH=${SMTP_AUTH:-on}
while true; do
    read -p "SMTP 認証を使用しますか？ (on/off, 現在の値: $SMTP_AUTH): " input
    SMTP_AUTH=${input:-$SMTP_AUTH}
    if [[ "$SMTP_AUTH" != "on" && "$SMTP_AUTH" != "off" ]]; then
        echo "エラー: on または off を入力してください。"
        continue
    fi
    break
done

# SMTP 認証ユーザー名（認証が "on" の場合のみ入力）
if [[ "$SMTP_AUTH" == "on" ]]; then
    SMTP_AUTH_USER=${SMTP_AUTH_USER:-}
    while true; do
        read -p "SMTP 認証ユーザー名を入力してください（現在の値: ${SMTP_AUTH_USER:-なし}）: " input
        SMTP_AUTH_USER=${input:-$SMTP_AUTH_USER}
        if [[ -z "$SMTP_AUTH_USER" ]]; then
            echo "エラー: SMTP 認証ユーザー名は必須です。"
            continue
        fi
        break
    done

    SMTP_AUTH_PASS=${SMTP_AUTH_PASS:-}
    while true; do
        read -sp "SMTP 認証パスワードを入力してください（現在の値: ${SMTP_AUTH_PASS:+********}）: " input
        echo
        SMTP_AUTH_PASS=${input:-$SMTP_AUTH_PASS}
        if [[ -z "$SMTP_AUTH_PASS" ]]; then
            echo "エラー: SMTP 認証パスワードは必須です。"
            continue
        fi
        break
    done
fi

# 送信先メールアドレス
SMTP_TO=${SMTP_TO:-}
while true; do
    read -p "送信先メールアドレス（Toアドレス）を入力してください（現在の値: ${SMTP_TO:-なし}）: " input
    SMTP_TO=${input:-$SMTP_TO}
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
SMTP_FROM=${SMTP_FROM:-}
while true; do
    read -p "送信元メールアドレス（Fromアドレス）を入力してください（現在の値: ${SMTP_FROM:-なし}）: " input
    SMTP_FROM=${input:-$SMTP_FROM}
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

# Subject の入力
SMTP_SUBJECT=${SMTP_SUBJECT:-"UEBA 結果レポート"}
while true; do
    read -p "結果レポートメールの件名(タイトル)を入力してください（現在の値: ${SMTP_SUBJECT}）: " input
    SMTP_SUBJECT=${input:-$SMTP_SUBJECT}
    break
done

# TLS の有効化
SMTP_TLS=${SMTP_TLS:-"on"}
while true; do
    read -p "SMTP TLS を有効にしますか？ (on/off, 現在の値: ${SMTP_TLS}): " input
    SMTP_TLS=${input:-$SMTP_TLS}
    if [[ "$SMTP_TLS" != "on" && "$SMTP_TLS" != "off" ]]; then
        echo "エラー: on または off を入力してください。"
        continue
    fi
    break
done

# STARTTLS の設定
SMTP_STARTTLS=${SMTP_STARTTLS:-"on"}
while true; do
    read -p "SMTP STARTTLS を有効にしますか？ (on/off, 現在の値: ${SMTP_STARTTLS}): " input
    SMTP_STARTTLS=${input:-$SMTP_STARTTLS}
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
SMTP_AUTH_PASS="${SMTP_AUTH_PASS}"
SMTP_FROM=${SMTP_FROM}
SMTP_TLS=${SMTP_TLS}
SMTP_STARTTLS=${SMTP_STARTTLS}
SMTP_TO=${SMTP_TO}
SMTP_SUBJECT="${SMTP_SUBJECT}"
EOF

echo ".env ファイルに SMTP 設定を保存しました。"


# ueba-eng のインストール
echo "ueba-eng をインストールします..."
if [ ! -f "docker-compose.yml" ]; then
    echo "エラー: docker-compose.yml が見つかりません。スクリプトを終了します。"
    exit 1
fi

sudo docker compose up -d

echo "ueba-eng のインストールが完了しました。"

# MSActivator のインストール確認
read -p "MSActivator をインストールしますか？ (デフォルト: yes) [yes/no]: " INSTALL_MSA
INSTALL_MSA=${INSTALL_MSA:-yes}

if [[ "$INSTALL_MSA" =~ ^(yes|y|Y|Yes|YES)$ ]]; then
    echo "MSActivator をインストールします..."
    sudo sysctl -w vm.max_map_count=262144
    echo 'vm.max_map_count = 262144' | sudo tee /etc/sysctl.d/50-msa.conf
    sudo sysctl -p /etc/sysctl.d/50-msa.conf
    cd ..
    
    git clone https://github.com/ubiqube/quickstart.git
    cd quickstart
    sudo ./scripts/install.sh
    echo "MSActivator のインストールが完了しました。"
else
    echo "MSActivator のインストールをスキップしました。"
fi

echo "すべての処理が完了しました。"

