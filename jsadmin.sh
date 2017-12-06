#!/bin/bash
#########################################################################
#                                                                       #
# jsadmin Created on Jan, 2015                                           #
#                                                                       #
#########################################################################

#########################################################################
# Script for aiding deployment/monitoring/management of the Jigsaw      #
# application                                                           #
#                                                                       #
#                                                                       #
# @ Author : Binu Kurian (IBS Software Services (P) Ltd)                #
# @ Author : Sony Abraham (IBS Software Services (P) Ltd)               #
#########################################################################
#set -x

alias echo='echo -e'

DIRCMD=`echo $0 | awk '$0 ~ /^\// { print }'`
if [[ ${DIRCMD} != "" ]]; then
  DIRCMD=`dirname $0`
else
  DIRCMD="`pwd``dirname $0 | cut -c2-`"
fi
export CURRDIR=${DIRCMD}
export COMMON_CONFIG_DIR="${DIRCMD}/store"

. ${DIRCMD}/libs/setEnv.sh
. ${DIRCMD}/libs/wladmin.functions.sh
. ${DIRCMD}/libs/icoadmin.functions.sh

prt_usage() {
   echo "" >&2
   echo "${BLUE_B}${YELLOW_F}${BOLD}USAGE:${NORM}" >&2
   echo " for Detailed help          : ${BOLD}${GREEN_F}jsadmin help${NORM}" >&2
   echo "" >&2
   echo " for Deployment         : ${BOLD}jsadmin deploy <server name> <version>${NORM}" >&2
   echo "" >&2
   echo " for Restore (previous version)  : ${BOLD}jsadmin restore <server name>${NORM}" >&2
   echo "" >&2
   echo " for Restore Version (specific)  : ${BOLD}jsadmin restore <server name> <version>${NORM}" >&2
   echo "" >&2
   echo " for querying Jigsaw  version    : ${BOLD}jsadmin version <server name>${NORM}" >&2
   echo "" >&2
   echo " for querying deployment history : ${BOLD}jsadmin history <server name>${NORM}" >&2
   echo "" >&2
   echo " The jigsaw.war should be placed in <domain>/user_stage/landing/app" >&2
   echo "" >&2
   echo "" >&2
   echo "${BOLD}The <server name> can be any of the following. ${NORM}" >&2
   echo "${BOLD}$(cat ${CONF_FILE} | grep -v '#' |awk '{ print $1 ,"\t" ,$2 ,"\t", $5 }' | grep `hostname`)${NORM}">&2
   echo "" >&2
}


deploy() {
   typeset TYPE=${1}
   doDeploy ${TYPE}
   if [[ $? -eq 0 ]]; then
      echo "${BOLD}${GREEN_F}********************************************************"
      echo "*                                                      *"
      echo "* Version ${VERSION} deployed succesfully!.            *"
      echo "*                                                      *"
      echo "********************************************************${NORM}"
      recordJigsawDeployment ${DOMAIN_NAME} ${VERSION} ${TYPE}
      return 0
   else
      echo "${BOLD}${RED_F}XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      echo "X                                                  X"
      echo "X FAILED deploying version ${VERSION}.             X"
      echo "X                                                  X"
      echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX${NORM}"
      return 1
   fi
}

doDeploy() {

   typeset TYPE=${1}
   typeset -i EXTEXISTS=0   
   echo "Deploying Jigsaw version ${VERSION}(${TYPE})"

   #Move app from landing to live
   moveJigsawApp ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echo "Could not move app to live"  >&2
      return 1
   fi

   #Record present version
   removeJigsawVersionId ${DOMAIN_NAME}
   recordJigsawVersionId ${DOMAIN_NAME} ${VERSION}
   if [[ $? -ne 0 ]]; then
      echo "Could not record current version id" >&2
      return 1
   fi      
   
   #Archive previous app
   archivePreviousJigsawApp ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echo "Could not Archive Previous version of App" >&2
      return 1
   fi
   
   cleanJigsawApp ${DOMAIN_NAME} ${TYPE}
   if [[ $? -ne 0 ]]; then
      echo "Could not clean  App location" >&2
      return 1
   fi

   #Explode
   explodeJigsawWar ${DOMAIN_NAME} 
   if [[ $? -ne 0 ]]; then
      echo "Could not Explode Jigsaw war" >&2
      return 1
   fi
   
   #Replace Config from maintained config
   writeOutJigsawConfig ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echo "No maintained jigsaw folder found." >&2
      #return 1
   fi
        
   #Move current ear and config zip to archive
   archiveCurrentJigsawApp ${DOMAIN_NAME}
   #Raise error if not patch release
   if [[ ${TYPE} != ${PATCH_REL_TYPE} ]]; then
      if [[ $? -ne 0 ]]; then
         echo "Could not Archive Current jigsaw  version of App" >&2
         return 1
      fi
   fi
}

