#!/bin/bash
# 保存期間(日)
DAYS_KEEP=90

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
UEBA_CLEANUP_LOG=/var/log/ueba/cleanup.log

echo "`date '+%Y:%m:%d %H:%M:%S'` - Clean up started" >> ${UEBA_CLEANUP_LOG}

# 現在の日付から90日以上前のファイルを削除
for dir in "${TARGET_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    for ext in "${TARGET_EXTS[@]}"; do
      find "$dir" -type f -name "$ext" -mtime +${DAYS_KEEP} -exec rm -f {} \;
      echo "`date '+%Y:%m:%d %H:%M:%S'` - Cleaned up $ext files in $dir" >> ${UEBA_CLEANUP_LOG}
    done
  else
    echo "`date '+%Y:%m:%d %H:%M:%S'` - Directory $dir not found, skipping..." >> ${UEBA_CLEANUP_LOG}
  fi
done

