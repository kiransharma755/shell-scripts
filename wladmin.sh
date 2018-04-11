#!/bin/bash
#set -x

##############################################################
#                                                            #
# WebLogic admin script                                      #
# @Author : Jens J P                                         #
#                                                            #
##############################################################

typeset -r WLADMIN_VERSION='10.0.0.20180124'

CURRDIR=`echo $0 | awk '$0 ~ /^\// { print }'`
if [[ ${CURRDIR} != "" ]]; then
  CURRDIR=`dirname $0`
else
  CURRDIR="`pwd``dirname $0 | cut -c2-`"
fi

export CURRDIR
export DERBY_FLAG='false'

# source the companion scripts
. ${CURRDIR}/libs/setEnv.sh
. ${CURRDIR}/libs/wladmin.functions.sh
. ${CURRDIR}/libs/jvm.functions.sh

# backup the shell variables
typeset -r CPBACKUP="${CLASSPATH}"
typeset -r JOBACKUP="${JAVA_OPTIONS}"
typeset -r WLADMSRPT=$(basename ${0})

println(){
   [[ ${NOPTR} == "true" ]] && return 0;
   if [[ ${ENABLE_COLOR} == 'true' ]]; then
      echo -e "${WHITE_F}------------------------------${1}------------------------------${NC}"
   else
      echo "------------------------------${1}------------------------------"
   fi
}

printUsage(){
 echo "wladmin.version : ${WLADMIN_VERSION}"
 println "-"
 echo "Usage "
 echo ""
 echo "   Lifecycle : ${WLADMSRPT} ( start | stop | restart | kill ) instance/cluster/domain [ flags ]"
 echo "    start   - starts the managed server instance flags [wait, tail, delay]"
 echo "    stop    - stops the managed server instance gracefully flags [force, block, nowait]"
 echo "    restart - restarts the managed server instance gracefully"
 echo "    kill    - kills the managed server java process"
 echo ""
 echo "   Info : ${WLADMSRPT} ( ping | state | health | ps | list) instance/cluster/domain"
 echo "    ping    - pings the instance and displays the status"
 echo "    state   - displays managed server instance state"
 echo "    health  - displays the health status of the instance"
 echo "    ps      - displays the command line arguments of the server and the pid"
 echo "    list    - displays the administered servers options (all, local)"
 echo ""
 echo "   Management : ${WLADMSRPT} ( wlst ) instance/cluster/domain"
 echo "    wlst    - starts the weblogic scripting tool < optionally provide a script to be executed >"
 echo ""
 echo "   House Keeping : ${WLADMSRPT} ( clearlogs | clearjms | cleartmps) instance/cluster/domain"
 echo "    clearlogs - clears the servers logs"
 echo "    clearjms  - clears the JMS persistent store contents"
 echo "    cleartmps - clears the server temp and persistent caches" 
 echo ""
 echo "   Log Management : ${WLADMSRPT} ( tailout | rotate ) instance"
 echo "    tail    - tails the instance log files"
 echo "    rotate  - rotates the log file"
 echo ""
 showJvmCommandUsage
 println "-"
}

# pings the instance and displays the result
pingInstance(){
   INSTANCE="$1"
   URL=$(getInstanceUrl ${INSTANCE} 'http')
   curl -m 3 -s -XHEAD "${URL}"
   PING_RESULT=$?
   if [[ ${PING_RESULT} -eq 18 || ${PING_RESULT} -eq 28 ]]; then
     echoi "${PING_RESULT} : WebLogic Instance ${INSTANCE} is OK"
     return 0;
   else
     echoe "${PING_RESULT} : WebLogic Instance ${INSTANCE}! FAILED"
     return 1;
   fi
}

# pings the instance and displays the result
stateInstance(){
   INSTANCE="$1"
   ADMURL=$(getAdminServerUrlForInstance ${INSTANCE})
   USRARG=$(getUserKeyArgsForInstance ${INSTANCE})
   # optionally set the admin server options while pinging
   ADM_SERVER=$(getAdminServerForInstance ${INSTANCE})
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   PYPROXY="/tmp/.stateInstance_${INSTANCE}.py"
   PYOUT="/tmp/.stateInstance_${INSTANCE}.out"
   cat << EOF >> ${PYPROXY}
# generated python script by ${WLADMSRPT}.
try:
   connect(userConfigFile='${DOMDIR}/.user.cfg', userKeyFile='${DOMDIR}/.user.key', url='${ADMURL}')
   state('${INSTANCE}','Server')
except Error:
   exit('1')
exit('0')
EOF
   invokeWlst ${PYPROXY} >${PYOUT} 2>&1
   typeset -i ANS=$?
   rm ${PYPROXY}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Unable to get the state of the server"
      return 1
   else
      grep ${INSTANCE} ${PYOUT}
      rm ${PYOUT}
      return 0
   fi
}

pingUrl(){
  INSTANCE="$1"
  URL=$(getInstanceUrl ${INSTANCE} "http")
  #DOM_SHORT_NAME=$(getDomainShortNameForInstance ${INSTANCE})
  #ICO_CP="icargo"
  #if [[ ! -z ${DOM_SHORT_NAME} && "${DOM_SHORT_NAME}" != "-" ]]; then
  #      ICO_CP="icargo${DOM_SHORT_NAME}"
  #fi
  ICO_CP=$(getDomainContextNameForInstance ${INSTANCE})
  URL="${URL}/${ICO_CP}/sso/auth/"
  wget --tries=2 -o ${CURRDIR}/tmp/ping-${INSTANCE}.log --spider "${URL}"
  if [[ $? -ne 0 ]]; then
  echo "Url ping on ${INSTANCE} : FAILED" >&2
  else
  echo "Url ping on ${INSTANCE} : SUCCESS" >&2
  fi
  return 0
}

