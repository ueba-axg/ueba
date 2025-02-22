#!/bin/bash
source /etc/environment

# 保存期間(日) from Environment variable defined in docker-compose.yml
DAYS_KEEP=${DATA_KEEP_DAYS}

# 監視対象ディレクトリ設定
TARGET_DIR1="/home/ueba/uploads"
TARGET_DIR2="/var/www/html/reports"

# 監視対象拡張子設定
TARGET_EXT1=*.gz
TARGET_EXT2=*.xlsx

# 対象ディレクトリのリスト
TARGET_DIRS=(${TARGET_DIR1} ${TARGET_DIR2})
TARGET_EXTS=(${TARGET_EXT1} ${TARGET_EXT2})

# Log file
exec >> /var/log/ueba/cleanup.log 2>&1
# ログ出力関数
log_message() {
    echo "`date '+%Y:%m:%d %H:%M:%S'` $0:$@"
}

log_message "INFO : Clean up started : ${DAYS_KEEP}"

# 現在の日付から90日以上前のファイルを削除
for dir in "${TARGET_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    for ext in "${TARGET_EXTS[@]}"; do
      find "$dir" -type f -name "$ext" -mtime +${DAYS_KEEP} -exec rm -f {} \;
      log_message "INFO : Cleaned up $ext files in $dir"
    done
  else
    log_message "INFO : Directory $dir not found, skipping..."
  fi
done

