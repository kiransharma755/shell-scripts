#!/bin/bash
#set -x

##############################################################
#                                                            #
# Weblogic admin script function library                     #
# @Author : Jens J P                                         #
#                                                            #
##############################################################

# environment specific config file
if [[ ${USER_WLADMIN_CONF} != "" && -r ${USER_WLADMIN_CONF} ]]; then
   CONF_FILE="${USER_WLADMIN_CONF}"
   echo "Using user defined wladmin config file {CONF_FILE}"
else
   CONF_FILE="${CURRDIR}/etc/servers.conf"
fi


CONF_SERVER_COLUMN="\$1"
CONF_DOMAIN_COLUMN="\$2"
CONF_CLUSTER_COLUMN="\$3"
CONF_DOMDIR_COLUMN="\$4"
CONF_HOST_COLUMN="\$5"
CONF_PORT_COLUMN="\$6"
CONF_JMXPORT_COLUMN="\$7"
CONF_ADMIN_HOST_COLUMN="\$8"
CONF_ADMIN_PORT_COLUMN="\$9"
CONF_IS_ADMIN_COLUMN="\$10"
CONF_DOMAIN_CONTEXTPATH_COLUMN="\$11"
CONF_DOMAIN_SHORTNAME_COLUMN="\$12"
CONF_OSUSER_COLUMN="\$13"

RED_F="\033[1;31m"
BLUE_F="\033[1;34m"
YELLOW_F="\033[1;33m"
GREEN_F="\033[1;32m"
NC='\033[0m'
WHITE_F='\033[1;37m'

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


# Returns the host/ip for the instance
getInstanceHost(){
   INSTANCE="$1"
   HOST=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_HOST_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${HOST} == "" ]]; then
      echo "Unable to find the host for instance ${INSTANCE}" >&2
      return 1
   fi
   echo $HOST
   return 0
}

# Returns the rmi/http port for the instance
getInstancePort(){
   INSTANCE="$1"
   PORT=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_PORT_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${PORT} == "" ]]; then
      echo "Unable to find the rmi port for instance ${INSTANCE}" >&2
      return 1
   fi
   echo $PORT   
   return 0
}

# Returns the domain name for the instance
getInstanceDomain(){
   INSTANCE="$1"
   DOM=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_DOMAIN_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${DOM} == "" ]]; then
      echo "Unable to find the domain for instance ${INSTANCE}" >&2
      return 1
   fi
   echo $DOM   
   return 0
}

# Returns the cluster name for the instance
getInstanceCluster(){
   INSTANCE="$1"
   CLSNAM=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_CLUSTER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${CLSNAM} == "" ]]; then
      echo "Unable to find the cluster name for instance ${INSTANCE}" >&2
      return 1
   fi
   echo $CLSNAM   
   return 0
}

# returns the domain directory for the instance
getDomainDirectoryForInstance(){
   INSTANCE="$1"
   DOMDIR=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_DOMDIR_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${DOMDIR} == "" ]]; then
      echo "Unable to find the domain directory for instance ${INSTANCE}" >&2
      return 1
   fi
   if [[ -r ${DOMDIR} ]]; then
      echo $DOMDIR
      return 0
   else
      echo "Domain directory : ${DOMDIR} does not exist for the instance ${INSTANCE}" >&2
      return 1
   fi
}

# returns the admin server host for the instance
getInstanceAdminHost(){
   INSTANCE="$1"
   ADMHST=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_ADMIN_HOST_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ADMHST} == "" ]]; then
      echo "Unable to find the admin server host for instance ${INSTANCE}" >&2
      return 1
   fi
   echo ${ADMHST}
   return 0
}

# returns the admin server host for the instance
getInstanceAdminPort(){
   INSTANCE="$1"
   ADMPRT=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_ADMIN_PORT_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ADMPRT} == "" ]]; then
      echo "Unable to find the admin server port for instance ${INSTANCE}" >&2
      return 1
   fi
   echo ${ADMPRT}
   return 0
}

# Returns the OS user for the instance
getInstanceOSUser(){
   INSTANCE="$1"
   INSUSER=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_OSUSER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${INSUSER} == "" ]]; then
      echo "Unable to find the os user for instance ${INSTANCE}" >&2
      return 1
   fi
   echo $INSUSER
   return 0
}

