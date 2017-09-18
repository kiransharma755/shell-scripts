#!/bin/bash
#set -x

CURRDIR=`echo $0 | awk '$0 ~ /^\// { print }'`
if [[ ${CURRDIR} != "" ]]; then
  CURRDIR=`dirname $0`
else
  CURRDIR="`pwd``dirname $0 | cut -c2-`"
fi

export CURRDIR

# source the companion scripts
. ${CURRDIR}/setEnv.sh
. ${CURRDIR}/wladmin.functions.sh

export PATH="${PATH}:${CURRDIR}"

#Days to which file will be maintained
export KEEPLOG4=2
export KEEPCORE4=1
export KEEPNMON4=3
export KEEPINTF4=3
export KEEPARCH4=2

typeset -r OS=$(uname -s)

# returns the server process Id 
findInstancePid(){
   SERVER=${1}
   if [[ ${OS} == 'SunOS' ]]; then
      PID=`${WLADM_PS} | grep "[w]eblogic.Name=${SERVER}" | nawk '{ print $2 }'`
   else
      PID=`${WLADM_PS} | grep "[w]eblogic.Name=${SERVER}" | awk '{ print $2 }'`
   fi
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echoe "Unable to resolve the process id of the weblogic server ${SERVER}" >&2
      return 1
   fi
   echo ${PID}
   return 0
}

cleanDomainLogs() {
   typeset DOMAINS=$(getAllDomains 'true')
   if [[ -n ${DOMAINS} ]]; then
      for DOMAIN in ${DOMAINS} ; do
         typeset DOMAINDIR=$(getDomainDirectoryForDomain ${DOMAIN})
         typeset LOGDIR=$(getLogDir ${DOMAINDIR})
         if [[ -e ${LOGDIR} ]]; then
            find ${LOGDIR}/app -name "*.log.*" -type f -mtime +${KEEPLOG4} -exec rm -f {} \;
     	    find ${LOGDIR}/app -name "*.out.*" -type f -mtime +${KEEPLOG4} -exec rm -f {} \;
	    find ${LOGDIR}/wls -name "*.log.*" -type f -mtime +${KEEPLOG4} -exec rm -f {} \;
	    find ${LOGDIR}/wls -name "*GC*" -type f -mtime +${KEEPLOG4} -exec rm -f {} \;
	    find ${LOGDIR}/wls -name "*.hprof" -type f -mtime +${KEEPCORE4} -exec rm -f {} \;
         fi
      done
   fi
}

cleanIntfFiles() {
   typeset DOMAINS=$(getAllDomains 'true')
   if [[ -n ${DOMAINS} ]]; then
      for DOMAIN in ${DOMAINS} ; do
         typeset DOMAINDIR=$(getDomainDirectoryForDomain ${DOMAIN})
	 typeset INFRDIR=${DOMAINDIR}/user_stage/intf
	 if [[ -e ${INFRDIR} ]]; then
	    find ${INFRDIR}/ -type f -mtime +${KEEPINTF4} -exec rm {} \;
   	 fi
      done
   fi
}

# NUM=$[$NUM + 1] && echo $NUM
cleanAppArchive() {
   typeset DOMAINS=$(getAllDomains 'true')
   if [[ -n ${DOMAINS} ]]; then
      for DOMAIN in ${DOMAINS} ; do
         typeset DOMAINDIR=$(getDomainDirectoryForDomain ${DOMAIN})
         typeset ARCHDIR=${DOMAINDIR}/user_stage/archive/app
         if [[ -e ${ARCHDIR} ]]; then
            if [[ ${OS} == 'SunOS' ]]; then
               ARCDIRS=$( find ${ARCHDIR}/. \( -name . -o -prune \) -type d -mtime +${KEEPARCH4} -print | grep -v "'^${ARCHDIR}/.$'")   
            else
               ARCDIRS=$( find ${ARCHDIR}/ -maxdepth 1 -mindepth 1 -type d -mtime +${KEEPARCH4} -print )
            fi
            if [[ -e ${ARCDIRS} ]]; then
               typeset -i NUMARCS=$( echo ${ARCDIRS} | wc -w )
               for ARCDIR in ${ARCDIRS} ; do
                  [[ ${NUMARCS} -le ${KEEPARCH4} ]] && break
                  rm -r ${ARCDIR}
                  NUMARCS=$[${NUMARCS} - 1]
               done
            fi
   	fi
      done
   fi
}

rotateAllLogs(){
   typeset DOMAINS=$(getAllDomains 'true')
   if [[ -n ${DOMAINS} ]]; then
      for DOMAIN in ${DOMAINS} ; do
         INSTANCES=$(findAllInstancesForDomain ${DOMAIN} 'true')
         if [[ -n ${INSTANCES} ]]; then
            for INST in ${INSTANCES}; do
               PID=$(findInstancePid ${INST})
               typeset -i RUNNING=${?}
               if [[ ${RUNNING} -eq 0 && -n ${PID} ]]; then
                  wladmin rotate ${INST}
               fi
            done
         fi
      done
   fi
}

#rotateAllLogs
cleanDomainLogs
cleanIntfFiles
cleanAppArchive
