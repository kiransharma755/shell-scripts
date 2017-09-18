#!/bin/bash
#set -x

##############################################################
#                                                            #
# Performance test manager script                            #
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
ENABLE_REMOTE_DISPATCH="true"
DBHOSTS="10.183.122.64 10.183.122.65 10.183.122.66 10.183.122.67"
#DBHOSTS="10.183.122.64"

# source the companion scripts
. ${CURRDIR}/libs/wladmin.functions.sh

PERFDIR="${CURRDIR}/perfTest"

println(){
   [[ ${NOPTR} == "true" ]] && return 0;
   echo "[testmgr]------------------------------${1}------------------------------[testmgr]"
}

printUsage(){
 println "-"
 echo "Usage "
 echo ""
 echo "   Lifecycle : testmgr ( start | stop ) <test-name>"
 echo "    start   - starts the stats data gathering and initializations"
 echo "    stop    - stops the stats data gathering "
 echo ""
 echo "   Info : testmgr ( list ) <test-name>"
 echo "    list    - displays the current test status"
 echo ""
 println "-"
}

getCfgValue(){
   CFGFILE="${1}"
   CFGKEY="${2}"
   CFGVAL=$(grep ${CFGKEY} ${CFGFILE} | awk 'BEGIN { FS="=" } { print $2 } ')
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]];then
      echo ${CFGVAL}
      return 0
   else
      echo "[ERROR] Unable to get value for key : ${CFGKEY}" 
      return 1
   fi
}

# get all domains configured
getAllHosts(){
   ALLHOSTS=$(awk '$0 !~ /^#/ { print '${CONF_HOST_COLUMN}' }' ${CONF_FILE} | sort | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ALLHOSTS} == "" ]]; then
      echo "[ERROR] Unable to retrieve all hosts." >&2
      return 1
   fi
   echo ${ALLHOSTS}
   return 0
}

