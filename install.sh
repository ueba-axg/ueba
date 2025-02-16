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

