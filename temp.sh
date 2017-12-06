statusTxpWebInstance(){
   NAME="$1"
   TXPWPID=$(isTxpWebRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoi "txprobe webserver \"${NAME}\" is running with PID ${TXPWPID}"
   else
      echow "txprobe webserver \"${NAME}\" is not running"
   fi
   return 0
}

startTxpWebInstance(){
   NAME="$1"
   TXPWPID=$(isTxpWebRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echow "txprobe webserver \"${NAME}\" is running with PID ${TXPWPID}"
      return 1
   fi
   PIDFILE=$(getPidFile ${NAME} 'txp-web' 'false')
   TXPWHOME=$(getHomeForNode 'txp-web' ${NAME})
   HTTPPORT=$(getConfForNode 'txp-web' ${NAME} ${CONF_PORT_TRANSPORT})
   ARGS=$(getConfForNode 'txp-web' ${NAME} ${CONF_ARGS})
   ARGS=$(resolveArgs ${ARGS})
   TXPWARGS="-Dserver.port=${HTTPPORT} ${ARGS}"
   LOGFILE="${TXPWHOME}/${NAME}.log"
   echoi "starting txprobe web server ${NAME} with arguments \"${TXPWARGS}\""
   nohup ${JAVA8_HOME}/bin/java ${TXPS_MEMARGS} ${TXPWARGS} -cp ${TXPWHOME}/com.ibsplc.icargo.txprobe-aggregator.jar txprobe.tools export-web >${LOGFILE} 2>&1 &
   typeset TXPWPID=${!}
   echoi "txprobe webserver started with PID ${TXPWPID}"
   echo ${TXPWPID} >${PIDFILE}
   return 0
}

stopTxpWebInstance(){
   NAME="$1"
   TXPWPID=$(isTxpWebRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "txprobe webserver \"${NAME}\" is not running, ignoring stop operation"
      return 1
   fi
   echoi "stopping txprobe webserver ${NAME} with PID ${TXPWPID}"
   kill -TERM ${TXPWPID}
   kill -0 ${TXPWPID} >/dev/null 2>&1
   typeset -i ANS=${?}
   typeset -i count=0
   while [[ ${ANS} -eq 0 && ${count} -le 10 ]]; do
      sleep 1
      kill -0 ${TXPWPID} >/dev/null 2>&1
      typeset -i ANS=${?}
      count=$((count + 1))
      echoi "waiting for the process to stop PID : ${TXPWPID}"
   done
   if [[ ${ANS} -eq 0 ]]; then
      echow "graceful shutdown failed, killing the process ..."
      kill -9 ${TXPWPID}
      waitForProcessDeath ${TXPWPID}
   else
      echoi "txprobe webserver stopped sucessfully."
   fi   
}

restartTxpWebInstance(){
   NAME="$1"
   stopTxpWebInstance ${NAME}
   startTxpWebInstance ${NAME}
}


startTxpWeb(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'startTxpWebInstance' ${NAME} 'txp-web'
   return ${?}
}

stopTxpWeb(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'stopTxpWebInstance' ${NAME} 'txp-web'
   return ${?}
}

restartTxpWeb(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'restartTxpWebInstance' ${NAME} 'txp-web'
  return ${?}
}

statusTxpWeb(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'statusTxpWebInstance' ${NAME} 'txp-web'
  return ${?}
}