# checks if the host is the localhost
isLocalHost(){
   INST_HOST="${1}"
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

# function to dispatch commands remotely over ssh
# 1 : command
# 2 : instance name
# 3 : flags (optional)
# return : 0 if success, 50 if local , 60 if remote dispatch not enabled, 1 execution errors
dispatchInstanceCommand(){
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
         echo "[INFO] dispatching command to server : ${SRVOSUSER}@${SRVHOST}"
         REMCMD="testmgr ${COMMAND} ${INSTANCE} ${FLAGS}"
         #ssh "${SRVOSUSER}@${SRVHOST}" "\"${REMCMD}\""
         ssh "${SRVOSUSER}@${SRVHOST}" bash -c "'${REMCMD}'"
         typeset -i ANS=${?}
         if [[ ${ANS} -ne 0 ]]; then
            echo "[ERROR] error occurred while dispatching remote command errorCode : ${ANS} command : ${REMCMD}"
         fi
         return 1
      else
         return 60
      fi
   else
      return 50
   fi
}

# function to dispatch commands remotely over ssh
# 1 : command
# 2 : instance name
# 3 : flags (optional)
# return : 0 if success, 50 if local ,  1 execution errors
dispatchHostCommand(){
   COMMAND="$1"
   SRVHOST="$2"
   FLAGS="$3"
   isLocalHost ${SRVHOST}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      SRVOSUSER="oracle"
      echo "[INFO] dispatching command to server : ${SRVOSUSER}@${SRVHOST}"
      REMCMD="testmgr ${COMMAND} ${SRVHOST} ${FLAGS}"
      ssh "${SRVOSUSER}@${SRVHOST}" bash -c "'${REMCMD}'"
      typeset -i ANS=${?}
      if [[ ${ANS} -ne 0 ]]; then
         echo "[ERROR] error occurred while dispatching remote command errorCode : ${ANS} command : ${REMCMD}"
      fi
      return ${ANS}
   else
      return 50
   fi
}

storeLogFileLines(){
  TESTINFO=${1}
  INSTANCE=${2}
  DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
  LOGDIR="${DOMDIR}/servers/${INSTANCE}/logs"
  LOGFILES="${LOGDIR}/${INSTANCE}.out ${LOGDIR}/${INSTANCE}_GC.log ${LOGDIR}/${INSTANCE}_access.log"
  for LOGFILE in ${LOGFILES}; do
     if [[ -r ${LOGFILE} ]]; then
        LINCNT=$(wc -l ${LOGFILE} | awk '{ print $1 }')
        LOGFILENAME=$(basename ${LOGFILE})
        echo "${LOGFILENAME}_lineCount=${LINCNT}" >> ${TESTINFO}
     fi
  done
}

saveLogFiles(){
  TESTINFO=${1}
  INSTANCE=${2}
  TESTDIR=$(dirname ${TESTINFO})
  DOMDIR=$(getDomainDirectoryForInstance ${INSTANCE})
  LOGDIR="${DOMDIR}/servers/${INSTANCE}/logs"
  LOGFILES="${LOGDIR}/${INSTANCE}.out ${LOGDIR}/${INSTANCE}_GC.log ${LOGDIR}/${INSTANCE}_access.log"
  for LOGFILE in ${LOGFILES}; do
     if [[ -r ${LOGFILE} ]]; then
        cp ${LOGFILE} ${TESTDIR}
     fi
  done
}

startNmon(){
   TESTNAME="${1}"
   TESTINFO="${2}"
   typeset -i NUMSAMPLES="15000" # 13000
   if [[ -r "/ibs/logs/base_domain/wls" ]]; then
      LOGDIR="/ibs/logs/base_domain/wls"
   elif [[ -r "/cellone/logs/base_domain/wls" ]]; then
      LOGDIR="/cellone/logs/base_domain/wls"
   elif [[ -r "/home/oracle/icob/logs" ]]; then
      LOGDIR="/home/oracle/icob/logs"
   else
      echo "[ERROR] unable to resolve log directory for nmon !!!"
      return 1
   fi
   HOSTNAME=$(hostname)
   NMONLOG="${LOGDIR}/${HOSTNAME}_${TESTNAME}_nmon.log"
   NMONTEST="${TESTNAME}(${HOSTNAME})"
   NMONPID=$(nmon -F ${NMONLOG} -r ${NMONTEST} -p -t -s20 -c${NUMSAMPLES} )
   if [[ ! -n ${NMONPID} ]]; then
      echo "[ERROR] error starting nmon on host ${HOSTNAME} for test ${TESTNAME}" >&2
      return 1
   else
      echo "[INFO] nmon started successfully on host ${HOSTNAME} PID ${NMONPID}"
   fi
   echo "${HOSTNAME}_nmonPid=${NMONPID}" >> ${TESTINFO}
   return 0
}

stopNmon(){
   TESTNAME="${1}"
   TESTINFO="${2}"
   TESTDIR=$(dirname ${TESTINFO})
   if [[ -r "/ibs/logs/base_domain/wls" ]]; then
      LOGDIR="/ibs/logs/base_domain/wls"
   elif [[ -r "/cellone/logs/base_domain/wls" ]]; then
      LOGDIR="/cellone/logs/base_domain/wls"
   elif [[ -r "/home/oracle/icob/logs" ]]; then
      LOGDIR="/home/oracle/icob/logs"
   else
      echo "[ERROR] unable to resolve log directory for nmon !!!"
      return 1
   fi
   HOSTNAME=$(hostname)
   NMONLOG="${LOGDIR}/${HOSTNAME}_${TESTNAME}_nmon.log"
   PIDVAR=$(getCfgValue ${TESTINFO} "${HOSTNAME}_nmonPid")
   echo "[INFO] stoping nmon PID : ${PIDVAR}"
   kill -9 "${PIDVAR}"
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echo "[INFO] nmon stopped successfully"
   else
      echo "[ERROR] nmon stop operation failed"
   fi
   if [[ -e ${NMONLOG} ]]; then
      mv ${NMONLOG} ${TESTDIR}
      typeset -i ANS=${?}
      if [[ ${ANS} -ne 0 ]]; then
         echo "[ERROR] unable to copy nmon logfile : ${NMONLOG}"
         return 1
      else
         echo "[INFO] nmon logs backed up successfully"
      fi
   else
      echo "[ERROR] unable to find nmon logs : ${NMONLOG}"
      return 1
   fi
   return 0
}

restartOTD(){
   #echo "OTD restart not implemented"
   ssh oracle@inxlcn06 ' cd /home/oracle/otd1/net-IBSConfig/bin && ./restart '
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      echo "[INFO] OTD restarted sucessfully."
      echo "[INFO] Waiting for OTD to stabilize ..."
      sleep 45
   else
      echo "[ERROR] OTD restart failed "
      return 1
   fi
   return 0
}

saveOTDStats(){
   TESTNAME="${1}"
   EVENT="${2}"
   TESTDIR="${PERFDIR}/${TESTNAME}"
   OTDSTAT="${TESTDIR}/${TESTNAME}_${EVENT}_OTDPerf.perf"
   wget -q -O ${OTDSTAT} http://inxlcn06:7080/.perf
   return $?
}

startTestInstance(){
   INSTANCE="$1"
   TESTNAME="$2"
   println " instance ${INSTANCE} "
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   [[ ! -r ${TESTDIR} ]] && mkdir -p ${TESTDIR}
   storeLogFileLines ${TESTINFO} ${INSTANCE}
   return ${?}
}

startTestHost(){
   WLHOST="${1}"
   TESTNAME="${2}"
   println " host ${WLHOST} "
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   [[ ! -r ${TESTDIR} ]] && mkdir -p ${TESTDIR}
   startNmon "${TESTNAME}" "${TESTINFO}"
}

stopTestInstance(){
   INSTANCE="$1"
   TESTNAME="$2"
   println " instance ${INSTANCE} "
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   saveLogFiles ${TESTINFO} ${INSTANCE}
   return ${?}
}

stopTestHost(){
   WLHOST="${1}"
   TESTNAME="${2}"
   println " host ${WLHOST} "
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   [[ ! -r ${TESTDIR} ]] && mkdir -p ${TESTDIR}
   stopNmon "${TESTNAME}" "${TESTINFO}"
}

storeAlertFileLines(){
  TESTINFO=${1}
  INSTANCE=${2}
  DBNAME="icargo"
  LOGDIR="/u01/app/oracle/diag/rdbms/${DBNAME}/${INSTANCE}/alert"
  LOGFILES="log.xml"
  typeset -i ANS=1
  for LOGFILEBS in ${LOGFILES}; do
     LOGFILE="${LOGDIR}/${LOGFILEBS}"
     if [[ -r ${LOGFILE} ]]; then
        LINCNT=$(wc -l ${LOGFILE} | awk '{ print $1 }')
        LOGFILENAME=$(basename ${LOGFILE})
        echo "${INSTANCE}_${LOGFILENAME}_lineCount=${LINCNT}" >> ${TESTINFO}
        ANS=${?}
     fi
  done
  return ${ANS}
}

saveAlertFile(){
  TESTNAME=${1}
  INSTANCE=${2}
  TESTDIR="${PERFDIR}/${TESTNAME}"
  TESTINFO="${TESTDIR}/testInfo.sh"
  DBNAME="icargo"
  LOGDIR="/u01/app/oracle/diag/rdbms/${DBNAME}/${INSTANCE}/alert"
  LOGFILES="log.xml"
  typeset -i ANS=1
  for LOGFILEBS in ${LOGFILES}; do
     LOGFILE="${LOGDIR}/${LOGFILEBS}"
     if [[ -r ${LOGFILE} ]]; then
        cp ${LOGFILE} "${TESTDIR}/alert_${INSTANCE}_${TESTNAME}.xml"
        ANS=${?}
     fi
  done
  return ${ANS}
}

getDBInstanceForHost(){
   DBHOST="${1}"
   case ${DBHOST} in
        inx24db01*)
               INSTANCE="icargo1"
               ;;
        inx24db02*)
	       INSTANCE="icargo2"
               ;;
        inx24db03*)
	       INSTANCE="icargo3"
               ;;
        inx24db04*)
	       INSTANCE="icargo4"
               ;;
        '10.183.122.64')
               INSTANCE="icargo1"
               ;;
        '10.183.122.65')
	       INSTANCE="icargo2"
               ;;
        '10.183.122.66')
	       INSTANCE="icargo3"
               ;;
        '10.183.122.67')
	       INSTANCE="icargo4"
               ;;       
        *)
               echo "[ERROR] invalid DB host : ${DBHOST}"
               return 1
               ;;
   esac
   echo ${INSTANCE}
   return 0
}

