MONITORING_TARGET=/home/ueba/uploads
# ログ出力関数
log_message() {
    echo "`date '+%Y:%m:%d %H:%M:%S'` $0:$@"
}

function monitor () {
  inotifywait -e CLOSE_WRITE -m ${MONITORING_TARGET} | while read notice
  do
    if [ "`echo $notice | awk "{print \$2;}" | grep CLOSE_WRITE`" ]
    then
      FN=`echo "${notice}" | awk "{print \\$1\\$3;}"`
      log_message "INFO : File arrived:${FN}"
      # java -classpath './*' cps.auditsyscall.AuditSyscall event-profile -u 'h(02|08|14|20)/h6' -n 20 -es 1.5 -en 1.5 -ef 0.0 -c 'M(06|07)' -s M12 -iu dozo -ff ff2.txt -ic '/etc/cron\..*' -o event-profile-202412V2.xlsx audit_syscall_raw_*.log
    fi
  done
}
log_message "INFO : Monitoring shell started... target=${MONITORING_TARGET}"
monitor &