# returns the server t3 url
getInstanceUrl(){
   INSTANCE="$1"
   PROTO="$2"
   if [[ ${PROTO} == "" ]]; then
      PROTO="t3"
   fi
   HOST=$(getInstanceHost ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "Unable to get hostname for instance ${INSTANCE}" >&2
      return 1
   fi
   PORT=$(getInstancePort ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "Unable to get rmi port for instance ${INSTANCE}" >&2
      return 1
   fi
   URL="${PROTO}://${HOST}:${PORT}"
   echo ${URL}
   return 0
}

# returns the admin server name for the instance
getAdminServerForInstance(){
   INSTANCE="$1"
   DOM=$(getInstanceDomain ${INSTANCE} )
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "Unable to retrieve domain name for instance : ${INSTANCE}" >&2
      return 1
   fi
   ADMSRV=$(awk '$0 !~ /^#/ && '${CONF_IS_ADMIN_COLUMN}' == "yes" && '${CONF_DOMAIN_COLUMN}' == '\"${DOM}\"' { print '${CONF_SERVER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ADMSRV} == "" ]]; then
      echo "Unable to resolve the admin server for the instance : ${INSTANCE} , domain : ${DOM}" >&2
      return 1
   fi
   echo ${ADMSRV}
   return 0;
}

# returns the admin server url for the instance
getAdminServerUrlForInstance(){
   INSTANCE="$1"
   ADMSRV=$(getAdminServerForInstance ${INSTANCE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "Unable to retrieve admin server name for instance : ${INSTANCE}" >&2
      return 1
   fi
   
   URL=$(getInstanceUrl ${ADMSRV})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "Unable to retrieve admin server url for server : ${ADMSRV}" >&2
      return 1
   fi
   echo ${URL}
   return 0
}

# returns the admin server url for the domain
getAdminServerUrlForDomain(){
   DOM="$1"
   ADMSRV=$(awk '$0 !~ /^#/ && '${CONF_IS_ADMIN_COLUMN}' == "yes" && '${CONF_DOMAIN_COLUMN}' == '\"${DOM}\"' { print '${CONF_SERVER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ADMSRV} == "" ]]; then
      echo "Unable to resolve the admin server for domain : {DOM}" >&2
      return 1
   fi
   
   URL=$(getInstanceUrl ${ADMSRV})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "Unable to retrieve admin server url for server : ${ADMSRV}" >&2
      return 1
   fi
   echo ${URL}
   return 0
}

# checks if the instance is an admin server
isAdminServer(){
   INSTANCE="$1"
   ISADM=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_IS_ADMIN_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "Error while checking admin server flag for instance : ${INSTANCE}" >&2
      return 1
   fi
   echo ${ISADM}
   return 0
}

# checks if the cluster name is valid
isValidCluster(){
   CLUSTER="$1"
   ISPRSNT=$(awk '$0 !~ /^#/ && '${CONF_CLUSTER_COLUMN}' == '\"${CLUSTER}\"' { print '${CONF_CLUSTER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 && -n ${ISPRSNT} ]]; then
      return 0;
   else
      return 1;
   fi
}

# checks if the domain name is valid
isValidDomain(){
   DOMAIN="$1"
   ISPRSNT=$(awk '$0 !~ /^#/ && '${CONF_DOMAIN_COLUMN}' == '\"${DOMAIN}\"' { print '${CONF_DOMAIN_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 && -n ${ISPRSNT} ]]; then
      return 0;
   else
      return 1;
   fi   
}

# checks if the instance name is valid
isValidInstance(){
   INSTANCE="$1"
   ISPRSNT=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_SERVER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -eq 0 && -n ${ISPRSNT} ]]; then
      return 0;
   else
      return 1;
   fi   
}

# checks if the name specified is instance, domain or cluster
# return 'instance' , 'domain' or 'cluster'
resolveType(){
   NAME="${1}"
}

# checks if the instance is running in this box
isInThisBox(){
   INSTANCE="$1"
   INST_HOST=$(getInstanceHost ${INSTANCE})
   typeset -i ANS=$?
   if [[ $ANS -ne 0 ]]; then
      echo "Error resolving hostname for instance : ${INSTANCE}" >&2
      return 2
   fi
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

# returns all the instances for the domain
findAllInstancesForDomain(){
   DOM="$1"
   LOCAL="$2"
   ADMORD="$3" # order of the admin server first or last
   [[ -z ${ADMORD} ]] && ADMORD="F"
   INSTS=$(awk '$0 !~ /^#/ && '${CONF_DOMAIN_COLUMN}' == '\"${DOM}\"' { print '${CONF_SERVER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${INSTS} == "" ]]; then
      echo "Unable to find the instances for domain ${DOM}" >&2
      return 1
   fi
   ADMSRV=""
   if [[ ${LOCAL} == "true" ]]; then
      LOCAL_INSTS=""
      for INST in ${INSTS} ; do
         isInThisBox ${INST}
         typeset -i ANS=$?
         if [[ ${ANS} -eq 0 ]]; then
            ISADM=$(isAdminServer ${INST})
            if [[ ${ISADM} == "yes" ]]; then
              ADMSRV="${INST}" 
            else
               LOCAL_INSTS="${LOCAL_INSTS} ${INST}"
            fi   
         fi
      done
      LOCAL_INSTS=$(echo ${LOCAL_INSTS} | tr " " "\n" | sort | tr "\n" " ")
      if [[ -n ${ADMSRV} ]]; then
         if [[ ${ADMORD} == "F" ]]; then
            LOCAL_INSTS="${ADMSRV} ${LOCAL_INSTS}"
	 elif [[ ${ADMORD} == "I" ]]; then
	    LOCAL_INSTS="${LOCAL_INSTS}"
         else
            LOCAL_INSTS="${LOCAL_INSTS} ${ADMSRV}"
         fi
      fi
      echo ${LOCAL_INSTS}
   else
      echo $INSTS
   fi
   return 0
}

# returns all instances for the cluster
findAllInstancesForCluster(){
   CLS="$1"
   LOCAL="$2"
   ADMORD="$3" # order of the admin server first or last
   [[ -z ${ADMORD} ]] && ADMORD="F"   
   
   INSTS=$(awk '$0 !~ /^#/ && '${CONF_CLUSTER_COLUMN}' == '\"${CLS}\"' { print '${CONF_SERVER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${INSTS} == "" ]]; then
      echo "Unable to find the instances for cluster ${CLS}" >&2
      return 1
   fi
   if [[ ${LOCAL} == "true" ]]; then
      LOCAL_INSTS=""
      ADMSRV=""
      for INST in ${INSTS} ; do
         isInThisBox ${INST}
         typeset -i ANS=$?
         if [[ ${ANS} -eq 0 ]]; then
            ISADM=$(isAdminServer ${INST})
            if [[ ${ISADM} == "yes" ]]; then   
               ADMSRV="${INST}"
            else
               LOCAL_INSTS="${LOCAL_INSTS} ${INST}"
            fi   
         fi
      done
      LOCAL_INSTS=$(echo ${LOCAL_INSTS} | tr " " "\n" | sort | tr "\n" " ")
      if [[ -n ${ADMSRV} ]]; then
         if [[ ${ADMORD} == "F" ]]; then
            LOCAL_INSTS="${ADMSRV} ${LOCAL_INSTS}"
	 elif [[ ${ADMORD} == "I" ]]; then
	    LOCAL_INSTS="${LOCAL_INSTS}"
         else
            LOCAL_INSTS="${LOCAL_INSTS} ${ADMSRV}"
         fi
      fi  
      echo ${LOCAL_INSTS}
   else
      echo $INSTS
   fi
   return 0
}

# get all domains configured
getAllDomains(){
   LOCAL="$1"
   ALLDOMAINS=$(awk '$0 !~ /^#/ { print '${CONF_DOMAIN_COLUMN}' }' ${CONF_FILE} | sort | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ALLDOMAINS} == "" ]]; then
      echo "Unable to retrieve all domains." >&2
      return 1
   fi
   #findAllInstancesForDomain
   if [[ ${LOCAL} == "false" ]]; then
      echo ${ALLDOMAINS}
   else
      for DOM in ${ALLDOMAINS} ; do
         INSTS=$(findAllInstancesForDomain "${DOM}" "true" "F") 2>/dev/null
         typeset -i ANS=${?}
         if [[ ${ANS} -eq 0 && ! -z ${INSTS} ]]; then
            if [[ -z ${LOCALDOMAINS} ]]; then
               LOCALDOMAINS="${DOM}"
            else
               LOCALDOMAINS="${LOCALDOMAINS} ${DOM}"
            fi
         fi
      done
      echo ${LOCALDOMAINS}
   fi
   return 0
}

# gets the user config key file arg line
getUserKeyArgsForInstance(){
  INSTANCE="$1"
  DOM=$(getDomainDirectoryForInstance ${INSTANCE})
  USER_CFG="${DOM}/.user.cfg"
  if [[ ! -r ${USER_CFG} ]]; then
     echo "User config file does not exist for domain {DOM} , userConfigFile : ${USER_CFG}" >&2
     return 1
  fi
  KEY_CFG="${DOM}/.user.key"
  if [[ ! -r ${KEY_CFG} ]]; then
     echo "User key file does not exist for domain {DOM} , userKeyFile : ${KEY_CFG}" >&2
     return 1
  fi
  echo "-userconfigfile ${USER_CFG} -userkeyfile ${KEY_CFG}"
  return 0
}

# returns the domain directory for the instance
getDomainDirectoryForDomain(){
   DOMAIN="$1"
   DOMDIR=$(awk '$0 !~ /^#/ && '${CONF_DOMAIN_COLUMN}' == '\"${DOMAIN}\"' { print '${CONF_DOMDIR_COLUMN}' }' ${CONF_FILE} | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${DOMDIR} == "" ]]; then
      echo "Unable to find the domain directory for instance ${DOMAIN}" >&2
      return 1
   fi
   if [[ -r ${DOMDIR} ]]; then
      echo $DOMDIR
      return 0
   else
      echo "Domain directory : ${DOMDIR} does not exist for the instance ${DOMAIN}" >&2
      return 1
   fi
}

# returns the domain directory for the instance
getDomainContextPath(){
   DOMAIN="$1"
   CONTEXTPATH=$(awk '$0 !~ /^#/ && '${CONF_DOMAIN_COLUMN}' == '\"${DOMAIN}\"' { print '${CONF_DOMAIN_CONTEXTPATH_COLUMN}' }' ${CONF_FILE} | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${CONTEXTPATH} == "" ]]; then
      echo "Unable to find the contextpath for domain ${DOMAIN}" >&2
      return 1
   fi
   echo ${CONTEXTPATH}
}

# returns the shortName for the domain
getDomainShortName(){
   DOMAIN="$1"
   SHORTNAME=$(awk '$0 !~ /^#/ && '${CONF_DOMAIN_COLUMN}' == '\"${DOMAIN}\"' { print '${CONF_DOMAIN_SHORTNAME_COLUMN}' }' ${CONF_FILE} | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${SHORTNAME} == "" ]]; then
      echo "Unable to find the shortname for domain ${DOMAIN}" >&2
      return 1
   fi
   echo ${SHORTNAME}
}

# returns the shortName for the instance
getDomainContextNameForInstance(){
   INSTANCE="$1"
   CONTEXTPATH=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_DOMAIN_CONTEXTPATH_COLUMN}' }' ${CONF_FILE} | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${CONTEXTPATH} == "" ]]; then
      echo "Unable to find the shortname for domain ${INSTANCE}" >&2
      return 1
   fi
   echo ${CONTEXTPATH}
}

# returns the shortName for the instance
getDomainShortNameForInstance(){
   INSTANCE="$1"
   SHORTNAME=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_DOMAIN_SHORTNAME_COLUMN}' }' ${CONF_FILE} | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${SHORTNAME} == "" ]]; then
      echo "Unable to find the shortname for domain ${INSTANCE}" >&2
      return 1
   fi
   echo ${SHORTNAME}
}

# returns the shortName for the instance
isInstanceName(){
   INSTANCE="$1"
   NAME=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_SERVER_COLUMN}' }' ${CONF_FILE} | uniq)
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${NAME} == "" ]]; then      
      return 1
   else
      return 0
   fi
   
}

# returns the domain directory for the instance
getJMXPort(){
   INSTANCE="$1"
   JMXPORT=$(awk '$0 !~ /^#/ && '${CONF_SERVER_COLUMN}' == '\"${INSTANCE}\"' { print '${CONF_JMXPORT_COLUMN}' }' ${CONF_FILE} )
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${JMXPORT} == "" ]]; then
      echo "Unable to find the JMX port for instance ${INSTANCE}" >&2
      return 1
   fi
   echo ${JMXPORT}
}

# check if remote dispatch of commands is enabled for the instance
isRemoteDispatchEnabled(){
   INSTANCE="$1"
   REMOSUSER=$(getInstanceOSUser ${INSTANCE})
   typeset -i ANS=${?}
   if [[ ${ANS} -eq 0 && ${ENABLE_REMOTE_DISPATCH} == "true" && ${REMOSUSER} != "-" ]]; then
      return 0
   else
      return 1
   fi
}

# return the base log directory for a domain
getLogDir(){
   DOMAINDIR="$1"
   INSTANCE="$2"
   echo "${DOMAINDIR}/user_stage/logs"
}