# finds the instance health
displayInstanceHealth(){
   INSTANCE="$1"
   ADMURL=$(getAdminServerUrlForInstance ${INSTANCE})
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   PYPROXY="/tmp/.health_${INSTANCE}.py"
   PYOUT="/tmp/.health_${INSTANCE}.out"
   
   ADM_SERVER=$(getAdminServerForInstance ${INSTANCE})
   ENVFILE="${DOMDIR}/${ENV_FILE_NAME}"
   if [[ ! -x ${ENVFILE} ]]; then
      echoe "Environment file not present or can not be executed : ${ENVFILE}"
      return 1
   fi
   # source the environment file
   . ${ENVFILE} ${ADM_SERVER} min
   export CONFIG_JVM_ARGS="${JAVA_OPTIONS}"
   
   echo "" > ${PYPROXY}
cat << EOF >> ${PYPROXY}
# generated python script by ${WLADMSRPT}.
try:
   connect(userConfigFile='${DOMDIR}/.user.cfg', userKeyFile='${DOMDIR}/.user.key', url='${ADMURL}')
   cd('domainRuntime:/ServerRuntimes/${INSTANCE}')
   healthState=get('OverallHealthState')
   print '${INSTANCE} health : ', healthState.mapToString(healthState.getState())
   reasonCodes=healthState.getReasonCode()
   if len(reasonCodes) > 0:
      for reasonCode in reasonCodes:
         print '${INSTANCE} reasonCode : ' ,reasonCode
   
except Error:
   exit('1')
exit('0')   
EOF
   ${WLADM_WL_HOME}/common/bin/wlst.sh -skipWLSModuleScanning ${PYPROXY} >${PYOUT} 2>&1
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Error while retrieving ${INSTANCE} health.The server may be down or not responding."
      return 1
   fi
   grep "^${INSTANCE}" ${PYOUT}
   return 0
}

# returns the server process Id 
findInstancePid(){
   SERVER=${1}
   #PID=`${JAVA_HOME}/bin/jps -lv | grep java | grep "[w]eblogic.Name=${SERVER}" | awk '{ print $1 }'`
   OS=$(uname -s)
   if [[ ${OS} == 'SunOS' ]]; then
      PID=`${WLADM_PS} | grep "[w]eblogic.Name=${SERVER}" | nawk '{ print $2 }'`
   else
      PID=`${WLADM_PS} | grep "[w]eblogic.Name=${SERVER}" | awk '{ print $2 }'`
   fi
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || -z ${PID} ]]; then
      echoe "Unable to resolve the process id of the weblogic server ${SERVER}" >&2
      return 1
   fi
   echo ${PID}
   return 0
}

# prints the ps line of the process
displayInstancePs(){
   SERVER="$1"
   ${WLADM_PS} | grep "[w]eblogic.Name=${SERVER}"
   return $?
}

# rotates the logs files of the instance
rotateInstanceLogs(){
   local INSTANCE="$1"
   local REFERER="$2"
   isValidInstance ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , invalidInstance : ${INSTANCE}" >&2
      return 1
   fi
   isInThisBox ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , instance not in this box : ${INSTANCE}" >&2
      return 1
   fi
   local DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   local TMS=$(date '+%Y%m%d_%H%M%S')
   local LOGROOT=$(getLogDir ${DOMDIR} ${INSTANCE})
   local LOGFILE="${LOGROOT}/wls/${INSTANCE}.out"
   if [[ -e ${LOGFILE} ]]; then
      if [[ ${ENABLE_PIPED_LOG} == 'true' ]]; then
         # stop the writer
         stopLogPipeWriter ${LOGFILE}
         cp ${LOGFILE} ${LOGFILE}.${TMS}
         #PIPEFIL=$(resolveLogDelegate ${LOGFILE} 'true' )
         resolveLogDelegate ${LOGFILE} 'true' >/dev/null
         typeset -i ANS=${?}
         if [[ ${ANS} -ne 0 ]]; then
            echoe "Unable to start pipe writer for instance : ${INSTANCE} , logFile : ${LOGFILE}"
            return 1
         else
            echoi "Log file rotated sucessfully for instance ${INSTANCE}"
         fi
      else
         cp ${LOGFILE} ${LOGFILE}.${TMS} && > ${LOGFILE}
         echoi "Log file rotated sucessfully for instance ${INSTANCE}"
         return 0
      fi
   else
      echow "Log file does not exist for instance ${INSTANCE}"
      if [[ ${REFERER} == 'start' && ${ENABLE_PIPED_LOG} == 'true' ]]; then
         stopLogPipeWriter ${LOGFILE}
         resolveLogDelegate ${LOGFILE} 'true' >/dev/null
         typeset -i ANS=${?}
         if [[ ${ANS} -ne 0 ]]; then
            echoe "Unable to start pipe writer for instance : ${INSTANCE} , logFile : ${LOGFILE}"
            return 1
         fi
      fi 
   fi
   return 0
}