createDBSnapshot(){
   SNAPSHOT=$(sqlplus -S / as sysdba @"${CURRDIR}/sql/createSnapshot.sql" | grep db_snapshot | awk ' { print $2 } ')
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] unable to generate db snapshot" > 2
      return 1
   fi
   echo ${SNAPSHOT}
   return 0
}

generateAWRReport(){
   INSTANCE="${1}"
   TESTNAME="${2}"
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   START_SNAPSHOT=$(getCfgValue ${TESTINFO} "snapshot_start_${INSTANCE}")
   END_SNAPSHOT=$(getCfgValue ${TESTINFO} "snapshot_end_${INSTANCE}")
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 || -z ${START_SNAPSHOT} || -z ${END_SNAPSHOT} ]]; then
      echo "[ERROR] unable to retrieve start and end shapshots for instance - ${INSTANCE}"
      echo "[ERROR] START_SNAPSHOT - ${START_SNAPSHOT} END_SNAPSHOT - ${END_SNAPSHOT}"
      return 1
   fi
   echo "[INFO] generating AWR report for instance ${INSTANCE} ..."
   AWRFILE="${TESTDIR}/awr_${INSTANCE}_${TESTNAME}.html"
   sqlplus -S / as sysdba @"${CURRDIR}/sql/generateAWR.sql" "${START_SNAPSHOT}" "${END_SNAPSHOT}" "${AWRFILE}" >/dev/null 2>&1
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] failed to generate awr report for instance : ${INSTANCE}"
      echo "[ERROR] START_SNAPSHOT - ${START_SNAPSHOT} END_SNAPSHOT - ${END_SNAPSHOT}"
      return 1
   else
      echo "[INFO] awr report generated successfully : ${AWRFILE}"
      return 0
   fi
}

