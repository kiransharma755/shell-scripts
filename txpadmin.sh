#!/bin/bash
#set -x

##############################################################
#                                                            #
# TX Probe admin script                                      #
# @Author : Jens J P                                         #
#                                                            #
##############################################################

CURRDIR=`echo $0 | awk '$0 ~ /^\// { print }'`
if [[ ${CURRDIR} != "" ]]; then
  CURRDIR=`dirname $0`
else
  CURRDIR="`pwd``dirname $0 | cut -c2-`"
fi

export CURRDIR
# Some configurations
JAVA8_HOME="${JAVA8_HOME:-/nfs/opt/jdk1.8.0_71}"
CURATOR_HOME='/data/elasticsearch-curator'
export JAVA_HOME=${JAVA8_HOME}
TXPS_MEMARGS="-Xms1G -Xmx4G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=30 -Xverify:none -server"
TXPW_MEMARGS="-Xms2G -Xmx2G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=30 -XX:+AlwaysPreTouch -Xverify:none -server"
ENABLE_COLOR="${ENABLE_COLOR:-true}"
RETENTION=1

# source the jvm functions
. ${CURRDIR}/libs/jvm.functions.sh

TXPETC="${CURRDIR}/etc/txpstack.conf"
typeset -r TXPSRPT=$(basename ${0})
typeset -r RED_F="\033[1;31m"
typeset -r BLUE_F="\033[1;34m"
typeset -r YELLOW_F="\033[1;33m"
typeset -r GREEN_F="\033[1;32m"
typeset -r NC='\033[0m'
typeset -r WHITE_F='\033[1;37m'

# instance.conf column mapping
typeset -r CONF_TYPE='$1'
typeset -r CONF_USER='$2'
typeset -r CONF_CLUSTER='$3'
typeset -r CONF_NODE_NAME='$4'
typeset -r CONF_PRD_HOME='$5'
typeset -r CONF_HOST='$6'
typeset -r CONF_PORT_TRANSPORT='$7'
typeset -r CONF_PORT_HTTP='$8'
typeset -r CONF_PORT_AUX='$9'
typeset -r CONF_ARGS='$10'

# prints an error message to screen
echoe(){
   if [[ ${ENABLE_COLOR} == 'true' ]]; then
      echo -e "${RED_F}${*}${NC}"
   else
      echo "[ERROR] ${*}"
   fi
}

# prints an info message to screen
echoi(){
   if [[ ${ENABLE_COLOR} == 'true' ]]; then
      echo -e "${GREEN_F}${*}${NC}"
   else
      echo "[INFO] ${*}"
   fi
}

# prints an warning message to screen
echow(){
   if [[ ${ENABLE_COLOR} == 'true' ]]; then
      echo -e "${YELLOW_F}${*}${NC}"
   else
      echo "[WARNING] ${*}"
   fi
}

# Print a status line ( used as a separator )
println(){
   [[ ${NOPTR} == "true" ]] && return 0;
   if [[ ${ENABLE_COLOR} == 'true' ]]; then
      echo -e "${WHITE_F}------------------------------${1}------------------------------${NC}"
   else
      echo "------------------------------${1}------------------------------"
   fi
}

assertExit(){
   ANSRET=${1}
   EXTMSG="$2"
   if [[ ${ANSRET} -ne 0 ]]; then
      [[ -n ${EXTMSG} ]] && echoe ${EXTMSG}
      echoe "Unable to continue .. "
      exit ${ANSRET} 
   fi
}

showUsage(){
   cat << EOF_USG
   TX Probe Stack Administartion
   ------------------------------
   
   Command Syntax : ${TXPSRPT} <operation> <cluster-name | node-name>
 
   Elastic Search :
      start-es                   : starts the elastic search process
      stop-es                    : stops the elastic search process
      status-es                  : retrieves the current status of the process
      restart-es                 : restarts elastic search process

   Kibana :   
      start-kibana               : starts kibana server
      stop-kibana                : stops kibana server
      status-kibana              : retrieves the current status of the process
      restart-kibana             : restarts kibana server
      
   TxProbe Aggregation Server :
      start-txps                 : starts tx probe server
      stop-txps                  : stops tx probe server
      status-txps                : retrieves the current status of the process
      restart-txps               : restarts tx probe server
   
   TxProbe Web Server :
      start-txp-web              : starts tx probe webserver
      stop-txp-web               : stops tx probe webserver
      status-txp-web             : retrieves the current status of the process
      restart-txp-web            : restarts tx probe webserver
      
   iCargo Server :
      enable-txprobe             : enables tx probing in iCargo
      disable-txprobe            : disables/stops tx probing in iCargo
      enable-http-txprobe        : enables http probe in iCargo
      disable-http-txprobe       : disable http probe in iCargo
      enable-service-txprobe     : enables probing of ejb server calls in iCargo
      disable-service-txprobe    : disables probing of ejb server calls in iCargo
      enable-sql-txprobe         : enables probing of sql calls to database in iCargo
      disable-sql-txprobe        : disables probing of sql calls to database in iCargo
      enable-jmsws-txprobe       : enables probing of JMS WebService calls in iCargo
      disable-jmsws-txprobe      : disables probing of JMS WebService calls in iCargo
      enable-httpws-txprobe      : enables probing of HTTP WebService calls in iCargo
      disable-httpws-txprobe     : disables probing of HTTP WebService calls in iCargo
      enable-intf-txprobe        : enables probing of interface messages in iCargo
      disable-intf-txprobe       : disables probing of interface messages in iCargo
      status-txprobe             : displays all the probe activation status
      
   Cluster Management :
      start-all                  : starts all the process in the cluster
      stop-all                   : stops all the process in the cluster
      status-all                 : displays the status of the cluster
      
EOF_USG
   showJvmCommandUsage
}