# tails the instance out log file
tailInstanceOutLog(){
   local INSTANCE="$1"
   isValidInstance ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , invalidInstance : ${INSTANCE}" >&2
      return 1
   fi
   isInThisBox ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , instance not in this box : ${INSTANCE}" >&2
      return 1
   fi
   local DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   local LOGROOT=$(getLogDir ${DOMDIR} ${INSTANCE})
   local LOGFILES=$( find ${LOGROOT}/ -type f \( -name "${INSTANCE}*log" -o -name "${INSTANCE}.out" \) -not \( -name "${INSTANCE}*access*" -o -name "${INSTANCE}*GC*" \) -print | awk '{ CP[FNR]=$1 } END { for (i = 1 ;i < FNR ; i++) { CPP=CP[i]" "CPP } ; print CPP CP[i]}' )
   echo ${LOGFILES} 
   tail -f ${LOGFILES}
   return 0
}

# function to clear jms store for the server
clearInstanceJmsStore(){
   INSTANCE="$1"
   PID=$(findInstancePid ${INSTANCE} 2>/dev/null )
   if [[ -n ${PID} ]]; then
      echoe "Instance : ${INSTANCE} is already running PID : ${PID}, ignoring JMS clear operation" >&2
      return 1
   fi
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Error getting domain directory for instance : ${INSTANCE}" >&2
      return 1
   fi
   JMSSTOREDIR="${DOMDIR}/user_stage/store/${INSTANCE}/jms"
   if [[ ! -r ${JMSSTOREDIR} ]]; then
      echow "JMS store folder does not exists : ${JMSSTOREDIR}"
      mkdir -p ${JMSSTOREDIR}
      if [[ $? -eq 0 ]]; then
         echoi "Created JMS store directory : ${JMSSTOREDIR}"
         return 0
      else
         echoe "Unable to create JMS store directory : ${JMSSTOREDIR} "
         retun 1
   fi
   fi
   find ${JMSSTOREDIR}/ -name '*.DAT' -type f -exec rm -f {} \;
   #find ${JMSSTOREDIR}/ -name "*.DAT" -type f -exec ls -l {} \;
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      echoi "JMS store cleared successfully for instance : ${INSTANCE}"
   else
      echoe "Error occurred while clearing JMS store files for instance : ${INSTANCE}"
   fi
   return ${ANS}
}

# function to clear the log files of the server
clearInstanceLogs(){
   INSTANCE="$1"
   PID=$(findInstancePid ${INSTANCE} 2>/dev/null )
   if [[ -n ${PID} ]]; then
      echoe "Instance : ${INSTANCE} is already running PID : ${PID}, ignoring log clear operation" >&2
      return 1
   fi
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Error getting domain directory for instance : ${INSTANCE}" >&2
      return 1
   fi
   LOGDIR=$(getLogDir ${DOMDIR} ${INSTANCE})
   if [[ ! -d ${LOGDIR} ]]; then
      echoe "Log store folder does not exists : ${LOGDIR}"
      return 1
   fi
   #find ${LOGDIR}/ -name "*.DAT" -type f -exec rm -f {} \;
   find ${LOGDIR}/ -name "*${INSTANCE}*.out*" -type f -exec rm -f {} \;
   find ${LOGDIR}/ -name "*${INSTANCE}*.log*" -type f -exec rm -f {} \;
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      echoi "Log files cleared successfully for instance : ${INSTANCE}"
   else
      echoe "Error occurred while clearing Log files for instance : ${INSTANCE}"
   fi
   return ${ANS}
}

# function to clear the temp files of the server
clearInstanceWlsTmps(){
   local INSTANCE="$1"
   local PID=$(findInstancePid ${INSTANCE} 2>/dev/null )
   if [[ -n ${PID} ]]; then
      echoe "Instance : ${INSTANCE} is already running PID : ${PID}, ignoring log clear operation" >&2
      return 1
   fi
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Error getting domain directory for instance : ${INSTANCE}" >&2
      return 1
   fi
   local WLSINSWRK="${DOMDIR}/servers/${INSTANCE}"
   find ${WLSINSWRK}/tmp ${WLSINSWRK}/cache -type f -exec rm -f {} \;
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      echoi "Temp files and caches cleared successfully for instance : ${INSTANCE}"
   else
      echoe "Error occurred while clearing Temp files for instance : ${INSTANCE}"
   fi
   return ${ANS}
}

resolveLogDelegate(){
   LOGFILE="$1"
   STRTWRITER="$2"
   [[ -z ${STRTWRITER} ]] && STRTWRITER='false'
   if [[ -z ${ENABLE_PIPED_LOG} || ${ENABLE_PIPED_LOG} != 'true' ]];then
       echo ${LOGFILE}
       return 0
   else
       PIPEDIR="${CURRDIR}/.pipes"
       LOGFILEBS=$(basename ${LOGFILE})
       PIPENAME="${PIPEDIR}/${LOGFILEBS}"
       if [[ ! -d ${PIPEDIR} ]]; then
          mkdir ${PIPEDIR}
          typeset -i ANS=${?}
          if [[ ${ANS} -ne 0 ]]; then
             echoe "Unable to create directory : ${PIPEDIR}" >&2
             return 1
          fi
       fi
       if [[ ! -p ${PIPENAME} ]]; then
          #mknod ${PIPENAME} p
          mkfifo ${PIPENAME}
          chmod a+rw ${PIPENAME}
          typeset -i ANS=${?}
          if [[ ${ANS} -ne 0 ]]; then
             echoe "Unable to create named pipe : ${PIPENAME}" >&2
             return 1
          fi
       fi
       if [[ ${STRTWRITER} == 'true' ]]; then
          # setup the reader for the pipe
          cat < ${PIPENAME} > ${LOGFILE} &
          typeset -i WRTRPID=${!}
          kill -0 ${WRTRPID}
          typeset -i ANS=${?}
          if [[ ${ANS} -ne 0 || ! -n ${WRTRPID} ]]; then
             echoe "Unable to create reader for the pipe : ${PIPENAME}" >&2
             return 1
          else
             echo ${WRTRPID} >${PIPEDIR}/${LOGFILEBS}.pid
          fi
       fi
       echo ${PIPENAME}
       return 0
   fi
}

