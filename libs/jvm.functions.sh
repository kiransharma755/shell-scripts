#!/bin/bash
##############################################################
#                                                            #
# Java VM management script library                          #
# @Author : Jens J P                                         #
#                                                            #
##############################################################

#
# Configurations could be overriden externally
#

# repeat jstat headers after 10 rows
JSTAT_SHOWHEADER_AFTER="${JSTAT_SHOWHEADER_AFTER:-10}"
# refresh frequency
JSTAT_FREQ="${JSTAT_FREQ:-3s}"
# dump default write location for thread dump, heap dump, perf stats etc
DUMP_LOCATION_DEFAULT="${DUMP_LOCATION_DEFAULT:-/tmp}"


JCURRDIR=`echo $0 | awk '$0 ~ /^\// { print }'`
if [[ ${JCURRDIR} != "" ]]; then
  JCURRDIR=`dirname $0`
else
  JCURRDIR="`pwd``dirname $0 | cut -c2-`"
fi

# source our fellow companions
. ${JCURRDIR}/libs/jvm.functions.help.sh

jechoi(){
  ARGS="${*}"
  if [[ $(type -t echoi) ]]; then
     echoi ${ARGS}
  else
     echo "[INFO] : ${ARGS}"
  fi
}

jechow(){
  ARGS="${*}"
  if [[ $(type -t echow) ]]; then
     echow ${ARGS}
  else
     echo "[WARN] : ${ARGS}"
  fi
}

jechoe(){
  ARGS="${*}"
  if [[ $(type -t echoe) ]]; then
     echoe ${ARGS}
  else
     echo "[ERROR] : ${ARGS}"
  fi
}

showJvmCommandUsage(){
   cat << EOF_USG
   JVM Management :  $(basename ${0}) ( td | tdd | hd | histo | gc | perf | jcmd | jstat ) [ flags ]
    td         - generates the thread dump and writes to System.out stream
    tdd        - generates the thread dump and displays it to console [ filePath ]
    hd         - generates the heap dump [ dumpPath ]
    histo      - generates the heap histogramm [ histoPath ]
    gc         - triggers a full GC on the jvm
    gctail     - displays the current garbage collection statistics
    perf       - dispalys the jvm performance counters
    jcmd       - executes remote commands on the jvm @see help
    jstat      - displays the jvm runtime statistics @see help
   
EOF_USG
}

# checks if the process is running
checkPid(){
   PID="$1"
   if [[ -n ${PID} ]]; then
      kill -0 ${PID} >/dev/null 2>&1
      typeset -i RUNNING=${?}
      if [[ ${RUNNING} -ne 0 ]]; then
         jechoe "PID does not map to an active process : ${PID}"
      fi
      return ${RUNNING}
   else
      jechoe "Provide a valid PID"
      return 1
   fi
}

# resolved the file name for writing stats
resolveFilePath(){
   FILEPATH="${1}"
   FILENAM="$2"
   if [[ ! -w ${FILEPATH} ]]; then
      touch ${TDPATH} >/dev/null 2>&1
      typeset -i CREATED=${?}
      if [[ ${CREATED} -ne 0 ]]; then
         echo "${DUMP_LOCATION_DEFAULT}/${FILENAM}"
         return 0
      else
         echo ${FILEPATH}
         return 0
      fi
   else
      echo "${FILEPATH}/${FILENAM}"
   fi  
}

# Invokes the jcmd operation on the jvm instance
commandInvokeJvm(){
   PID="$1"
   ACTNAME="$2"
   OUTFILE="$3"
   MAINCLS="$4"
   if [[ ! -x ${JAVA_HOME}/bin/jcmd ]]; then
      jechoe "JVM does not support remote command execution , JAVA_HOME : ${JAVA_HOME}";
      return 1
   fi
   if [[ -z ${MAINCLS} ]]; then
      jechoe "A command has to be specified."
      MAINCLS='help'
      OUTFILE='stdout'
   fi
   jechoi "Invoking ${ACTNAME} for PID ${PID}"
   if [[ ${OUTFILE} == 'stdout' ]]; then
      ${JAVA_HOME}/bin/jcmd ${PID} ${MAINCLS}
   else
      ${JAVA_HOME}/bin/jcmd ${PID} ${MAINCLS} >${OUTFILE} 2>&1
   fi
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      jechoi "${ACTNAME} operation invoked sucessfully."
      jechoi "Output written to : ${OUTFILE}"
      return 0
   else
      jechoe "Error occured while invoking ${ACTNAME}, errorCode : ${ANS}"
      jechoe "Output written to : ${OUTFILE}"
      return 11
   fi
}

executeJStatJvm(){
   PID="$1"
   OPTION="$2"
   if [[ ! -x ${JAVA_HOME}/bin/jstat ]]; then
      jechoe "JVM does not support jstat , JAVA_HOME : ${JAVA_HOME}";
      return 1
   fi
   if [[ -z ${OPTION} ]]; then
      jechoe "An option has to be specified."
      OPTION='help'
   fi
   echo ${OPTION} | grep -q '^help'
   typeset -i ISHELP=${?}
   if [[ ${ISHELP} -eq 0 ]]; then
      showJStatOptionHelp ${OPTION}
      return 0
   fi
   JSTATCMD="${JAVA_HOME}/bin/jstat -${OPTION} -t"
   [[ -n ${JSTAT_SHOWHEADER_AFTER} ]] && JSTATCMD="${JSTATCMD} -h${JSTAT_SHOWHEADER_AFTER}"
   JSTATCMD="${JSTATCMD} ${PID} ${JSTAT_FREQ}"
   jechoi "Executing command : ${JSTATCMD}"
   eval ${JSTATCMD}
   return ${?}
}


