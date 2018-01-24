#!/bin/bash
#set -x

##############################################################
#                                                            #
# Tomcat Administration shell script                         #
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
ENABLE_COLOR="${ENABLE_COLOR:-true}"
typeset -r HEALTH_CHECK_URL='http://${HTTP_HOST}:${HTTP_PORT}/iCargoHealthCheck/HealthCheck?action=${HEALTH_ACTION}\&password=${HEALTH_CHECK_PASSWD}'
typeset -r HEALTH_CHECK_PASSWD='icargo123'


# source the jvm functions
. ${CURRDIR}/libs/jvm.functions.sh

TCTETC="${CURRDIR}/etc/tomcat.conf"

typeset -r TCTSRPT=$(basename ${0})
typeset -r RED_F="\033[1;31m"
typeset -r BLUE_F="\033[1;34m"
typeset -r YELLOW_F="\033[1;33m"
typeset -r GREEN_F="\033[1;32m"
typeset -r NC='\033[0m'
typeset -r WHITE_F='\033[1;37m'

# tomcat.conf column (name cluster-name host osuser http-port catalina-home catalina-base)
typeset -r CONF_NAME='$1'
typeset -r CONF_CLUSTER='$2'
typeset -r CONF_HOST='$3'
typeset -r CONF_USER='$4'
typeset -r CONF_PORT_HTTP='$5'
typeset -r CONF_CAT_HOME='$6'
typeset -r CONF_CAT_BASE='$7'

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
   Tomcat Server Administartion
   ------------------------------
   
   Command Syntax : ${TCTSRPT} <operation> <cluster-name | node-name>
 
   Tomcat Lifecycle :
      start                          : starts the tomcat server
      stop                           : stops the tomcat server
      kill                           : kills the tomcat server process
      status                         : retrieves the current status of the process
      ps                             : displays the process command line
      restart                        : restarts the tomcat server

   Application Deployment :   
      deploy                         : deploy the application [version]
      restore                        : restores the application to the specified version [version]
      version                        : queries the current version of the application
      history                        : displays the deployment history [count]
      freeze                         : disable health check
      thaw                           : enable health check
      health                         : displays the current health check status
      
   Server Provisioning
      create                         : create a new tomcat server instance
      destroy                        : destroy the server instance installation
      list                           : lists the current severs 
		
EOF_USG
   showJvmCommandUsage
}

# Retrieves the indexed entry from the conf
lookupConf(){
   TYPE="$1"
   ENTRYIDX="$2"
   ENTRYNAM="$3"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_TYPE}' == '\"${TYPE}\"' { print '${ENTRYIDX}' }' ${TCTETC})
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
   ENTRYVAL=$(awk '$0 !~ /^#/ { print '${ENTRYIDX}' }' ${TCTETC})
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
   local CLSNAME="$1"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_CLUSTER}' == '\"${CLSNAME}\"' { print '${CONF_NAME}' }' ${TCTETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the nodes of the cluster ${CLSNAME}"
      return 1
   fi
   echo $ENTRYVAL
   return 0
}