stopDBInstanceMonitoring(){
   DBHOST="${1}"
   TESTNAME="${2}"
   println " database ${DBHOST} "
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   [[ ! -r ${TESTDIR} ]] && mkdir -p ${TESTDIR}
   stopNmon "${TESTNAME}" "${TESTINFO}"
   
   INSTANCE=$(getDBInstanceForHost ${DBHOST})
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      return ${ANS}
   fi
   # save alert file
   saveAlertFile ${TESTNAME} ${INSTANCE}
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] unable to copy DB log files ..."
      return ${ANS}
   fi
   # create the end snapshot
   SNAPSHOT=$(createDBSnapshot )
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      return ${ANS}
   else
      echo "[INFO] DB workload snapshot created for instance ${INSTANCE} , snapshot : ${SNAPSHOT}"
   fi
   echo "snapshot_end_${INSTANCE}=${SNAPSHOT}" >>${TESTINFO}
   generateAWRReport ${INSTANCE} ${TESTNAME}
   
}

startDBInstanceMonitoring(){
   DBHOST="${1}"
   TESTNAME="${2}"
   println " database ${DBHOST} "
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   [[ ! -r ${TESTDIR} ]] && mkdir -p ${TESTDIR}
   startNmon "${TESTNAME}" "${TESTINFO}"
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] nmon start failed for node : ${DBHOST}" 
      return ${ANS}
   fi
   INSTANCE=$(getDBInstanceForHost ${DBHOST})
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      return ${ANS}
   fi
   storeAlertFileLines ${TESTINFO} ${INSTANCE}
   # create the start snapshot
   SNAPSHOT=$(createDBSnapshot )
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      return ${ANS}
   else
      echo "[INFO] DB workload snapshot created for instance ${INSTANCE} , snapshot : ${SNAPSHOT}"
   fi
   echo "snapshot_start_${INSTANCE}=${SNAPSHOT}" >>${TESTINFO}
   return 0
}

