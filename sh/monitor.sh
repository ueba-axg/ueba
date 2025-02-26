MONITORING_TARGET=/home/ueba/uploads
# ログ出力関数
log_message() {
    echo "`date '+%Y:%m:%d %H:%M:%S'` $0:$@"
}

UEBA_HOME=/opt/uebaeng
UPLOAD_DIR=/home/ueba/uploads
OUTPUT_DIR=/var/www/html/reports
function monitor () {
  inotifywait -e CLOSE_WRITE -m ${MONITORING_TARGET} | while read notice
  do
    if [ "`echo $notice | awk "{print \$2;}" | grep CLOSE_WRITE`" ]
    then
      FN=`echo "${notice}" | awk "{print \\$1\\$3;}"`
      log_message "INFO : File arrived:${FN}"

      # 1. パス部分を削除
      FILE_NO_PATH="${FN#/home/ueba/uploads/}"

      # 2. "ausearch_" を "event-profile-" に置換
      EVENT_PROFILE_FILE="${FILE_NO_PATH/ausearch_/event-profile-}"

      # 3. 拡張子 ".log" を ".xlsx" に変更
      EVENT_PROFILE_FILE="${EVENT_PROFILE_FILE%.log}.xlsx"

      log_message "INFO : AI Engine started. IN:${FN} OUT:{EVENT_PROFILE_FILE}"
      java -classpath "${UEBA_HOME}/*" cps.auditsyscall.AuditSyscall event-profile -u 'h(02|08|14|20)/h6' -n 20 -es 1.5 -en 1.5 -ef 0.0 -c 'M(06|07|09|10)' -s Y2025M01D01 -iu dozo -ff ${UEBA_HOME}/ff2.txt -ic '/etc/cron\..*' -o ${EVENT_PROFILE_FILE} ${FN}
    fi
  done
}
log_message "INFO : Monitoring shell started... target=${MONITORING_TARGET}"
monitor &