getConfForNode(){
   local NODENAME="$1"
   local FIELD="$2"
   ENTRYVAL=$(awk '$0 !~ /^#/ && '${CONF_NAME}' == '\"${NODENAME}\"' { print '${FIELD}' }' ${TCTETC})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRYVAL} == "" ]]; then
      echoe "Unable to find the field \"${FIELD}\" for node ${NODENAME}"
      return 1
   fi
   echo $ENTRYVAL
   return 0   
}

isThisBox(){
   local INST_HOST="$1"
   local OSTYP=$(uname -s)
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
   local CLSNAME="$1"
   CLS=$(lookupAllEntries ${CONF_CLUSTER} 'cluster')
   typeset -i ANS=${?}	
   if [[ ${ANS} -eq 0 ]]; then
      local CLSNAMEC=$(echo ${CLSNAME} | sed -e 's/[^A-Za-z0-9_ ]/_/g')
      echo ${CLS} | sed -e 's/[^A-Za-z0-9_ ]/_/g' | grep -qw ${CLSNAMEC}
      typeset -i ANS=${?}
   fi
   return ${ANS}
}

isNodeName(){
   local NODNAME="$1"
   NODS=$(lookupAllEntries ${CONF_NAME} 'node')
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      local NODNAMEC=$(echo ${NODNAME} | sed -e 's/[^A-Za-z0-9_ ]/_/g')
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
   local RCOMMAND="$1"
   local INSTANCE="$2"
   local FLAGS="$3"
   local REMCMD="${TCTSRPT} ${RCOMMAND} ${INSTANCE} ${FLAGS}"
   SRVOSUSER=$(getConfForNode ${INSTANCE} ${CONF_USER})
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 || '-' == ${SRVOSUSER} ]]; then
      local SRVHOST=$(getConfForNode ${INSTANCE} ${CONF_HOST})
      echoi "Dispatching command to server : ${SRVOSUSER}@${SRVHOST}"
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
   local COMMAND="$1"
   local NAME="$2"
   local DFLAGS="$3"
   local LOCAL="${4:-false}"
   isCluster ${NAME}
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      NODES=$(getAllNodesInCluster ${TYPE} ${NAME})
      assertExit ${?} 'Unable to get the nodes of the cluster'
      for NODE in ${NODES} ; do
         HOST=$(getConfForNode ${NODE} ${CONF_HOST})
         assertExit ${?} "Unable to get the host for node ${NODE}"
         [[ ${LOCAL} == 'true' ]] || isThisBox ${HOST}
         typeset -i ANS=${?}
         if [[ ${ANS} -eq 0 ]]; then
            println "[ ${NODE} ]"
            eval "${COMMAND} ${NODE} ${DFLAGS}"
         elif [[ ${LOCAL} == 'false' ]]; then
            dispatchCommandRemote ${TCT_ACT} ${NODE} ${TCT_FLAGS}
         fi
      done
   else
      isNodeName ${NAME}
      typeset -i ANS=${?}
      assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
      HOST=$(getConfForNode ${NAME} ${CONF_HOST})
      assertExit ${?} "Unable to get the host for node ${NAME} "
      [[ ${LOCAL} == 'true' ]] || isThisBox ${HOST}
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 0 ]]; then
         println "[ ${NAME} ]"
         eval "${COMMAND} ${NAME} ${DFLAGS}"
      elif [[ ${LOCAL} == 'false' ]]; then
         dispatchCommandRemote ${TCT_ACT} ${NAME} ${TCT_FLAGS}
      fi
   fi
   return 0
}

getPidFile(){
  local NODE="$1"
  local VALIDATE="{false:-$2}"
  THEHOME=$(getConfForNode ${NODE} ${CONF_CAT_BASE})
  assertExit ${?} "Unable to get home folder for node ${NODE}"
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
   local ARG="$1"
   DARGS=$(echo ${ARG} | sed -e 's/|/ /g')
   typeset -i ANS=${?}
   echo ${DARGS}
   return ${ANS}
}

isTcatRunning(){
  local NODE="$1"
  PIDFILE=$(getPidFile ${NODE} 'true')
  typeset -i ANS=${?}
  if [[ ${ANS} -ne 0 ]]; then
     return 1
  else
     local TXPID=$(cat ${PIDFILE})
     if [[ -n ${TXPID} ]]; then
        kill -0 ${TXPID} >/dev/null 2>&1
        typeset -i ANS=${?}
     else
        return 1
     fi
     echo ${TXPID}
     return ${ANS}
  fi
}