# Retrieves the indexed entry from the conf
lookupConf(){
   TYPE="$1"
   ENTRYIDX="$2"
   ENTRYNAM="$3"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_TYPE}' == '\"${TYPE}\"' { print '${ENTRYIDX}' }' ${TXPETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the ${ENTRYNAM} (idx ${ENTRYIDX}) for type ${TYPE}"
      return 1
   fi
   echo $ENTRYVAL
   return 0
}

lookupAllEntries(){
   ENTRYIDX="$1"
   ENTRYNAM="$2"
   ENTRYVAL=$(awk '$0 !~ /^#/ { print '${ENTRYIDX}' }' ${TXPETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the ${ENTRYNAM} (idx ${ENTRYIDX})"
      return 1
   fi
   UNIQENTRYVAL=$(echo $ENTRYVAL | xargs -n1 | sort | uniq | xargs)
   echo ${UNIQENTRYVAL}
   return 0
}

getAllNodesInCluster(){
   TYPE="$1"
   CLSNAME="$2"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_TYPE}' == '\"${TYPE}\"' && '${CONF_CLUSTER}' == '\"${CLSNAME}\"' { print '${CONF_NODE_NAME}' }' ${TXPETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the nodes of the cluster ${CLSNAME} and type ${TYPE}"
      return 1
   fi
   echo $ENTRYVAL
   return 0
}

getHostForNode(){
   TYPE="$1"
   NODENAME="$2"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_TYPE}' == '\"${TYPE}\"' && '${CONF_NODE_NAME}' == '\"${NODENAME}\"' { print '${CONF_HOST}' }' ${TXPETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the hostname for node ${NODENAME} and type ${TYPE}"
      return 1
   fi
   echo $ENTRYVAL
   return 0   
}

getHomeForNode(){
   TYPE="$1"
   NODENAME="$2"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_TYPE}' == '\"${TYPE}\"' && '${CONF_NODE_NAME}' == '\"${NODENAME}\"' { print '${CONF_PRD_HOME}' }' ${TXPETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the hostname for node ${NODENAME} and type ${TYPE}"
      return 1
   fi
   echo $ENTRYVAL
   return 0   
}

getUserForNode(){
   TYPE="$1"
   NODENAME="$2"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_TYPE}' == '\"${TYPE}\"' && '${CONF_NODE_NAME}' == '\"${NODENAME}\"' { print '${CONF_USER}' }' ${TXPETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the osuser for node ${NODENAME} and type ${TYPE}"
      return 1
   fi
   echo $ENTRYVAL
   return 0   
}

getConfForNode(){
   TYPE="$1"
   NODENAME="$2"
   FIELD="$3"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_TYPE}' == '\"${TYPE}\"' && '${CONF_NODE_NAME}' == '\"${NODENAME}\"' { print '${FIELD}' }' ${TXPETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the field \"${FIELD}\" for node ${NODENAME} and type ${TYPE}"
      return 1
   fi
   echo $ENTRYVAL
   return 0   
}

isThisBox(){
   INST_HOST="$1"
   OSTYP=$(uname -s)
   if [[ ${OSTYP} == "SunOS" ]]; then
      ALLIPS=$(/usr/sbin/ifconfig -a | grep inet | awk '{ print $2 }' )
   else
      ALLIPS=$(hostname -i)
   fi
   for thisHost in localhost 127.0.0.1 $(hostname) ${ALLIPS} ; do
      if [[ ${thisHost} == ${INST_HOST} ]]; then
         return 0
      fi
   done
   return 1
}

isCluster(){
   CLSNAME="$1"
   CLSTYPE="$2"
   if [[ -z ${CLSTYPE} ]]; then 
      CLS=$(lookupAllEntries ${CONF_CLUSTER} 'cluster')
      typeset -i ANS=${?}
   else
      CLS=$(lookupConf ${CLSTYPE} ${CONF_CLUSTER} 'cluster')
      typeset -i ANS=${?}
   fi
   if [[ ${ANS} -eq 0 ]]; then
      CLSNAMEC=$(echo ${CLSNAME} | sed -e 's/[^A-Za-z0-9_ ]/_/g')
      echo ${CLS} | sed -e 's/[^A-Za-z0-9_ ]/_/g' | grep -qw ${CLSNAMEC}
      typeset -i ANS=${?}
   fi
   return ${ANS}
}

isNodeName(){
   NODNAME="$1"
   NODTYP="$2"
   if [[ -z ${NODTYP} ]]; then 
      NODS=$(lookupAllEntries ${CONF_NODE_NAME} 'node')
      typeset -i ANS=${?}
   else
      NODS=$(lookupConf ${NODTYP} ${CONF_NODE_NAME} 'node')
      typeset -i ANS=${?}
   fi
   if [[ ${ANS} -eq 0 ]]; then
      NODNAMEC=$(echo ${NODNAME} | sed -e 's/[^A-Za-z0-9_ ]/_/g')
      echo ${NODS} | sed -e 's/[^A-Za-z0-9_ ]/_/g' | grep -qw ${NODNAMEC}
      typeset -i ANS=${?}
   fi
   return ${ANS}
}