gatherArtefacts(){
  TESTNAME="${1}"
  TESTDIR="${PERFDIR}/${TESTNAME}"
  TESTINFO="${TESTDIR}/testInfo.sh"
  echo "[INFO] downloading stats and logs from remote weblogic servers ..."
  ssh oracle@192.168.9.102 "cat /cellone/icob/perfTest/${TESTNAME}/testInfo.sh" >> ${TESTINFO}
  ssh oracle@192.168.9.102 bash -c "'cd /cellone/icob/perfTest && jar -cvfM ${TESTNAME}.zip ${TESTNAME}/ '"
  typeset -i ANS=${?}
  if [[ ${ANS} -eq 0 ]]; then
     scp oracle@192.168.9.102:/cellone/icob/perfTest/${TESTNAME}.zip /ibs/icob/perfTest
     typeset -i ANS=${?}
     if [[ ${ANS} -eq 0 ]]; then
        echo "[INFO] stats downloaded to /ibs/icob/perfTest/${TESTNAME} ... extracting ..."
        unzip -nq -d /ibs/icob/perfTest /ibs/icob/perfTest/${TESTNAME}.zip
        rm /ibs/icob/perfTest/${TESTNAME}.zip
     fi
  else
     echo "[ERROR] remote artefact gather operation failed !!"
  fi
  
  # gather db artefacts
  echo "[INFO] downloading stats and logs from remote db servers ..."
  DBPERFHOME="/home/oracle/icob/perfTest"
  DBPERFDIR="${DBPERFHOME}/${TESTNAME}"
  for DBHOST in ${DBHOSTS}; do
     ssh oracle@${DBHOST} "cat ${DBPERFDIR}/testInfo.sh" >> ${TESTINFO}
     ssh oracle@${DBHOST} bash -c "'cd ${DBPERFHOME} && jar -cvfM ${TESTNAME}.zip ${TESTNAME}/ '"   
     typeset -i ANS=${?}
     if [[ ${ANS} -eq 0 ]]; then
        scp oracle@${DBHOST}:${DBPERFHOME}/${TESTNAME}.zip /ibs/icob/perfTest
        typeset -i ANS=${?}
        if [[ ${ANS} -eq 0 ]]; then
           echo "[INFO] DB stats downloaded to /ibs/icob/perfTest/${TESTNAME} ... extracting ..."
           unzip -nq -d /ibs/icob/perfTest /ibs/icob/perfTest/${TESTNAME}.zip
           rm /ibs/icob/perfTest/${TESTNAME}.zip
        fi
     else
        echo "[ERROR] remote DB artefact gather operation failed for host ${DBHOST} !!"
     fi     
  done
  return ${ANS}
}

startTest(){
   TESTNAME="${1}"
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   mkdir -p ${TESTDIR}
   touch ${TESTINFO} && chmod +x ${TESTINFO}
   ST=$(TZ=Asia/Kolkata date)
   echo "START_TIME=${ST}" >> ${TESTINFO}
   # restart OTD
   echo "[INFO] restarting OTD ..."
   restartOTD
   saveOTDStats ${TESTNAME} "start"
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] OTD restart failed ... exiting"
      return ${ANS}
   fi
   # do for all instances
   ALLDOMAINS=$(getAllDomains "false")
   for DOM in ${ALLDOMAINS}; do
      echo "[INFO] considering domain : ${DOM}"
      ALLINSTS=$(findAllInstancesForDomain ${DOM} "false" "I")
      for INS in ${ALLINSTS} ; do
         dispatchInstanceCommand "start-test-ins" ${INS} ${TESTNAME}
         typeset -i ANS=${?}
         if [[ ${ANS} -eq 60 ]]; then
	    echo "[ERROR] Instance : ${INS} is not in this box and remote dispatch is disabled."
	    #return 1
	 elif [[ ${ANS} -eq 50 ]]; then
	    startTestInstance ${INS} ${TESTNAME}
         fi
      done
   done
   # start nmon in all hosts
   ALLHOSTS=$(getAllHosts )
   for WLHOST in ${ALLHOSTS}; do
      dispatchHostCommand "start-test-host" ${WLHOST} ${TESTNAME}
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 50 ]]; then
      	 startTestHost ${WLHOST} ${TESTNAME}
      fi
   done
   # start monitoring in db nodes
   for DBHOST in ${DBHOSTS}; do
      dispatchHostCommand "start-testdb-host" ${DBHOST} ${TESTNAME}
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 50 ]]; then
      	 startDBInstanceMonitoring ${DBHOST} ${TESTNAME}
      fi
   done
}

stopTest(){
   TESTNAME="${1}"
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   ET=$(TZ=Asia/Kolkata date)
   echo "END_TIME=${ET}" >> ${TESTINFO}
   # get OTD stats
   saveOTDStats ${TESTNAME} "stop"
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] unable to get OTD stats... exiting"
      return ${ANS}
   fi
   # do for all instances
   ALLDOMAINS=$(getAllDomains "false")
   for DOM in ${ALLDOMAINS}; do
      echo "[INFO] considering domain : ${DOM}"
      ALLINSTS=$(findAllInstancesForDomain ${DOM} "false" "I")
      for INS in ${ALLINSTS} ; do
         dispatchInstanceCommand "stop-test-ins" ${INS} ${TESTNAME}
         typeset -i ANS=${?}
         if [[ ${ANS} -eq 60 ]]; then
	    echo "[ERROR] Instance : ${INS} is not in this box and remote dispatch is disabled."
	    #return 1
	 elif [[ ${ANS} -eq 50 ]]; then
	    stopTestInstance ${INS} ${TESTNAME}
         fi
      done
   done
   # start nmon in all hosts
   ALLHOSTS=$(getAllHosts )
   for WLHOST in ${ALLHOSTS}; do
      dispatchHostCommand "stop-test-host" ${WLHOST} ${TESTNAME}
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 50 ]]; then
      	 stopTestHost ${WLHOST} ${TESTNAME}
      fi
   done
   # start monitoring in db nodes
   for DBHOST in ${DBHOSTS}; do
      dispatchHostCommand "stop-testdb-host" ${DBHOST} ${TESTNAME}
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 50 ]]; then
         stopDBInstanceMonitoring ${DBHOST} ${TESTNAME}
      fi
   done
   gatherArtefacts "${TESTNAME}"
}