stopLogPipeWriter(){
   LOGFILE="$1"
   PIPEDIR="${CURRDIR}/.pipes"
   LOGFILEBS=$(basename ${LOGFILE})
   WTRPIDFILE="${PIPEDIR}/${LOGFILEBS}.pid"
   if [[ -e ${WTRPIDFILE} ]]; then
      typeset -i WTRPID=$(cat ${WTRPIDFILE})
      if [[ -n ${WTRPID} ]]; then
         kill -9 ${WTRPID} >/dev/null 2>&1
         typeset -i ANS=${?}
         if [[ ${ANS} -eq 0 ]]; then
            echoi "Pipe writer process stopped successfully."
            rm ${WTRPIDFILE}
            return 0
         else
            return 1
         fi
      fi
   fi
   return 0
}

# starts the instance if its not running
startInstance(){
   local INSTANCE="$1"
   local FLAG="$2"
   local PID=$(findInstancePid ${INSTANCE} 2>/dev/null )
   if [[ -n ${PID} ]]; then
      echoe "Instance : ${INSTANCE} is already running PID : ${PID}, ignoring start operation" >&2
      return 1
   fi
   rotateInstanceLogs ${INSTANCE} 'start'
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Error getting domain directory for instance : ${INSTANCE}" >&2
      return 1
   fi
   ENVFILE="${DOMDIR}/${ENV_FILE_NAME}"
   if [[ ! -x ${ENVFILE} ]]; then
      echoe "Environment file not present or can not be executed : ${ENVFILE}" >&2
      return 1
   fi
   # source the environment file
   . ${ENVFILE} ${INSTANCE}
   local ISADM=$(isAdminServer ${INSTANCE})
   local LOGOUTDIR="${DOMDIR}/user_stage/logs/wls"
   if [[ ! -d ${LOGOUTDIR} ]]; then
      mkdir -p ${LOGOUTDIR}
      echoi "Created wls log directory ${LOGOUTDIR}"
   fi
   local LOGOUTFILE="${LOGOUTDIR}/${INSTANCE}.out"
   LOGOUT=$(resolveLogDelegate ${LOGOUTFILE} 'false')
   typeset -i ANS=${?}
   [[ ${ANS} -ne 0 ]] && LOGOUT="${LOGOUTFILE}"
   if [[ ${ISADM} == "yes" ]]; then
      echoi "Starting Admin server : ${INSTANCE}"
      nohup ${DOMDIR}/bin/startWebLogic.sh > ${LOGOUT} 2>&1 &
      local PID=${!}
   else
      ADMURL=$(getAdminServerUrlForInstance ${INSTANCE})
      typeset -i ANS=$?
      if [[ ${ANS} -ne 0 ]]; then
         echoe "Unable to retrieve Admin server url for instance ${INSTANCE}" >&2
         return 1
      fi
      echoi "Starting Managed server : ${INSTANCE}"
      nohup ${DOMDIR}/bin/startManagedWebLogic.sh ${INSTANCE} ${ADMURL} > ${LOGOUT} 2>&1 &
      local PID=${!}
   fi
   echoi "Start process initiated processId : ${PID}"
   echoi "Log file written to : ${LOGOUTFILE}"
   # If required to wait
   if [[ ${FLAG} == "wait" ]]; then
      typeset -i counter=0
      typeset -i NOT_STARTED=1
      while [[ ${NOT_STARTED} -ne 0 && ${counter} -le ${RESTART_START_LOOPTIMES} ]]; do
         echoi "${counter}. Waiting for Instance to Start... ${INSTANCE}"
         sleep ${RESTART_START_WAIT}
         pingInstance ${INSTANCE}
         NOT_STARTED=$?
         counter=$((counter + 1))
      done
      if [[ ${NOT_STARTED} -eq 0 ]]; then
         echoi "Server ${INSTANCE} started sucessfully."
      else
         echow "Server ${INSTANCE} may still be coming up."
      fi
   fi
   # If required to tail
   if [[ ${FLAG} == "tail" ]]; then
      tailInstanceOutLog ${INSTANCE}
   fi
   if [[ ${FLAG} == "delay" ]]; then
      echoi "Waiting for ${STARTUP_DELAY} seconds ..."
      sleep ${STARTUP_DELAY}
   fi
   return 0
}