statusTcatInstance(){
   local NAME="$1"
   TCTPID=$(isTcatRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoi "Tomcat server instance \"${NAME}\" is running with PID ${TCTPID}"
   else
      echow "Tomcat server instance \"${NAME}\" is not running"
   fi
   return 0
}

startTcatInstance(){
   local NAME="$1"
   local FLAG="$2"
   TCTPID=$(isTcatRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echow "Tomcat server instance \"${NAME}\" is running with PID ${TCTPID}"
      return 1
   fi
   local CATBASE=$(getConfForNode ${NAME} ${CONF_CAT_BASE})
   if [[  ! -r ${CATBASE} ]]; then
      echoe "Catalina base directory not found ${CATBASE}"
      return 1
   fi
   local CATHOME=$(getConfForNode ${NAME} ${CONF_CAT_HOME})
   if [[  ! -r ${CATHOME} ]]; then
      echoe "Catalina home directory not found ${CATHOME}"
      return 1
   fi
   # some defaults 
   export CATALINA_BASE="${CATBASE}"
   export CATALINA_PID="${CATBASE}/.${NAME}.pid"
   export USE_NOHUP='true'
   export SERVER_NAME="${NAME}"
   echoi "Starting tomcat server ${NAME} ..."
   echoi "Server base : ${CATALINA_BASE}"
   ${CATHOME}/bin/catalina.sh start
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      local TCTPID=$(isTcatRunning ${NAME})
      echoi "Tomcat started sucessfully, PID : ${TCTPID}"
   else
      echoe "Unable to start tomcat server, check logs for furter details."
   fi
   if [[ ${FLAG} == 'tail' ]]; then
      local CATOUTFILE="${CATBASE}/logs/catalina.out"
      if [[ -f ${CATOUTFILE} ]]; then
         tail -f ${CATOUTFILE}
      else
         echow "Unable to find catalina out file in ${CATOUTFILE}"
      fi
   fi
   return ${ANS}
}

stopTcatInstance(){
   local NAME="$1"
   TCTPID=$(isTcatRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Tomcat server instance \"${NAME}\" is not running, ignoring stop operation"
      return 1
   fi
   local CATBASE=$(getConfForNode ${NAME} ${CONF_CAT_BASE})
   if [[  ! -r ${CATBASE} ]]; then
      echoe "Catalina base directory not found ${CATBASE}"
      return 1
   fi
   local CATHOME=$(getConfForNode ${NAME} ${CONF_CAT_HOME})
   if [[  ! -r ${CATHOME} ]]; then
      echoe "Catalina home directory not found ${CATHOME}"
      return 1
   fi
   export CATALINA_BASE="${CATBASE}"
   export CATALINA_PID="${CATBASE}/.${NAME}.pid"
   export SERVER_NAME="${NAME}"
   echoi "Stopping tomcat server ${NAME} with PID ${TCTPID}"
   echoi "Server base : ${CATBASE}"
   ${CATHOME}/bin/catalina.sh stop
   kill -0 ${TCTPID} >/dev/null 2>&1
   typeset -i ANS=${?}
   typeset -i count=0
   while [[ ${ANS} -eq 0 && ${count} -le 10 ]]; do
      sleep 2
      kill -0 ${TCTPID} >/dev/null 2>&1
      typeset -i ANS=${?}
      count=$((count + 1))
      echoi "Waiting for the process to stop PID : ${TCTPID}"
   done
   if [[ ${ANS} -eq 0 ]]; then
      echow "Graceful shutdown failed, killing the process ..."
      kill -9 ${TCTPID}
      waitForProcessDeath ${TCTPID}
   else
      echoi "Tomcat server stopped sucessfully."
   fi   
}

displayTcatInstancePs(){
   local NAME="$1"
   TCTPID=$(isTcatRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoi "Tomcat server instance \"${NAME}\" is running with PID ${TCTPID}"
   else
      echow "Tomcat server instance \"${NAME}\" is not running"
      return 1
   fi
   ps -ef | grep -v grep | grep ${TCTPID}
   return 0
}

killTcatInstance(){
   local NAME="$1"
   TCTPID=$(isTcatRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoi "Tomcat server instance \"${NAME}\" is running with PID ${TCTPID}"
   else
      echow "Tomcat server instance \"${NAME}\" is not running"
      return 1
   fi
   echoi "Sending TERM signal to PID : ${TCTPID}"
   kill -TERM ${TCTPID}
   sleep 2
   kill -0 ${TCTPID} >/dev/null 2>&1
   typeset -i ANS=${?}
   typeset -i count=0
   while [[ ${ANS} -eq 0 && ${count} -le 10 ]]; do
      sleep 2
      kill -0 ${TCTPID} >/dev/null 2>&1
      typeset -i ANS=${?}
      count=$((count + 1))
      echoi "Waiting for the process to stop PID : ${TCTPID}"
   done
   if [[ ${ANS} -eq 0 ]]; then
      echow "Graceful shutdown failed, killing the process ..."
      kill -9 ${TCTPID}
      waitForProcessDeath ${TCTPID}
   else
      echoi "Tomcat server stopped sucessfully."
   fi
   return 0
}

restartTcatInstance(){
   local NAME="$1"
   stopTcatInstance ${NAME}
   startTcatInstance ${NAME}
}


startTomcat(){
   local NAME="$1"
   local FLAG="$2"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'startTcatInstance' ${NAME} ${FLAG}
   return ${?}
}

stopTomcat(){
   local NAME="$1"
   local FLAG="$2"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'stopTcatInstance' ${NAME} ${FLAG}
   return ${?}
}

restartTomcat(){
  local NAME="$1"
  local FLAG="$2"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'restartTcatInstance' ${NAME} ${FLAG}
  return ${?}
}

statusTomcat(){
  local NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'statusTcatInstance' ${NAME}
  return ${?}
}

killTomcat(){
  local NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'killTcatInstance' ${NAME}
  return ${?}
}

displayTomcatPs(){
  local NAME="$1"
  test -n "${NAME}"
  typeset -i ANS=${?}
  assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
  dispatchCommand 'displayTcatInstancePs' ${NAME}
  return ${?}
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
      echoi "Waiting for the process to stop PID : ${TPID}"
   done
}

createTcatInstance(){
   #set -x
   local NAME="${1}"
   local CATBASE=$(getConfForNode ${NAME} ${CONF_CAT_BASE})
   if [[ -r ${CATBASE} ]]; then
      echoe "Catalina base directory already present ${CATBASE}, Please specify configure alternate home or destroy it."
      return 1
   fi
   local CATHOME=$(getConfForNode ${NAME} ${CONF_CAT_HOME})
   if [[ ! -r ${CATHOME} ]]; then
      echoe "Catalina home directory not found ${CATHOME}"
      return 1
   fi
   local HOST=$(getConfForNode ${NAME} ${CONF_HOST})
   isThisBox ${HOST} 
   typeset -i ANS=${?}
   assertExit ${ANS} "This instance is not configured to be hosted in this box, configured box ${HOST}."
   echoi "Creating domain home and directories ..."
   mkdir -pv ${CATBASE}/{bin,conf,lib,logs,webapps,work,temp,user_stage}
   typeset -i ANS=${?}
   assertExit ${ANS} "Directory creation failed, exiting ..."
   echoi "Creating user_stage directories ..."
   mkdir -pv ${CATBASE}/user_stage/{archive,landing,overrides,.conf}
   typeset -i ANS=${?}
   assertExit ${ANS} "Unable to user_stage directory structure."
   mkdir -pv ${CATBASE}/user_stage/overrides/scripts
   local USER_ENV="${CATBASE}/bin/setenv.sh"
cat << 'EOF' >> ${USER_ENV}
#!/bin/bash

# User environment configuration
JVM_MEM_ARGS='-server -Xms1G -Xmx1G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=50 -XX:+UseStringDeduplication'
export CATALINA_OPTS="${JVM_MEM_ARGS} -Djava.awt.headless=true"
EOF
   echoi "User env file created : ${USER_ENV}"
   HTTP_PORT=$(getConfForNode ${NAME} ${CONF_PORT_HTTP})
   typeset -i ANS=${?}
   assertExit ${ANS} "Unable to HTTP port for domain ${NAME}"
   echoi "Copying server configuration ..."
   cp -rv ${CATHOME}/conf ${CATBASE}
   typeset -i ANS=${?}
   assertExit ${ANS} "Unable to copy configurations from ${CATHOME}/conf to ${CATBASE}/conf"
   echow "Please edit the ${CATBASE}/conf/server.xml to correct the port configurations, threadpools etc. manually"
   echoi "Domain ${NAME} created sucessfully"
}

deleteTctInstance(){
   local NAME="${1}"
   local CATBASE=$(getConfForNode ${NAME} ${CONF_CAT_BASE})
   if [[ ! -r ${CATBASE} ]]; then
      echoe "Domain home directory ${CATBASE}, not found"
      return 1
   fi
   TCTPID=$(isTcatRunning ${NAME})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echoe "Tomcat instance ${NAME} is running with PID ${TCTPID}, Stop the server before destroying."
      return 1
   fi
   echo -n "Confirm destroy of instance ${NAME}(${CATBASE}) [y/n] : "
   read CNF
   if [[ ${CNF} != 'y' ]]; then
      echow "Confirmation failed exiting ...";
      return 1
   fi
   rm -r ${CATBASE}
   typeset -i ANS=${?}
   assertExit ${ANS} "Unable to remove domain home ${CATBASE}"
   echoi "Domain ${NAME} home ${CATBASE} removed sucessfully."
   return 0
}

typeset -r JVMCMD_SEP='@'

# dispatch to jvm library functions
executeInstanceJvmCommand(){
   local INSTANCE="$1"
   local JCMDENC="$2"
   local JCMD=$( echo ${JCMDENC} | awk 'BEGIN { FS='\"${JVMCMD_SEP}\"' } { print $1 }')
   local JCMD_FLAG=$( echo ${JCMDENC} | awk 'BEGIN { FS='\"${JVMCMD_SEP}\"' } { print $2 }')
   
   isNodeName ${NAME}
   typeset -i ISNODE=${?}
   if [[ ${ISNODE} -eq 0 ]]; then
      INSTPID=$(isTcatRunning ${INSTANCE})
      typeset -i ANS=${?}
      assertExit ${ANS} "Tomcat instance ${INSTANCE} is not running."
   else
      echoe "Enter a valid tomcat node name."
      return 1
   fi
   
   export DUMP_LOCATION_DEFAULT="/tmp/${INSTANCE}"
   [[ ! -d ${DUMP_LOCATION_DEFAULT} ]] && mkdir ${DUMP_LOCATION_DEFAULT}
   export JVM_NAME=${INSTANCE}
   executeJvmCommand ${JCMD} ${INSTPID} ${JCMD_FLAG}
   return ${?}
}

# dispatch the jvm command to separate instances
doDispatchJvmCommand(){
   local NAME="$1"
   local JCMD="$2"
   local JCMD_FLAG="$3"
   if [[ ${NAME} == "" ]]; then
      echoe 'Enter a valid tomcat node name.'
      return 1
   fi
   isNodeName ${NAME}
   typeset -i ISNODE=${?}
   
   if [[ ${ISES} -ne 0 ]]; then
      echoe 'Enter a valid tomcat node name.'
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
   dispatchCommand 'executeInstanceJvmCommand' ${NAME} "${ACTENC}"
   typeset -i ANS=$?
   return $ANS
}

listServers(){
   ALLNODES=$(lookupAllEntries ${CONF_NAME} 'nodes')
   typeset -i ANS=${?}
   assertExit ${ANS} 'Unable to lookup nodes'
   printf "%-20s | %-15s | %-20s | %-6s | %-7s | %-19s | %-s \n" 'Name' 'Cluster' 'Host Name' 'Port' 'PID' 'Status' 'Domain Base'
   echo '-----------------------------------------------------------------------------------------------------------'
   for NODE in ${ALLNODES}; do
      local HOST=$(getConfForNode ${NODE} ${CONF_HOST})
      isThisBox ${HOST}
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 0 ]]; then
         local CLS=$(getConfForNode ${NODE} ${CONF_CLUSTER})
         local PORT=$(getConfForNode ${NODE} ${CONF_PORT_HTTP})
         local BASE=$(getConfForNode ${NODE} ${CONF_CAT_BASE})
         if [[ -r ${BASE} ]]; then
            TCATPID=$(isTcatRunning ${NODE})
            typeset -i ANS=${?}
            if [[ ${ANS} -eq 0 ]]; then
               STATUS="${GREEN_F}RUNNING${NC}"
            else
               STATUS="${RED_F}STOPPED${NC}" 
               TCATPID='0'
            fi
         else
            STATUS="${YELLOW_F}UNSTAGED${NC}"
            TCATPID='0'
         fi
         printf "%-20s | %-15s | %-20s | %-6s | %-7s | %-19b | %-s \n" ${NODE} ${CLS} ${HOST} ${PORT} ${TCATPID} ${STATUS} ${BASE}
      fi
   done
}

generateServiceConf(){
   local NAME="${1}"
   local CONFTYPE="${2}"
   isNodeName ${NAME}
   typeset -i ISNODE=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Enter a valid tomcat server running in this box."
      return 1
	fi
   # Only systemd unit files are supported now
   if [[ ${CONFTYPE} == 'systemd' ]]; then
      local USER=$(getConfForNode ${NAME} ${CONF_USER})
      local GRP=$(id -ng ${USER})
      local CATBASE=$(getConfForNode ${NAME} ${CONF_CAT_BASE})
      local CLUSTER=$(getConfForNode ${NAME} ${CONF_CLUSTER})
      local UNITFILE="${CURRDIR}/${USER}-${CLUSTER}.service"
      local TMS=$(date +'%Y%m%d:%H%M')
cat << EOF_UNIT > ${UNITFILE}
#  Systemd unit file for Apache Tomcat 
# Generated by ${TCTSRPT} on ${TMS}
[Unit]
Description=Apache Tomcat Web Container
After=syslog.target network.target

[Service]
Type=forking

WorkingDirectory=${CATBASE}
Environment=JAVA_HOME=${JAVA_HOME}

ExecStart=${CURRDIR}/${TCTSRPT} start ${NAME}
ExecStop=${CURRDIR}/${TCTSRPT} stop ${NAME}

User=${USER}
Group=${GRP}
UMask=0002
RestartSec=3
Restart=always

[Install]
WantedBy=multi-user.target

EOF_UNIT
      echoi "Systemd unit file configuration writted to ${UNITFILE}"
      return 0
   else
      echoe "Unsupported init system specified, supported systemd"
      return 1
   fi
}

manageTcatInstanceHealth(){
   local NAME="${1}"
   local HEALTH_ACTION="${2:-status}"
   local HTTP_HOST=$(getConfForNode ${NAME} ${CONF_HOST})
   local HTTP_PORT=$(getConfForNode ${NAME} ${CONF_PORT_HTTP}) 
   if [[ ${ACTION} == 'activate' ]]; then
      echoi "Thawing instance ${NAME} ..."
   elif [[ ${ACTION} == 'deactivate' ]]; then
      echoi "Freezing instance ${NAME} ..."
   else
      # healthc heck returns the ststus line only if the action is empty
      HEALTH_ACTION=''
      echoi "Checking the health of the instance ${NAME} ..."
   fi
   local HEALTHURL=$(eval echo "${HEALTH_CHECK_URL}")
   HTTP_STATUS=$(curl -sw '%{http_code}' -o /dev/null --connect-timeout 2 -XPOST ${HEALTHURL})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      if [[ ${HTTP_STATUS} == '200' ]]; then
         if [[ ${HEALTH_ACTION} == 'activate' || ${HEALTH_ACTION} == 'deactivate' ]]; then
            echoi "Operation completed sucessfully"
            return 0
         else
            echoi "Health check ENABLED"
            return 0
         fi
      elif [[ ${HTTP_STATUS} == '500' ]]; then
         echow "Health check DISABLED"
         return 1
      elif [[ ${HTTP_STATUS} == '404' ]]; then
         echoe "Health check application not installed, server response is 404"
         return 2
      else
         echoe "Unknown status line returned by the server error code ${HTTP_STATUS}"
         return 2
      fi
   else
      echoe "Unable to connect to the server, the server may not be running. Error Code ${ANS}"
      return 7 
   fi
}

manageTomcatHealth(){
   local NAME="${1}"
   local ACTION="${2}"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   test -n "${ACTION}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Action is required : ${ACTION}"
   dispatchCommand 'manageTcatInstanceHealth' ${NAME} ${ACTION} 'true'
   return ${?}
}

deployAppOnInstance(){
   local NODE="${1}"
   local VERSION="${2}"
   local WAR="${3}"
   local APPLYOVERIDES="${4:-true}"
   local CATBASE=$(getConfForNode ${NODE} ${CONF_CAT_BASE})
   local LIVE="${CATBASE}/webapps" 
   local USRSTG="${CATBASE}/user_stage"
   local ARCHIVE="${USRSTG}/archive"
   local OVERRIDES="${USRSTG}/overrides"
   local CFGDIR="${USRSTG}/.conf"
   local WARNAME=$(basename ${WAR})
   local APPNAME="${WARNAME%.*}"
   local APPHASH=$(md5sum ${WAR} | cut -d' ' -f1) 
   if [[ -d ${LIVE}/${APPNAME} ]]; then
      local CVERSION='unknown'
      local CHASH='unknown'
      if [[ -r "${CFGDIR}/${APPNAME}.version" ]]; then
         CVERSION=$(cat "${CFGDIR}/${APPNAME}.version" | cut -d' ' -f1 )
         CHASH=$(cat "${CFGDIR}/${APPNAME}.version" | cut -d' ' -f3) 
      else
         echow "Current version absent for ${APPNAME}"
      fi
      if [[ ${APPHASH} == ${CHASH} ]]; then
         echow "The current deployed application and the staging version are the same for ${APPNAME} checksum ${CHASH} !"
         echow "Deployment skipped ..."
         return 0
      fi
      local ARCHIVEDIR="${ARCHIVE}/${CVERSION}"
      if [[ ! -r "${ARCHIVEDIR}/${APPNAME}.war" ]]; then 
         mkdir -p ${ARCHIVEDIR}
         echoi "Archiving current application to ${ARCHIVEDIR} ..."
         zip -rq "${ARCHIVEDIR}/${APPNAME}.war" "${LIVE}/${APPNAME}/"
         typeset -i ANS=${?}
         assertExit ${ANS} "Archive Operation failed"
      else
         echow "Existing archive found for version not overwriting ..."
      fi
      echoi "Deleting live location ${LIVE}/${APPNAME} ..."
      rm -r "${LIVE}/${APPNAME}"
      typeset -i ANS=${?}
      assertExit ${ANS} "Clearing live location failed."
   fi 
   echoi "Deploying application ${APPNAME} version ${VERSION} ..." 
   unzip -q ${WAR} -d "${LIVE}/${APPNAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Error exploding war ..."
   local DEPDATE=$(date '+%Y-%m-%d~%H:%M:%S')
   echo "${VERSION} ${DEPDATE} ${APPHASH}" >"${CFGDIR}/${APPNAME}.version"
   echo "${APPNAME} ${VERSION} ${DEPDATE} ${APPHASH}" >>"${CFGDIR}/history.log"
   if [[ ${APPLYOVERIDES} == 'true' && -d "${OVERRIDES}/${APPNAME}" ]]; then
      echoi "Applying override configurations ..."
      cp -vpr ${OVERRIDES}/${APPNAME} "${LIVE}/${APPNAME}"
   fi
   # check if there is a post deploy script to be executed for the app
   local PSCRPT="${OVERRIDES}/scripts/${APPNAME}.sh"
   if [[ ${APPLYOVERIDES} == 'true' && -x ${PSCRPT} ]]; then
      echoi "Executing post deployment script ${PSCRPT} ..."
      export ${APPNAME}
      export ${LIVE}
      export SERVER_NAME="${NODE}"
      . ${PSCRPT}
   fi
   echoi "Deployment completed for application ${APPNAME}."
   return 0 
}

deployOnInstance(){
   local NODE="${1}"
   local VERSION="${2}"
   local CATBASE=$(getConfForNode ${NODE} ${CONF_CAT_BASE}) 
   local LANDING="${CATBASE}/user_stage/landing" 
   if [[ ! -d ${LANDING} ]]; then
      echoe "Landing directory for instance ${NODE} not found ${LANDING}"
      return 1
   fi
   for WARF in $(find ${LANDING} -maxdepth 1 -type f -name '*.war' -print); do
      echoi "Deploying ${WARF} on instance ${NODE} ..."
      deployAppOnInstance ${NODE} ${VERSION} ${WARF} 'true'
      typeset -i ANS=${?}
      assertExit ${ANS} "Deployment of War ${WARF} failed on instance ${NODE}" 
      echo ''
   done
}

deploy(){
   local NAME="${1}"
   local VERSION="${2}"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}" 
   if [[ -z ${VERSION} ]]; then
      VERSION=$(date '+%Y%m%d_%H%M%S')
      echow "Using generated version for this deployment : ${VERSION}"
   fi
   # remote dispatch is disabled for deployment only local deployment is done now
   dispatchCommand 'deployOnInstance' ${NAME} ${VERSION} 'only'
}

displayInstanceHistory(){
   local NODE="${1}"
   local COUNT="${2}"
   local CATBASE=$(getConfForNode ${NODE} ${CONF_CAT_BASE})
   local CFGDIR="${CATBASE}/user_stage/.conf"
   local HISFILE="${CFGDIR}/history.log"
   if [[ -r ${HISFILE} ]]; then
      tail -${COUNT} ${HISFILE} | awk 'BEGIN { 
         printf "%-25s | %-25s | %-20s | %-33s\n", "Application", "Version", "Timestamp", "Checksum"  
         print "---------------------------------------------------------------------------------------------------------------"
         }
               { printf "%-25s | %-25s | %-20s | %-33s\n", $1, $2, $3, $4 }'
   else
      echoe "History file does not exists for this instance ${HISFILE}"
      return 1
   fi
   return 0
}

displayHistory(){
   local NAME="${1}"
   local COUNT=${2:-15}
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}"
   dispatchCommand 'displayInstanceHistory' ${NAME} ${COUNT}
}

restoreOnInstance(){
   local NODE="${1}"
   local VERSION="${2}"
   local CATBASE=$(getConfForNode ${NODE} ${CONF_CAT_BASE}) 
   local ARCHIVE="${CATBASE}/user_stage/archive/${VERSION}" 
   if [[ ! -d ${ARCHIVE} ]]; then
      echoe "No archives has been found with the specified version $ARCHIVE"
      return 1
   fi
   for WARF in $(find ${ARCHIVE} -maxdepth 1 -type f -name '*.war' -print); do
      echoi "Deploying ${WARF} on instance ${NODE} ..."
      deployAppOnInstance ${NODE} ${VERSION} ${WARF} 'false'
      typeset -i ANS=${?}
      assertExit ${ANS} "Deployment of War ${WARF} failed on instance ${NODE}" 
      echo ''
   done
}

restore(){
   local NAME="${1}"
   local VERSION="${2}"
   test -n "${NAME}"
   typeset -i ANS=${?}
   assertExit ${ANS} "Not a valid cluster or node name : ${NAME}" 
   if [[ -z ${VERSION} ]]; then
      echoe "Version is mandatory for restore operation"
      return 1
   fi
  dispatchCommand 'restoreOnInstance' ${NAME} ${VERSION} 'only'
}

# Greetings for the user :=)
userGreet(){
cat << EOF_MSG

Welcome you are the Tomcat Server Adinistrator.
The servers hosted on this box `hostname` are

`listServers local`

@See '${TCTSRPT} help' for administrative tasks and options.

EOF_MSG
}

# main block 

TCT_ACT="${1}"
TCT_ARG="${2}"
TCT_FLAGS="${3}"

case ${TCT_ACT} in 
   
   'start')
               startTomcat ${TCT_ARG} ${TCT_FLAGS}
               ;;
   'stop')
               stopTomcat ${TCT_ARG} ${TCT_FLAGS}
               ;;
   'status')
               statusTomcat ${TCT_ARG}
               ;;
   'restart')
               restartTomcat ${TCT_ARG} ${TCT_FLAGS}
               ;;
   'ps')
               displayTomcatPs ${TCT_ARG}
	       ;;
   'kill')
               killTomcat ${TCT_ARG}
	       ;;
   'create')
               createTcatInstance ${TCT_ARG}
   	       ;;
   'destroy')
	       deleteTctInstance ${TCT_ARG}
	       ;;
   'list')
              listServers 'local'
              ;;
   'service-conf')
              generateServiceConf ${TCT_ARG} 'systemd'
              ;;				  
   'freeze')
              manageTomcatHealth ${TCT_ARG} 'deactivate'
              ;;
   'thaw')
              manageTomcatHealth ${TCT_ARG} 'activate'
              ;;
   'health')
              manageTomcatHealth ${TCT_ARG} 'status' 
              ;;
   'deploy')
             deploy ${TCT_ARG} ${TCT_FLAGS}
             ;;
   'restore')
             restore ${TCT_ARG} ${TCT_FLAGS}
             ;;
   'history')
             displayHistory ${TCT_ARG} ${TCT_FLAGS}
             ;;
   '_greet')
             userGreet
             ;;
       *)
         # check if its a jvm command
   		if isJvmCommand ${TCT_ACT}; then
   		   doDispatchJvmCommand ${TCT_ARG} ${TCT_ACT} ${TCT_FLAGS}
   		else
   		   echoe "Invalid command : ${TCT_ACT}"
   		   showUsage
         fi
        	;;
esac