doStartTest(){
   TESTNAME="${1}"
   if [[ -z ${TESTNAME} ]]; then
      echo "provide a valid test name"
      return 1
   fi
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   if [[ -e ${TESTINFO} ]]; then
      echo "[ERROR] test information exists for test name ${TESTNAME} . use another name"
      return 1
   fi
   RUNMARKER="${PERFDIR}/.nowRunning"
   if [[ -e ${RUNMARKER} ]]; then
      echo "[ERROR] test is currently running, stop this prior to starting new"
      cat ${RUNMARKER}
      return 1
   fi
   ST=$(TZ=Asia/Kolkata date)
   echo "[${ST}] ${TESTNAME}" > "${RUNMARKER}"
   startTest "${TESTNAME}"
   return ${?}
}

doStopTest(){
   TESTNAME="${1}"
   if [[ -z ${TESTNAME} ]]; then
      echo "[ERROR] provide a valid test name"
      return 1
   fi
   TESTDIR="${PERFDIR}/${TESTNAME}"
   TESTINFO="${TESTDIR}/testInfo.sh"
   if [[ ! -e ${TESTINFO} ]]; then
      echo "[ERROR] test information does not exists for test name ${TESTNAME}"
      return 1
   fi
   RUNMARKER="${PERFDIR}/.nowRunning"
   if [[ ! -e ${RUNMARKER} ]]; then
      echo "[ERROR] no tests are currently running"
      return 1
   else
      MATCHED=$(grep -o ${TESTNAME} ${RUNMARKER} )
      typeset -i ANS=${?}
      if [[ ${ANS} -ne 0 ]]; then
         echo "[ERROR] incorrect test name , current test running is"
         cat ${RUNMARKER}
         return 1
      fi
   fi
   rm ${RUNMARKER}
   # invoke stop
   stopTest ${TESTNAME}
}

#
# Main block start
#

TSTMGR_ACTION="${1}"
TSTMGR_NAME="${2}"
TSTMGR_FLAG="${3}"

echo "[main] TSTMGR_ACTION - ${TSTMGR_ACTION} , TSTMGR_NAME - ${TSTMGR_NAME} , TSTMGR_FLAG - ${TSTMGR_FLAG} "

case ${TSTMGR_ACTION} in
        'start')
                doStartTest ${TSTMGR_NAME}
                ;;
        'stop')   
                doStopTest ${TSTMGR_NAME}
                ;;
        'start-test-ins')
                startTestInstance ${TSTMGR_NAME} ${TSTMGR_FLAG}
                ;;
        'start-test-host')
                startTestHost ${TSTMGR_NAME} ${TSTMGR_FLAG}
                ;;
        'stop-test-ins')
                stopTestInstance ${TSTMGR_NAME} ${TSTMGR_FLAG}
                ;;
        'stop-test-host')
                stopTestHost ${TSTMGR_NAME} ${TSTMGR_FLAG}
                ;;
        'start-testdb-host')
                startDBInstanceMonitoring ${TSTMGR_NAME} ${TSTMGR_FLAG}
                ;;
        'stop-testdb-host')
                stopDBInstanceMonitoring ${TSTMGR_NAME} ${TSTMGR_FLAG}
                ;;       
        'status')
                echo "test status not implemented !!"
                ;;
        *)
        	printUsage
        	;;
esac



# start test
# create a directory with the test name
# put some metadata list start time 
# take the count of logs - out file, gc file, access log
# check nmon and start 
# restart otd instance wait for a 30 seconds for health check to stabilize
# capture the perf report before start

# end test 
# update the metadata with the endtime
# update it with end lines for the logs
# stop nmon 
# copy the logs for each server to a separate folder 
# capture the otd perf report
# zip it all up