# stops the weblogic instance
stopInstance(){
   INSTANCE="$1"
   FLAG="$2"
   PID=$(findInstancePid ${INSTANCE} 2>/dev/null )
   if [[ -z ${PID} ]]; then
      echoe "Instance : ${INSTANCE} is shutdown, ignoring stop operation" >&2
      return 0
   fi   
   USRARG=$(getUserKeyArgsForInstance ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Unable to retrieve user key config for instance ${INSTANCE}" >&2
      return 1
   fi
   
   ISADM=$(isAdminServer ${INSTANCE})
   if [[ ${ISADM} == "yes" ]]; then
      ADM_SERVER="${INSTANCE}"   
   else
      ADM_SERVER=$(getAdminServerForInstance ${INSTANCE})   
   fi
   
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   ENVFILE="${DOMDIR}/${ENV_FILE_NAME}"
   echoi "Stopping instance : ${INSTANCE}"
   . ${ENVFILE} ${ADM_SERVER} min
   ADMURL=$(getInstanceUrl ${ADM_SERVER})
   echoi "Admin Server URL : ${ADMURL}"
   PYPROXY="/tmp/.stopInstance_${INSTANCE}.py"
   if [[ ${FLAG} = 'nowait' ]]; then
      WLS_SHUTDOWN_TIMEOUT=5
      BLOCK='false'
      [[ ${WLS_SHUTDOWN_CMD} == 'FORCESHUTDOWN' ]] && FORCE='true' || FORCE='false'; 
   elif [[ ${FLAG} == 'block' ]]; then
      BLOCK='true'
      [[ ${WLS_SHUTDOWN_CMD} == 'FORCESHUTDOWN' ]] && FORCE='true' || FORCE='false'; 
   elif [[ ${FLAG} == 'force' || ${WLS_SHUTDOWN_CMD} == 'FORCESHUTDOWN' ]]; then
      BLOCK='true'
      FORCE='true'
   fi
   cat << EOF >> ${PYPROXY}
# generated python script by ${WLADMSRPT}.
try:
   connect(userConfigFile='${DOMDIR}/.user.cfg', userKeyFile='${DOMDIR}/.user.key', url='${ADMURL}')
   shutdown('${INSTANCE}', 'Server', ignoreSessions='true', timeOut=${WLS_SHUTDOWN_TIMEOUT}, force='${FORCE}', block='${BLOCK}')
except Error:
   exit('1')
exit('0')   
EOF
   invokeWlst ${PYPROXY} >/dev/null 2>&1
   typeset -i ANS=$?
   kill -0 ${PID} >/dev/null 2>&1
   typeset -i ISRUNNING=${?}
   # Delete the py file if executed sync
   [[ ${INVOKE_MODE} == 'sync' ]] && rm ${PYPROXY} 
   if [[ ${ISRUNNING} -eq 0 ]]; then
      ANS=1
   fi
   if [[ ${ANS} -ne 0 && ${FLAG} == "force" ]]; then
      echow "Stop operation failed , killing server."
      kill -0 ${PID} && killInstance ${INSTANCE}
      return 0
   elif [[ ${ANS} -ne 0 ]]; then
      echoe "Stop operation failed, server would be still running."
      return 1
   elif [[ ${ANS} -eq 0 ]]; then
      echoi "Server has been shutdown successfully."
      return 0
   fi
   return $ANS
}

# restarts the weblogic instance
restartInstance(){
   local INSTANCE="$1"
   echoi "Restarting instance : ${INSTANCE}"
   stopInstance ${INSTANCE} 'force'
   startInstance ${INSTANCE} 'wait'
   return $?
}

# kills the java instance
killInstance(){
   INSTANCE="$1"
   local WLSPID=$(findInstancePid ${INSTANCE} 2>/dev/null )
   if [[ -z ${WLSPID} ]]; then
      echoe "Instance ${INSTANCE} is not running" >&2
      return 1
   fi
   echoi "Gracefully terminating instance ${INSTANCE} PID : ${WLSPID}"
   kill -TERM ${WLSPID}
   kill -0 ${WLSPID} >/dev/null 2>&1
   typeset -i ANS=${?}
   typeset -i count=0
   while [[ ${ANS} -eq 0 && ${count} -le ${RESTART_STOP_LOOPTIMES} ]]; do
      sleep ${RESTART_STOP_WAIT}
      kill -0 ${WLSPID} >/dev/null 2>&1
      typeset -i ANS=${?}
      count=$((count + 1))
      echoi "Waiting for ${INSTANCE} to stop PID : ${WLSPID}"
   done
   if [[ ${ANS} -eq 0 ]]; then
      echow "Graceful shutdown failed, killing the process ..."
      kill -9 ${WLSPID}
      typeset -i ANS=$?
      if [[ ${ANS} -eq 0 ]]; then
         echoi "Instance ${INSTANCE} killed sucessfully."
         return 0
      else
         echoe "Unable to kill instance ${INSTANCE}" >&2
         return 1
      fi
   else
      echoi "WebLogic server ${INSTANCE} stopped sucessfully."
      return 0
   fi
}

# creates the userconfig and user key files
createUserKeyFilesForInstance(){
   INSTANCE="${1}"
   isValidInstance ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , invalidInstance : ${INSTANCE}" >&2
      return 1
   fi
   isInThisBox ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , instance not in this box : ${INSTANCE}" >&2
      return 1
   fi
   # check if already present
   ARGS=$(getUserKeyArgsForInstance ${INSTANCE} >/dev/null 2>&1 )
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      echoe "User config and key files exists for this domain, delete them before running this command : ${ARGS}"
      return 1;
   fi
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   echo -n "Enter the weblogic user for domain (${DOMDIR}) : "
   read WLS_USER
   echo -n "Enter the weblogic password for domain (${DOMDIR}) : "
   read WLS_PASSWD
   ADMURL=$(getAdminServerUrlForInstance ${INSTANCE})
   USER_CFG="${DOMDIR}/.user.cfg"
   KEY_CFG="${DOMDIR}/.user.key"
   PYPROXY="/tmp/.userKey_${INSTANCE}.py"
   echo "" > ${PYPROXY}
cat << EOF >> ${PYPROXY}
# generated python script by ${WLADMSRPT}.
try:
   connect('${WLS_USER}','${WLS_PASSWD}','${ADMURL}');
   storeUserConfig('${USER_CFG}','${KEY_CFG}');
except Error:
   exit('1')
exit('0')   
EOF
   invokeWlst ${PYPROXY}
   typeset -i ANS=$?
   rm ${PYPROXY}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Error while generating user config and key files !"
      return 1
   fi
   echoi "User config and key files generated sucessfully "
   return 0
}

# creates the boot.properties entry for the server
createBootPropsForInstance(){
   INSTANCE="${1}"
   isValidInstance ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , invalidInstance : ${INSTANCE}" >&2
      return 1
   fi
   isInThisBox ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , instance not in this box : ${INSTANCE}" >&2
      return 1
   fi
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   BOOTPROP="${DOMDIR}/servers/${INSTANCE}/security"
   if [[ ! -e ${BOOTPROP} ]]; then
      mkdir -p ${BOOTPROP}
      typeset -i ANS=$?
      if [[ ${ANS} -ne 0 ]]; then
         echoe "Unable to create folder : ${BOOTPROP}" >&2
         return 1
      fi
   fi
   BOOTPROP="${DOMDIR}/servers/${INSTANCE}/security/boot.properties"
   if [[ -r ${BOOTPROP} ]]; then
      echoe "boot file already exists ${BOOTPROP}, delete this and continue." >&2
      return 1
   fi
   echo -n "Enter the weblogic user for domain (${DOMDIR}) : "
   read WLS_USER
   echo -n "Enter the weblogic password for domain (${DOMDIR}) : "
   read WLS_PASSWD
   echo "username=${WLS_USER}" >${BOOTPROP}
   echo "password=${WLS_PASSWD}" >>${BOOTPROP}
   echo "" >>${BOOTPROP}
   echoi "Boot file sucessfully written for instance ${INSTANCE} , file : ${BOOTPROP}"
   return 0
}

# function to dispatch commands remotely over ssh
# 1 : command
# 2 : instance name
# 3 : flags (optional)
# return : 0 if success, 50 if local , 60 if remote dispatch not enabled, 1 execution errors
dispatchCommandRemote(){
   COMMAND="$1"
   INSTANCE="$2"
   FLAGS="$3"
   isInThisBox ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      isRemoteDispatchEnabled ${INSTANCE}
      typeset -i ANS=$?
      if [[ ${ANS} -eq 0 ]]; then
         SRVHOST=$(getInstanceHost ${INSTANCE})
	 SRVOSUSER=$(getInstanceOSUser ${INSTANCE})
	 echoi "Dispatching command to server : ${SRVOSUSER}@${SRVHOST}"
	 REMCMD="${WLADMSRPT} ${COMMAND} ${INSTANCE} ${FLAGS}"
	 #ssh "${SRVOSUSER}@${SRVHOST}" "\"${REMCMD}\""
         ssh "${SRVOSUSER}@${SRVHOST}" bash -c "'${REMCMD}'"
	 typeset -i ANS=${?}
	 if [[ ${ANS} -ne 0 ]]; then
	    echoe "Error occurred while dispatching remote command errorCode : ${ANS} command : ${REMCMD}"
	 fi
         return 1
      else
         return 60
      fi
   else
      return 50
   fi
}

# dispatches the command for the instance, cluster or domain
doDispatchCommand(){
   INSCMD="$1"
   NAME="$2"
   FLAG="$3"
   [[ -z ${LOCAL_INS} ]] && LOCAL_INS="true"
   #echo "doDispatchCommand -> INSCMD : ${INSCMD}, NAME : ${NAME}, FLAG : ${FLAG}"
   # check if the name is an instance
   isValidInstance ${NAME}
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      if [[ ${LOCAL_INS} == "true" ]]; then
         dispatchCommandRemote ${WLADM_ACTION} ${NAME} ${WLADM_FLAG}
         typeset -i ANS=$?
         if [[ ${ANS} -eq 60 ]]; then
            echow "Instance : ${NAME} is not in this box and remote dispatch is disabled."
            return 1
         elif [[ ${ANS} -eq 50 ]]; then
            println " instance ${NAME} "
	    eval "${INSCMD} ${NAME} ${FLAG}"
            return 0
         else
            return ${ANS}
         fi
      else
         println " instance ${NAME} "
	 eval "${INSCMD} ${NAME} ${FLAG}"
         return 0
      fi
   fi
   # check if its a domain
   isValidDomain ${NAME}
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      INSTS=$(findAllInstancesForDomain ${NAME} "false" ${ADMORD})
      if [[ -n ${INSTS} ]]; then
         for INST in ${INSTS} ; do
            if [[ ${LOCAL_INS} == "true" ]]; then
	       dispatchCommandRemote ${WLADM_ACTION} ${INST} ${WLADM_FLAG}
	       typeset -i ANS=$?
	       if [[ ${ANS} -eq 60 ]]; then
	          echow "Instance : ${INST} is not in this box and remote dispatch is disabled."
	          #return 1
	       elif [[ ${ANS} -eq 50 ]]; then
	          println " instance ${INST} "
		  CLASSPATH="${CPBACKUP}"
		  JAVA_OPTIONS="${JOBACKUP}"
	          eval "${INSCMD} ${INST} ${FLAG}"
	       fi
	    else
	       println " instance ${INST} "
	       CLASSPATH="${CPBACKUP}"
	       JAVA_OPTIONS="${JOBACKUP}"
	       eval "${INSCMD} ${INST} ${FLAG}"
            fi
         done
         return 0
      else
         echoe "No instances for the domain ${NAME} in this box" >&2
         return 1
      fi
   fi
   # check if its a cluster
   isValidCluster ${NAME}
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      INSTS=$(findAllInstancesForCluster ${NAME} "false" ${ADMORD})
      if [[ -n ${INSTS} ]]; then
         for INST in ${INSTS} ; do
            if [[ ${LOCAL_INS} == "true" ]]; then
	       dispatchCommandRemote ${WLADM_ACTION} ${INST} ${WLADM_FLAG}
	       typeset -i ANS=$?
	    if [[ ${ANS} -eq 60 ]]; then
	          echow "Instance : ${INST} is not in this box and remote dispatch is disabled."
	          #return 1
       elif [[ ${ANS} -eq 50 ]]; then
	          println " instance ${INST} "
	          CLASSPATH="${CPBACKUP}"
	          JAVA_OPTIONS="${JOBACKUP}"
	          eval "${INSCMD} ${INST} ${FLAG}"
				 fi
       else
	       println " instance ${INST} "
	       CLASSPATH="${CPBACKUP}"
	       JAVA_OPTIONS="${JOBACKUP}"
	       eval "${INSCMD} ${INST} ${FLAG}"
       fi
         done
         return 0
      else
         echoe "No instances for the cluster ${NAME} in this box" >&2
         return 1
      fi
   fi
   echoe "${NAME} is neither a valid instance,cluster or domain name" >&2
   return 1
}

# displays the ps line for the instance, cluster or domain
doDisplayPs(){
   NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   doDispatchCommand "displayInstancePs" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

# pings the servers
doPing(){
   NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   LOCAL_INS="false" # all instances
   doDispatchCommand "pingInstance" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

# rotates the logs
doRotateLogs(){
   NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   doDispatchCommand "rotateInstanceLogs" ${NAME} 'rotate'
   typeset -i ANS=$?
   return $ANS
}

# starts the server
doStartServers(){
   NAME="$1"
   FLAG="$2"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   ADMORD="F" # first start the admin server
   doDispatchCommand "startInstance" ${NAME} ${FLAG}
   typeset -i ANS=$?
   return $ANS   
}

# stops the servers
doStopServers(){
   NAME="$1"
   FLAG="$2"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   ADMORD="L" # stop the admin server last
   doDispatchCommand "stopInstance" ${NAME} ${FLAG}
   typeset -i ANS=$?
   return $ANS
}

# restarts the servers
doRestartServers(){
   NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   ADMORD="F" # bounce the admin first
   doDispatchCommand "restartInstance" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

# kills the instance, cluster or domain
doKill(){
   NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   ADMORD="L" # stop the admin server last
   doDispatchCommand "killInstance" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

# displays the health of the instance, cluster or domain
doDisplayHealth(){
   NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   LOCAL_INS="false" # all instances
   doDispatchCommand "displayInstanceHealth" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

# display the state of the servers
doDisplayState(){
   NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   LOCAL_INS="false" # all instances
   doDispatchCommand "stateInstance" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

doTailOutLog(){
   INSTANCE="$1"
   isValidInstance ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , invalidInstance : ${INSTANCE}" >&2
      return 1
   fi
   LOCAL_INS="true" # only local instances
   doDispatchCommand "tailInstanceOutLog" ${INSTANCE}
   typeset -i ANS=$?
   return $ANS
}

listInstance(){
   INSTANCE="$1"
   FLAGS="$2"
   if [[ ${FLAGS} == "local" ]]; then
      isInThisBox ${INSTANCE}
      typeset -i ANS=${?}
      if [[ ${ANS} -ne 0 ]]; then
         return 0
      fi
   fi
   #domain cluster instance host port ctxpath domaindir
   DOMAIN=$(getInstanceDomain ${INSTANCE})
   CLUSTER=$(getInstanceCluster ${INSTANCE})
   HOST=$(getInstanceHost ${INSTANCE})
   PORT=$(getInstancePort ${INSTANCE})
   CTXPATH=$(getDomainContextPath ${DOMAIN})
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   echo "${DOMAIN} ${CLUSTER} ${INSTANCE} ${HOST} ${PORT} ${CTXPATH} ${DOMDIR}"
   return 0
}

doList(){
   local NAME="$1"
   local FLAGS="$2"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid list option all, local, instance, cluster or domain name" >&2
      return 1
   fi
   [[ -z ${FLAGS} ]] && FLAGS="$NAME"
   println "${NAME} servers"
   NOPTR="true"
   if [[ ${NAME} == "all" || ${NAME} == "local" ]]; then
      ISLOCAL="true"
      [[ ${NAME} == "all" ]] && ISLOCAL="false"
      ALLDOMAINS=$(getAllDomains ${ISLOCAL})
      for DOM in ${ALLDOMAINS} ; do
         LOCAL_INS="false"
         doDispatchCommand "listInstance" ${DOM} ${FLAGS}
      done
   else
      doDispatchCommand "listInstance" ${NAME} ${FLAGS}
   fi
   NOPTR="false"
   println "-"
   return 0
}

doClearJmsStore(){
   local NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   LOCAL_INS="true" # only local instances
   doDispatchCommand "clearInstanceJmsStore" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

doClearLogs(){
   local NAME="$1"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   LOCAL_INS="true" # only local instances
   doDispatchCommand "clearInstanceLogs" ${NAME}
   typeset -i ANS=$?
   return $ANS
}

doClearWlsTmps(){
   local NAME="$1"
   if [[ -z ${NAME} ]]; then
      echoe "Enter a valid instance, cluster or domain name" >&2
      return 1
   fi
   LOCAL_INS='true'
   doDispatchCommand "clearInstanceWlsTmps" ${NAME}
   typeset -i ANS=${?}
   return ${ANS}
}

invokeWlst(){
   local PYFILE="$1"
   local WLST_SCRIPT="${WLADM_WL_HOME}/common/bin/wlst.sh"
   if [[ ! -x ${WLST_SCRIPT} ]]; then
      echoe "wlst.sh file does not exists or is not executable : ${WLST_SCRIPT}"
   fi
   if [[ ! -z ${PYFILE} && ! -r ${PYFILE} ]]; then
      echoe "wlst script does not exists : ${PYFILE}"
      return 1
   fi
   WLST_EXT_CLASSPATH=$(find ${CURRDIR}/store/ -type f -name 'i*.jar' -print | awk '{ CP[FNR]=$1 } END { for (i = 1 ; i < FNR ; i++) { CPP=CP[i]":"CPP } ; print CPP CP[i]}')
   export WLST_EXT_CLASSPATH
   ${WLST_SCRIPT} -skipWLSModuleScanning ${PYFILE}
   return ${?}
   
}

typeset -r JVMCMD_SEP='@'

# dispatch to jvm library functions
executeInstanceJvmCommand(){
   INSTANCE="$1"
   JCMDENC="$2"
   JCMD=$( echo ${JCMDENC} | awk 'BEGIN { FS='\"${JVMCMD_SEP}\"' } { print $1 }')
   JCMD_FLAG=$( echo ${JCMDENC} | awk 'BEGIN { FS='\"${JVMCMD_SEP}\"' } { print $2 }')
   # check if valid instance
   isValidInstance ${INSTANCE}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Provide a valid instance running in this box , invalidInstance : ${INSTANCE}"
      return 1
   fi
   # check if in this box
   isInThisBox ${INSTANCE}
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Instance is not present in this box."
      return 1
   fi   
   INSTPID=$(findInstancePid ${INSTANCE} 2>/dev/null )
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Instance is not running. ${JCMD} operation skipped."
      return 1
   fi
   
   DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Error getting domain directory for instance : ${INSTANCE}"
      return 1
   fi
   LOGDIR=$(getLogDir ${DOMDIR} ${INSTANCE})
   if [[ ! -d ${LOGDIR} ]]; then
      echoe "Log store folder does not exists : ${LOGDIR}"
      return 1
   fi
   export DUMP_LOCATION_DEFAULT="${LOGDIR}/wls"
   [[ ! -d ${DUMP_LOCATION_DEFAULT} ]] && mkdir ${DUMP_LOCATION_DEFAULT}
   executeJvmCommand ${JCMD} ${INSTPID} ${JCMD_FLAG}
   return ${?}
}

# dispatch the jvm command to separate instances
doDispatchJvmCommand(){
   NAME="$1"
   JCMD="$2"
   JCMD_FLAG="$3"
   if [[ ${NAME} == "" ]]; then
      echoe "Enter a valid instance, cluster or domain name"
      return 1
   fi
   # encode the flag and action to 
   echo ${JCMD_FLAG} | grep -q ${JVMCMD_SEP}
   typeset -i ANS=${?}
   if [[ -n ${JCMD_FLAG} && ${ANS} -ne 0 ]]; then
      ACTENC="${JCMD}${JVMCMD_SEP}${JCMD_FLAG}"
   elif [[ -n ${JCMD_FLAG} && ${ANS} -eq 0 ]]; then
      # already encoded, invoked as part of remote dispatch
      ACTENC="${JCMD_FLAG}"
   else
      # no flag
      ACTENC="${JCMD}"
   fi
   LOCAL_INS="true"
   doDispatchCommand 'executeInstanceJvmCommand' ${NAME} "${ACTENC}"
   typeset -i ANS=$?
   return $ANS
}

#
# Main block start
#

WLADM_ACTION="${1}"
WLADM_NAME="${2}"
WLADM_FLAG="${3}"

#echo "main -> WLADM_ACTION : ${WLADM_ACTION}, WLADM_NAME : ${WLADM_NAME}, WLADM_FLAG : ${WLADM_FLAG}"
case ${WLADM_ACTION} in
        'ps')
                doDisplayPs ${WLADM_NAME}
                ;;
        'ping')   
                doPing ${WLADM_NAME}
                ;;
        'health')
                doDisplayHealth ${WLADM_NAME}
                ;;
        'state')
                doDisplayState ${WLADM_NAME}
                ;;
        'wlst')
                invokeWlst ${WLADM_NAME}
                ;;
        'rotate')
                doRotateLogs ${WLADM_NAME}
                ;;
        'tail')
                doTailOutLog ${WLADM_NAME} ${WLADM_FLAG}
                ;;
        'start')
                doStartServers ${WLADM_NAME} ${WLADM_FLAG}
                ;;
        'stop')
                doStopServers ${WLADM_NAME} ${WLADM_FLAG}
                ;;
        'restart')
                doRestartServers ${WLADM_NAME}
                ;;
        'kill')
                doKill ${WLADM_NAME}
                ;;
        'list')
                doList ${WLADM_NAME} ${WLADM_FLAG}
                ;;
        'clearjms')
                doClearJmsStore ${WLADM_NAME}
                ;;
        'clearlogs')
                doClearLogs ${WLADM_NAME}
                ;;
        'cleartmps')
                doClearWlsTmps ${WLADM_NAME}
                ;;
        'storeuserconfig')
                createUserKeyFilesForInstance ${WLADM_NAME}
                ;;
        'storebootconfig')
                createBootPropsForInstance ${WLADM_NAME}
                ;;
        *)
        	# check if its a jvm command
		if isJvmCommand ${WLADM_ACTION}; then
		   doDispatchJvmCommand ${WLADM_NAME} ${WLADM_ACTION} ${WLADM_FLAG}
		else
		   echoe "Invalid command : ${WLADM_ACTION}"
		   printUsage
                fi
        	;;
esac