# function to dispatch commands remotely over ssh
# 1 : command
# 2 : instance name
# 3 : flags (optional)
dispatchCommandRemote(){
   RCOMMAND="$1"
   INSTANCE="$2"
   TYPE="$3"
   FLAGS="$4"
   REMCMD="${TXPSRPT} ${RCOMMAND} ${INSTANCE} ${FLAGS}"
   SRVOSUSER=$(getUserForNode ${TYPE} ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 || '-' == ${SRVOSUSER} ]]; then
      SRVHOST=$(getHostForNode ${TYPE} ${INSTANCE})
      echo "Dispatching command to server : ${SRVOSUSER}@${SRVHOST}"
      ssh "${SRVOSUSER}@${SRVHOST}" bash -c "'${REMCMD}'"
      typeset -i ANS=${?}
      if [[ ${ANS} -ne 0 ]]; then
         echoe "Error occurred while dispatching remote command errorCode : ${ANS} command : ${REMCMD}"
      fi
      return ${ANS}
   else
      echow "Remote dispatch is not enabled, do the operation manually : ${REMCMD}"
      return 1
   fi
   
}

dispatchCommand(){
   COMMAND="$1"
   NAME="$2"
   TYPE="$3"
   DFLAGS="$4"
   isCluster ${NAME} ${TYPE}
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      NODES=$(getAllNodesInCluster ${TYPE} ${NAME})
      assertExit ${?} 'Unable to get the nodes of the cluster'
      for NODE in ${NODES} ; do
         HOST=$(getHostForNode ${TYPE} ${NODE})
         assertExit ${?} "Unable to get the host for node ${NODE} type ${TYPE}"
         isThisBox ${HOST}
         typeset -i ANS=${?}
         if [[ ${ANS} -eq 0 ]]; then
            println "[ ${TYPE} - ${NODE} ]"
            eval "${COMMAND} ${NODE} ${DFLAGS}"
         else
            dispatchCommandRemote ${ELK_ACT} ${NODE} ${TYPE} ${ELK_FLAGS}
         fi
      done
   else
      isNodeName ${NAME} ${TYPE}
      typeset -i ANS=${?}
      assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
      HOST=$(getHostForNode ${TYPE} ${NAME})
      assertExit ${?} "Unable to get the host for node ${NAME} type ${TYPE}"
      isThisBox ${HOST}
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 0 ]]; then
         println "[ ${TYPE} - ${NAME} ]"
         eval "${COMMAND} ${NAME} ${DFLAGS}"
      else
         dispatchCommandRemote ${ELK_ACT} ${NAME} ${TYPE} ${ELK_FLAGS}
      fi
   fi
   return 0
}

getPidFile(){
  NODE="$1"
  TYPE="$2"
  VALIDATE="{false:-$3}"
  THEHOME=$(getHomeForNode ${TYPE} ${NODE})
  assertExit ${?} "Unable to get home folder for node ${NODE} type ${TYPE}"
  PIDFILE="${THEHOME}/.${NODE}.pid"
  if [[ 'true' == ${VALIDATE} ]]; then
     if [[ -r ${PIDFILE} ]]; then
        echo ${PIDFILE}
        return 0
     else
        return 1
     fi
  fi
  touch ${PIDFILE}
  echo ${PIDFILE}
  return 0
}

resolveArgs(){
   ARG="$1"
   DARGS=$(echo ${ARG} | sed -e 's/|/ /g')
   typeset -i ANS=${?}
   echo ${DARGS}
   return ${ANS}
}

isESRunning(){
  NODE="$1"
  PIDFILE=$(getPidFile ${NODE} 'es' 'true')
  typeset -i ANS=${?}
  if [[ ${ANS} -ne 0 ]]; then
     return 1
  else
     ESPID=$(cat ${PIDFILE})
     kill -0 ${ESPID} >/dev/null 2>&1
     typeset -i ANS=${?}
     echo ${ESPID}
     return ${ANS}
  fi
}

isKibanaRunning(){
  NODE="$1"
  PIDFILE=$(getPidFile ${NODE} 'kibana' 'true')
  typeset -i ANS=${?}
  if [[ ${ANS} -ne 0 ]]; then
     return 1
  else
     KBPID=$(cat ${PIDFILE})
     kill -0 ${KBPID} >/dev/null 2>&1
     typeset -i ANS=${?}
     echo ${KBPID}
     return ${ANS}
  fi
}

isTxpsRunning(){
  NODE="$1"
  PIDFILE=$(getPidFile ${NODE} 'txps' 'true')
  typeset -i ANS=${?}
  if [[ ${ANS} -ne 0 ]]; then
     return 1
  else
     TXPID=$(cat ${PIDFILE})
     kill -0 ${TXPID} >/dev/null 2>&1
     typeset -i ANS=${?}
     echo ${TXPID}
     return ${ANS}
  fi
}