# writes the thread dump to a file/console
writeJvmTd(){
   PID="$1"
   TDPATH="${2}"
   if ! checkPid ${PID}; then
      return 1
   fi
   if [[ -z ${TDPATH} ]]; then
      TDFILE='stdout'
   else
      TDNAME="threadDump_${PID}_$(date '+%Y%m%d_%H%M%S').td"
      TDFILE=$(resolveFilePath ${TDPATH} ${TDNAME})
   fi
   commandInvokeJvm ${PID} 'ThreadDump' "${TDFILE}" 'Thread.print'
   return $?
}

# writes the thread dump to a file/console
createJvmTd(){
   PID="$1"
   if ! checkPid ${PID}; then
      return 1
   fi
   kill -3 ${PID}
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 ]]; then
      jechoi "Thread dump generated successfully for PID : ${PID}"
   else
      jechoe "Error generating thread dump for PID : ${PID}"
   fi
   return ${ANS}
}

# creates the heapdump for the instance
createJvmHd(){
   PID="$1"
   HDPATH="${2}"
   if ! checkPid ${PID}; then
      return 1
   fi
   [[ -z ${HDPATH} ]] && HDPATH="${DUMP_LOCATION_DEFAULT}"
   HDNAME="heapDump_${PID}_$(date '+%Y%m%d_%H%M%S').hprof"
   HDFILE=$(resolveFilePath ${HDPATH} ${HDNAME})
   
   jechoi "Generating heapdump PID ${PID}, location ${HDFILE} ..."
   ${JAVA_HOME}/bin/jmap -dump:format=b,file=${HDFILE} ${PID}
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      jechoi "Heap dump for PID ${PID} written to location ${HDFILE}"
      return 0
   else
      jechoe "Error generating heap dump for PID ${PID}"
      return 1
   fi
}

# creates the heap histo stats for the instance
createJvmHisto(){
   PID="$1"
   HSPATH="${2}"
   if ! checkPid ${PID}; then
      return 1
   fi
   [[ -z ${HSPATH} ]] && HSPATH="${DUMP_LOCATION_DEFAULT}"
   HSNAME="heapHisto_${PID}_$(date '+%Y%m%d_%H%M%S').log"
   HSFILE=$(resolveFilePath ${HSPATH} ${HSNAME})
   
   jechoi "Generating heaphisto PID ${PID}, location ${HSFILE} ..."
   ${JAVA_HOME}/bin/jmap -histo:live ${PID} >${HSFILE}
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 ]]; then
      jechoi "Heap histogram for PID ${PID} written to location ${HSFILE}"
      return 0
   else
      jechoe "Error generating heap histogram for PID ${PID}"
      return 1
   fi
}

# invokes a full GC on the jvm
performJvmGC(){
   PID="$1"
   if ! checkPid ${PID}; then
      return 1
   fi   
   commandInvokeJvm ${PID} 'GC' 'stdout' 'GC.run'
   return ${?}
}

createJvmPerfCounterDump(){
   PID="$1"
   PCPATH="${2}"
   if ! checkPid ${PID}; then
      return 1
   fi
   if [[ -z ${PCPATH} ]]; then
      PCFILE="stdout"
   else
      PCNAME="perfStats_${PID}_$(date '+%Y%m%d_%H%M%S').log"
      PCFILE=$(resolveFilePath ${PCPATH} ${PCNAME})
   fi   
   commandInvokeJvm ${PID} 'JVMPerfListing' "${PCFILE}" 'PerfCounter.print'
   return ${?}
}

# checks if the command is handled by this library
isJvmCommand(){
   JCMD="$1"
   case ${JCMD} in   
   'td'|'tdd'|'hd'|'histo'|'jcmd'|'jstat'|'perf'|'gc'|'gcutil'|'gctail')
          typeset -i ANS=0
          ;;
        *)
          typeset -i ANS=1
          ;;
   esac
   return ${ANS}
}

executeJvmCommand(){
   JCMD_ACTION="$1"
   JCMD_PID="$2"
   JCMD_FLAG="$3"
   
   case ${JCMD_ACTION} in
      'td')
          createJvmTd ${JCMD_PID}
          ;;
     'tdd')
          writeJvmTd ${JCMD_PID} ${JCMD_FLAG}
          ;;
      'hd')
          createJvmHd ${JCMD_PID} ${JCMD_FLAG}
          ;;
   'histo')
          createJvmHisto ${JCMD_PID} ${JCMD_FLAG}
          ;;
    'jcmd')
          commandInvokeJvm ${JCMD_PID} ${JCMD_FLAG} "stdout" ${JCMD_FLAG}
          ;;
   'jstat')
          executeJStatJvm ${JCMD_PID} ${JCMD_FLAG}
          ;;
	'gctail' | 'gcutil')
	      executeJStatJvm ${JCMD_PID} 'gcutil'
		  ;;
    'perf')
          createJvmPerfCounterDump ${JCMD_PID} ${JCMD_FLAG}
          ;;
      'gc')
          performJvmGC ${JCMD_PID}
          ;;
        *)
          showJvmCommandUsage
          ;;
   esac
}