restoreVersion() {
   typeset PRVVRSN=${1}
   echo "Restoring Version ${PRVVRSN}" >&2
   echo "">&2 
   echo "">&2 
   echo "#### WARNING!!    WARNING!!      WARNING!!        ######" >&2
   echo "<Warning> Application EAR in Landing will be over-written <Warning>" >&2
   echo "<Warning> Application Config ZIP in Landing will be over-written <Warning>" >&2
   echo "">&2
   echo "">&2
   
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN_NAME})
   typeset SRC=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}/jigsaw.war
   typeset DST=${MYDOMDIR}/${LANDING} 
   
   restoreToLanding ${SRC} ${DST}
   if [[ $? -ne 0 ]]; then
      echo "Could not Restore Version ${PRVVRSN} of App to Landing"  >&2
      return 1
   fi
  
   echo "Deploying app...."
   deploy "FULL"
   return $?
}

CMD=${1}
DOMAIN_NAME=${2}
VERSION=${3}
OPTION=${4}

if [[ ${CMD} == "" ]]; then
   echo "${RED_F}A command has to be specified !!${NORM}"
   prt_usage
   exit 1
fi

#Not checks for help !
if [[ ${CMD} != "help" ]]; then
   if [[ ${DOMAIN_NAME} == "" ]]; then
      echo "A domain name has to be specified !!"
      prt_usage
      exit 1
   fi

   if [[ ${CMD} != "elog" && ${CMD} != "dlog" ]]; then
      isDomainInThisBox ${DOMAIN_NAME}
      if [[ $? -ne 0 ]]; then
         echo "" >&2
         echo "Instance ${DOMAIN_NAME} is not a weblogic instance in this partition. Maybe on the other one! " >&2
         echo "" >&2
         echo "My instances follow" >&2
         echo "$(cat ${CONF_FILE} | grep -v '#' |awk '{ print $1 ,"\t" ,$2 ,"\t", $5 }' | grep `hostname`)"
         exit 1
      fi
   fi
fi

if [[ ${CMD} = "deploy" || ${CMD} = "restoreVersion" || ${CMD} = "patch" || ${CMD} = "restorePatch" ]]; then
   if [[ ${VERSION} == "" ]]; then
      echo "A version for the application has to be specified !!"
      prt_usage
      exit 1
   fi
fi


case $CMD in
   deploy)
           deploy "FULL"
           exit $?
           ;;
   restore)
            typeset VERSION=$(retrievePreviousJigsawVersionId ${DOMAIN_NAME})
            restoreVersion ${VERSION}
            exit $?
            ;;
   restoreVersion)
            restoreVersion ${VERSION}
            exit $?
            ;;        
   version)
            typeset VERSION=$(retrieveCurrentJigsawVersionId ${DOMAIN_NAME})
            typeset PRVVERSION=$(retrievePreviousJigsawVersionId ${DOMAIN_NAME})
            if [[ ${PRVVERSION} == "" ]]; then
               PRVVERSION="unknown"
            fi
            echo "Version of Jigsaw in domain ${DOMAIN_NAME} is ${VERSION}"
            echo "Previous Version was ${PRVVERSION}"
            exit 1
            ;;        
   history)
            viewJigsawDeploymentHistory ${DOMAIN_NAME}
            exit 1
            ;;        
      help)
            showDetailedHelp
            exit 0
            ;;
   *)
           prt_usage
           exit 1
           ;;
esac