isTxpWebRunning(){
  NODE="$1"
  PIDFILE=$(getPidFile ${NODE} 'txp-web' 'true')
  typeset -i ANS=${?}
  if [[ ${ANS} -ne 0 ]]; then
     return 1
  else
     TXPWID=$(cat ${PIDFILE})
     kill -0 ${TXPWID} >/dev/null 2>&1
     typeset -i ANS=${?}
     echo ${TXPWID}
     return ${ANS}
  fi
}

isICORunning(){
   NODE="$1"
   local ICOPID=$(ps -ef | grep "nodeName=${NODE}" | grep 'weblogic.Server' | grep -v 'grep' | awk '{ print $2 }')
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 || -z ${ICOPID} ]]; then
      return 1
   else
     kill -0 ${ICOPID} >/dev/null 2>&1
     typeset -i ANS=${?}
     echo ${ICOPID}
     return ${ANS}
  fi
}

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
   nohup ${JAVA8_HOME}/bin/java ${TXPW_MEMARGS} ${TXPWARGS} -cp ${TXPWHOME}/com.ibsplc.icargo.txprobe-aggregator.jar txprobe.tools export-web >${LOGFILE} 2>&1 &
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

statusESInstance(){
   NAME="$1"
   ESPID=$(isESRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoi "elasticsearch instance \"${NAME}\" is running with PID ${ESPID}"
   else
      echow "elasticsearch instance \"${NAME}\" is not running"
   fi
}

startESInstance(){
   NAME="$1"
   ESPID=$(isESRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echow "elasticsearch instance \"${NAME}\" is running with PID ${ESPID}"
      return 1
   fi
   PIDFILE=$(getPidFile ${NAME} 'es' 'false')
   ESHOME=$(getHomeForNode 'es' ${NAME})
   CLSNAME=$(getConfForNode 'es' ${NAME} ${CONF_CLUSTER})
   TRANSPORT=$(getConfForNode 'es' ${NAME} ${CONF_PORT_TRANSPORT})
   HTTPPORT=$(getConfForNode 'es' ${NAME} ${CONF_PORT_HTTP})
   ARGS=$(getConfForNode 'es' ${NAME} ${CONF_ARGS})
   ARGS=$(resolveArgs ${ARGS})
   ESARGS="-Ecluster.name=${CLSNAME} -Enode.name=${NAME} -Ehttp.port=${HTTPPORT} -Etransport.tcp.port=${TRANSPORT} ${ARGS}"
   OOM_ACTION="${CURRDIR}/.restart-es-${NAME}"
   echo "${CURRDIR}/${TXPSRPT} restart-es ${NAME}" >${OOM_ACTION}
   chmod +x ${OOM_ACTION}
   export ES_JAVA_OPTS="-XX:OnOutOfMemoryError=${OOM_ACTION}"
   echoi "starting elastic search instance ${NAME} with arguments \"${ESARGS}\""
   ${ESHOME}/bin/elasticsearch --daemonize --pidfile ${PIDFILE} ${ESARGS}
   
   typeset -i count=0
   ESPID=$(isESRunning ${NAME})
   typeset -i ANS=${?}
   while [[ ${ANS} -ne 0 && ${count} -le 10 ]]; do
      sleep 2
      ESPID=$(isESRunning ${NAME})
      typeset -i ANS=${?}
      count=$((count + 1))
   done
   if [[ ${ANS} -eq 0 ]]; then
      echoi "elasticsearch started sucessfully with PID ${ESPID}"
   else
      echow "elasticsearch would be starting in the background pidFile : ${PIDFILE}"
   fi
   return ${ANS}
}

stopESInstance(){
   NAME="$1"
   ESPID=$(isESRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "elasticsearch instance \"${NAME}\" is not running, ignoring stop operation"
      return 1
   fi
   echoi "stopping elasticsearch server ${NAME} with PID ${ESPID}"
   kill -TERM ${ESPID}
   kill -0 ${ESPID} >/dev/null 2>&1
   typeset -i ANS=${?}
   typeset -i count=0
   while [[ ${ANS} -eq 0 && ${count} -le 10 ]]; do
      sleep 2
      kill -0 ${ESPID} >/dev/null 2>&1
      typeset -i ANS=${?}
      count=$((count + 1))
      echoi "waiting for the process to stop PID : ${ESPID}"
   done
   if [[ ${ANS} -eq 0 ]]; then
      echow "graceful shutdown failed, killing the process ..."
      kill -9 ${ESPID}
      waitForProcessDeath ${ESPID}
   else
      echoi "elasticserver stopped sucessfully."
   fi   
}

restartESInstance(){
   NAME="$1"
   stopESInstance ${NAME}
   startESInstance ${NAME}
}

startES(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'startESInstance' ${NAME} 'es'
   return ${?}
}

stopES(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'stopESInstance' ${NAME} 'es'
   return ${?}
}

restartES(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'restartESInstance' ${NAME} 'es'
  return ${?}
}

statusKibanaInstance(){
   NAME="$1"
   KBPID=$(isKibanaRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoi "kibana instance \"${NAME}\" is running with PID ${KBPID}"
   else
      echow "kibana instance \"${NAME}\" is not running"
   fi
   return 0
}

startKibanaInstance(){
   NAME="$1"
   KBPID=$(isKibanaRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echow "kibana instance \"${NAME}\" is running with PID ${KBPID}"
      return 1
   fi
   PIDFILE=$(getPidFile ${NAME} 'kibana' 'false')
   KBHOME=$(getHomeForNode 'kibana' ${NAME})
   HTTPPORT=$(getConfForNode 'kibana' ${NAME} ${CONF_PORT_HTTP})
   ARGS=$(getConfForNode 'kibana' ${NAME} ${CONF_ARGS})
   ARGS=$(resolveArgs ${ARGS})
   KBARGS="--port ${HTTPPORT} ${ARGS}"
   echoi "starting kibana instance ${NAME} with arguments \"${KBARGS}\""
   nohup ${KBHOME}/bin/kibana ${KBARGS} >/dev/null 2>&1 &
   typeset KBPID=${!}
   echoi "kibana started with PID ${KBPID}"
   echo ${KBPID} >${PIDFILE}
   return 0
}

stopKibanaInstance(){
   NAME="$1"
   KBPID=$(isKibanaRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "kibana instance \"${NAME}\" is not running, ignoring stop operation"
      return 1
   fi
   echoi "stopping kibana server ${NAME} with PID ${KBPID}"
   kill -TERM ${KBPID}
   kill -0 ${KBPID} >/dev/null 2>&1
   typeset -i ANS=${?}
   typeset -i count=0
   while [[ ${ANS} -eq 0 && ${count} -le 10 ]]; do
      sleep 1
      kill -0 ${KBPID} >/dev/null 2>&1
      typeset -i ANS=${?}
      count=$((count + 1))
      echoi "waiting for the process to stop PID : ${KBPID}"
   done
   if [[ ${ANS} -eq 0 ]]; then
      echow "graceful shutdown failed, killing the process ..."
      kill -9 ${KBPID}
      waitForProcessDeath ${KBPID}
   else
      echoi "kibana stopped sucessfully."
   fi   
}

restartKibanaInstance(){
   NAME="$1"
   stopKibanaInstance ${NAME}
   startKibanaInstance ${NAME}
}

startKibana(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'startKibanaInstance' ${NAME} 'kibana'
   return ${?}
}

stopKibana(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'stopKibanaInstance' ${NAME} 'kibana'
   return ${?}
}

restartKibana(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'restartKibanaInstance' ${NAME} 'kibana'
  return ${?}
}

statusTxpInstance(){
   NAME="$1"
   TXPSPID=$(isTxpsRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoi "txprobe server instance \"${NAME}\" is running with PID ${TXPSPID}"
   else
      echow "txprobe server instance \"${NAME}\" is not running"
   fi
   return 0
}

startTxpInstance(){
   NAME="$1"
   TXPSPID=$(isTxpsRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echow "txprobe server instance \"${NAME}\" is running with PID ${TXPSPID}"
      return 1
   fi
   PIDFILE=$(getPidFile ${NAME} 'txps' 'false')
   TXPSHOME=$(getHomeForNode 'txps' ${NAME})
   TRANSPORT=$(getConfForNode 'txps' ${NAME} ${CONF_PORT_TRANSPORT})
   ARGS=$(getConfForNode 'txps' ${NAME} ${CONF_ARGS})
   ARGS=$(resolveArgs ${ARGS})
   TXPSARGS="-DnetworkServer.port=${TRANSPORT} ${ARGS}"
   LOGFILE="${TXPSHOME}/${NAME}.log"
   OOM_ACTION="'${CURRDIR}/${TXPSRPT} restart-txps ${NAME}'"
   echoi "starting txprobe instance ${NAME} with arguments \"${TXPSARGS}\""
   nohup ${JAVA8_HOME}/bin/java -XX:OnOutOfMemoryError="${OOM_ACTION}" ${TXPS_MEMARGS} ${TXPSARGS} -jar ${TXPSHOME}/com.ibsplc.icargo.txprobe-aggregator.jar >${LOGFILE} 2>&1 &
   typeset TXPSPID=${!}
   echoi "txprobe started with PID ${TXPSPID}"
   echo ${TXPSPID} >${PIDFILE}
   return 0
}

stopTxpInstance(){
   NAME="$1"
   TXPSPID=$(isTxpsRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "txprobe server instance \"${NAME}\" is not running, ignoring stop operation"
      return 1
   fi
   echoi "stopping txprobe server ${NAME} with PID ${TXPSPID}"
   kill -TERM ${TXPSPID}
   kill -0 ${TXPSPID} >/dev/null 2>&1
   typeset -i ANS=${?}
   typeset -i count=0
   while [[ ${ANS} -eq 0 && ${count} -le 10 ]]; do
      sleep 1
      kill -0 ${TXPSPID} >/dev/null 2>&1
      typeset -i ANS=${?}
      count=$((count + 1))
      echoi "waiting for the process to stop PID : ${TXPSPID}"
   done
   if [[ ${ANS} -eq 0 ]]; then
      echow "graceful shutdown failed, killing the process ..."
      kill -9 ${TXPSPID}
      waitForProcessDeath ${TXPSPID}
   else
      echoi "txprobe server stopped sucessfully."
   fi   
}

restartTxpInstance(){
   NAME="$1"
   stopTxpInstance ${NAME}
   startTxpInstance ${NAME}
}


startTxps(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'startTxpInstance' ${NAME} 'txps'
   return ${?}
}

stopTxps(){
   NAME="$1"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'stopTxpInstance' ${NAME} 'txps'
   return ${?}
}

restartTxps(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'restartTxpInstance' ${NAME} 'txps'
  return ${?}
}

statusTxps(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'statusTxpInstance' ${NAME} 'txps'
  return ${?}
}

statusES(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'statusESInstance' ${NAME} 'es'
  return ${?}
}

statusKibana(){
  NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'statusKibanaInstance' ${NAME} 'kibana'
  return ${?}
}

startAll(){
  NAME="$1"
  if [[ -z ${NAME} ]]; then
     CLUSTERS=$(lookupAllEntries ${CONF_CLUSTER} 'CONF_CLUSTER')
  else
     CLUSTERS="${NAME}"
  fi
  echoi "proceeding to start cluster ${CLUSTERS}"
  for CLSTR in ${CLUSTERS}; do
     ELK_ACT='start-es'
     startES ${CLSTR}
     ELK_ACT='start-kibana'
     startKibana ${CLSTR}
     ELK_ACT='start-txps'
     startTxps ${CLSTR}
     ELK_ACT='start-txp-web'
     startTxpWeb ${CLSTR}
  done
}

stopAll(){
  NAME="$1"
  if [[ -z ${NAME} ]]; then
     CLUSTERS=$(lookupAllEntries ${CONF_CLUSTER} 'CONF_CLUSTER')
  else
     CLUSTERS="${NAME}"
  fi
  echoi "proceeding to stop cluster ${CLUSTERS}"
  for CLSTR in ${CLUSTERS}; do
     ELK_ACT='stop-txp-web'
     stopTxpWeb ${CLSTR}
     ELK_ACT='stop-txps'
     stopTxps ${CLSTR}
     ELK_ACT='stop-kibana'
     stopKibana ${CLSTR}
     ELK_ACT='stop-es'
     stopES ${CLSTR}
  done
}

statusAll(){
  NAME="$1"
  if [[ -z ${NAME} ]]; then
     CLUSTERS=$(lookupAllEntries ${CONF_CLUSTER} 'CONF_CLUSTER')
  else
     CLUSTERS="${NAME}"
  fi
  echoi "retrieving status of cluster ${CLUSTERS}"
  for CLSTR in ${CLUSTERS}; do
     isCluster ${CLSTR} 'ico'
     typeset -i ISICOCLS="${?}"
     if [[ ${ISICOCLS} -eq 0 ]]; then
        manageiCargoTxProbe ${CLSTR} 'all' 'dont-care' 'read'
     else
        ELK_ACT='status-txp-web'
        statusTxpWeb ${CLSTR}
        ELK_ACT='status-txps'
        statusTxps ${CLSTR}
        ELK_ACT='status-kibana'
        statusKibana ${CLSTR}
        ELK_ACT='status-es'
        statusES ${CLSTR}
     fi
  done
}

#
# WARN : This is a hardcoded function for purging and index management
#
performPurge(){
# purge the indexes
   curator_cli --host 192.168.6.46 --port 10920 delete_indices --filter_list '[{"filtertype":"age","source":"name","direction":"older","unit":"hours","unit_count":48,"timestring":"-%Y%m%d%H"},{"filtertype":"pattern","kind":"prefix","value":"icargo_txprobe_index"}]'
   curator_cli --host 192.168.6.47 --port 10920 delete_indices --filter_list '[{"filtertype":"age","source":"name","direction":"older","unit":"hours","unit_count":48,"timestring":"-%Y%m%d%H"},{"filtertype":"pattern","kind":"prefix","value":"icargo_txprobe_index"}]'
# optimize the indexes by doing a merge of the segments
   curator_cli --host 192.168.6.46 --port 10920 forcemerge --max_num_segments 1 --delay 20 --filter_list '[{"filtertype":"age","source":"name","direction":"older","unit":"hours","unit_count":2,"timestring":"-%Y%m%d%H"},{"filtertype":"pattern","kind":"prefix","value":"icargo_txprobe_index"}]'
   curator_cli --host 192.168.6.47 --port 10920 forcemerge --max_num_segments 1 --delay 20 --filter_list '[{"filtertype":"age","source":"name","direction":"older","unit":"hours","unit_count":2,"timestring":"-%Y%m%d%H"},{"filtertype":"pattern","kind":"prefix","value":"icargo_txprobe_index"}]'
}

waitForProcessDeath(){
   typeset -i TPID="${1}"
   kill -0 ${TPID} >/dev/null 2>&1
   typeset -i TANS=${?}
   typeset -i count=0
   while [[ ${TANS} -eq 0 && ${count} -le 10 ]]; do
      sleep 2
      kill -0 ${TPID} >/dev/null 2>&1
      typeset -i TANS=${?}
      count=$((count + 1))
      echoi "waiting for the process to stop PID : ${TPID}"
   done
}

executeJmxJScript(){
   local NODE="$1"
   local ATTR="$2"
   local FLAG="$3"
   local OPR="${4:-read}"
   local ICOHOST=$(getHostForNode 'ico' ${NODE})
   assertExit ${?} "Unable to get the hostname for iCargo node ${NODE}"
   local ICOJMXPORT=$(getConfForNode 'ico' ${NODE} ${CONF_PORT_TRANSPORT})
   local JSFILE="${CURRDIR}/.${NODE}_${ATTR}.js"
   echo "" >${JSFILE}
   if [[ ${OPR} == 'write' ]]; then
   cat << EOFW >> ${JSFILE}
// generated js script by txpadmin.
var url = "service:jmx:rmi:///jndi/rmi://${ICOHOST}:${ICOJMXPORT}/jmxrmi";
//println("connecting to " + url)
var jmxServiceUrl = new javax.management.remote.JMXServiceURL(url);
var connector = javax.management.remote.JMXConnectorFactory.connect(jmxServiceUrl);
var mbs = connector.getMBeanServerConnection();
var attr = new javax.management.Attribute("${ATTR}", ${FLAG});
var on = new javax.management.ObjectName("com.ibsplc.xibase:type=txProbeConfig")
mbs.setAttribute(on, attr);
println("Successfully updated the attribute ${ATTR} to '${FLAG}' for node ${NODE}.");
connector.close();

EOFW
   else
   cat << EOFRD >> ${JSFILE}
// generated js script by txpadmin.
var url = "service:jmx:rmi:///jndi/rmi://${ICOHOST}:${ICOJMXPORT}/jmxrmi";
//println("connecting to " + url)
var jmxServiceUrl = new javax.management.remote.JMXServiceURL(url);
var connector = javax.management.remote.JMXConnectorFactory.connect(jmxServiceUrl);
var mbs = connector.getMBeanServerConnection();
var on = new javax.management.ObjectName("com.ibsplc.xibase:type=txProbeConfig")
var enabled = mbs.getAttribute(on, "Enabled");
var httpEnabled = mbs.getAttribute(on, "EnableHttpProbing");
var serviceEnabled = mbs.getAttribute(on, "EnableServiceProbing");
var jmsWSEnabled = mbs.getAttribute(on, "EnableJmsWebServiceProbing");
var httpWSEnabled = mbs.getAttribute(on, "EnableHttpWebServiceProbing");
var sqlEnabled = mbs.getAttribute(on, "EnableSqlProbing");
var intfEnabled = mbs.getAttribute(on, "EnableInterfaceMessageProbing");
println("${NODE} : ProbeEnabled                 : " + enabled);
println("${NODE} : HTTP ProbeEnabled            : " + httpEnabled);
println("${NODE} : Service ProbeEnabled         : " + serviceEnabled);
println("${NODE} : JMS WebService ProbeEnabled  : " + jmsWSEnabled);
println("${NODE} : HTTP WebService ProbeEnabled : " + httpWSEnabled);
println("${NODE} : SQL ProbeEnabled             : " + sqlEnabled);
println("${NODE} : Interface ProbeEnabled       : " + intfEnabled);
connector.close();

EOFRD
   fi
   JRS_HOME="${JAVA_HOME:-${JAVA8_HOME}}"
   JRS="${JRS_HOME}/bin/jrunscript"
   if [[ ! -x ${JRS} ]]; then
      echoe "JAVA_HOME or JAVA8_HOME env variables not present, unable to execute ${JRS}."
      return 1
   fi
   ${JRS} ${JSFILE} 2>/dev/null
   typeset -i ANS="${?}"
   if [[ ${ANS} -eq 0 ]]; then
      echoi "Operation completed successfully."
   else
      echoe "Operation failed, server might be down."
   fi
   rm ${JSFILE}
   return ${ANS}
}

manageiCargoTxProbe(){
   local NAME="$1"
   local ATTR="$2"
   local FLAG="$3"
   local OPR="$4"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} 'A valid iCargo cluster or node name should be specified'
   isNodeName ${NAME} 'ico'
   typeset -i ISNODE=${?}
   if [[ ${ISNODE} -eq 0 ]]; then
      println "[ ico - ${NAME} ]"
      executeJmxJScript ${NAME} ${ATTR} ${FLAG} ${OPR}
      return ${?}
   fi
   # check if this a icargo cluster
   isCluster ${NAME} 'ico'
   typeset -i ISCLS=${?}
   if [[ ${ISCLS} -eq 0 ]]; then
      NODES=$(getAllNodesInCluster 'ico' ${NAME})
      assertExit ${?} 'Unable to get the nodes of the cluster'
      for NODE in ${NODES} ; do
         println "[ ico - ${NODE} ]"
         executeJmxJScript ${NODE} ${ATTR} ${FLAG} ${OPR}
      done
      return 0
   else
      echoe "Not a valid iCargo cluster or node name : ${NAME}"
      return 1
   fi
}

typeset -r JVMCMD_SEP='@'

# dispatch to jvm library functions
executeInstanceJvmCommand(){
   INSTANCE="$1"
   JCMDENC="$2"
   JCMD=$( echo ${JCMDENC} | awk 'BEGIN { FS='\"${JVMCMD_SEP}\"' } { print $1 }')
   JCMD_FLAG=$( echo ${JCMDENC} | awk 'BEGIN { FS='\"${JVMCMD_SEP}\"' } { print $2 }')
   
   isNodeName ${NAME} 'es'
   typeset -i ISES=${?}
   isNodeName ${NAME} 'txps'
   typeset -i ISTXPS=${?}
   isNodeName ${NAME} 'txp-web'
   typeset -i ISTXPW=${?}
   isNodeName ${NAME} 'ico'
   typeset -i ISICO=${?}
   if [[ ${ISES} -eq 0 ]]; then
      INSTPID=$(isESRunning ${INSTANCE})
      typeset -i ANS=${?}
      assertExit ${ANS} "elasticsearch node ${INSTANCE} is not running."
   elif [[ ${ISTXPS} -eq 0 ]]; then
      INSTPID=$(isTxpsRunning ${INSTANCE})
      assertExit ${ANS} "txps node ${INSTANCE} is not running."
   elif [[ ${ISTXPW} -eq 0 ]]; then
      INSTPID=$(isTxpWebRunning ${INSTANCE})
      assertExit ${ANS} "txp webserver ${INSTANCE} is not running."
	elif [[ ${ISICO} -eq 0 ]]; then
      INSTPID=$(isICORunning ${INSTANCE})
      assertExit ${ANS} "iCargo server ${INSTANCE} is not running."  
   else
      echoe "Enter a valid txps or elasticsearch node name."
      return 1
   fi
   
   export DUMP_LOCATION_DEFAULT="/tmp/${INSTANCE}"
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
      echoe 'Enter a valid txps, txp-web, elasticsearch or icargo node name.'
      return 1
   fi
   isNodeName ${NAME} 'es'
   typeset -i ISES=${?}
   isNodeName ${NAME} 'txps'
   typeset -i ISTXPS=${?}
   isNodeName ${NAME} 'txp-web'
   typeset -i ISTXPW=${?}
   isNodeName ${NAME} 'ico'
   typeset -i ISICO=${?}
   
   if [[ ${ISES} -eq 0 ]]; then
      NODTYP='es'
   elif [[ ${ISTXPS} -eq 0 ]]; then
      NODTYP='txps'
   elif [[ ${ISTXPW} -eq 0 ]]; then
      NODTYP='txp-web'
   elif [[ ${ISICO} -eq 0 ]]; then
      NODTYP='ico'	  
   else
      echoe 'Enter a valid txps, txp-web, elasticsearch or icargo node name.'
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
   dispatchCommand 'executeInstanceJvmCommand' ${NAME} "${NODTYP}" "${ACTENC}"
   typeset -i ANS=$?
   return $ANS
}

# main block 

ELK_ACT="${1}"
ELK_ARG="${2}"
ELK_FLAGS="${3}"

case ${ELK_ACT} in 
   
   'start-es')
                startES ${ELK_ARG}
                ;;
   'stop-es')
                stopES ${ELK_ARG}
                ;;
   'status-es')
                statusES ${ELK_ARG}
                ;;
   'restart-es')
                restartES ${ELK_ARG}
                ;;
   'start-kibana')
               startKibana ${ELK_ARG}
               ;;
   'stop-kibana')
               stopKibana ${ELK_ARG}
               ;;
   'status-kibana')
               statusKibana ${ELK_ARG}
               ;;
   'restart-kibana')
               restartKibana ${ELK_ARG}
               ;;
   'start-txps')
               startTxps ${ELK_ARG}
               ;;
   'stop-txps')
               stopTxps ${ELK_ARG}
               ;;
   'status-txps')
               statusTxps ${ELK_ARG}
               ;;
   'restart-txps')
               restartTxps ${ELK_ARG}
               ;;
  'start-txp-web')
               startTxpWeb ${ELK_ARG}
               ;;
  'stop-txp-web')
               stopTxpWeb ${ELK_ARG}
               ;;
  'status-txp-web')
               statusTxpWeb ${ELK_ARG}
               ;;
  'restart-txp-web')
               restartTxpWeb ${ELK_ARG}
               ;;
   'start-all')
               startAll ${ELK_ARG}
               ;;
'enable-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'Enabled' 'true' 'write'
               ;;
'disable-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'Enabled' 'false' 'write'
               ;;
'enable-http-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableHttpProbing' 'true' 'write'
               ;;
'disable-http-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableHttpProbing' 'false' 'write'
               ;;
'enable-service-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableServiceProbing' 'true' 'write'
               ;;
'disable-service-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableServiceProbing' 'false' 'write'
               ;;  
'enable-sql-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableSqlProbing' 'true' 'write'
               ;;
'disable-sql-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableSqlProbing' 'false' 'write'
               ;;
'enable-jmsws-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableJmsWebServiceProbing' 'true' 'write'
               ;;
'disable-jmsws-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableJmsWebServiceProbing' 'false' 'write'
               ;;
'enable-httpws-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableHttpWebServiceProbing' 'true' 'write'
               ;;
'disable-httpws-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableHttpWebServiceProbing' 'false' 'write'
               ;;
'enable-intf-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableInterfaceMessageProbing' 'true' 'write'
               ;;
'disable-intf-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'EnableInterfaceMessageProbing' 'false' 'write'
               ;;
   'status-txprobe')
               manageiCargoTxProbe ${ELK_ARG} 'all' 'dont-care' 'read'
               ;;
   'stop-all')
               stopAll ${ELK_ARG}
               ;;
   'status-all')
               statusAll ${ELK_ARG}
               ;;
        'purge')
               performPurge
               ;;
              *)
                # check if its a jvm command
   		if isJvmCommand ${ELK_ACT}; then
   		   doDispatchJvmCommand ${ELK_ARG} ${ELK_ACT} ${ELK_FLAGS}
   		else
   		   echoe "Invalid command : ${ELK_ACT}"
   		   showUsage
                fi
        	;;
esac


