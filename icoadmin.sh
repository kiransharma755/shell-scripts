#!/bin/bash
#########################################################################
#                                                                       #
# icoadmin Created on Feb, 2009                                         #
#                                                                       #
#########################################################################

#########################################################################
# Script for aiding deployment/monitoring/management of the iCargo      #
# application                                                           #
#                                                                       #
#                                                                       #
# @ Author : Binu Kurian (IBS Software Services (P) Ltd)                #
# @ Author : Jens J P    (IBS Software Services (P) Ltd)                #
#########################################################################
#set -x

#
# initialization blocks
#

DIRCMD=`echo $0 | awk '$0 ~ /^\// { print }'`
if [[ ${DIRCMD} != "" ]]; then
  DIRCMD=`dirname $0`
else
  DIRCMD="`pwd``dirname $0 | cut -c2-`"
fi

export CURRDIR=${DIRCMD}
COMMON_CONFIG_DIR="${DIRCMD}/store"

# import the library scripts
. ${DIRCMD}/libs/setEnv.sh
. ${DIRCMD}/libs/wladmin.functions.sh
. ${DIRCMD}/libs/icoadmin.functions.sh


prt_usage() {
   echo "" >&2
   echo "USAGE:" >&2
   echo " for Detailed help          : icoadmin help" >&2
   echo "" >&2
   echo " for Deployment         : icoadmin deploy <server name> <version>" >&2
   echo "" >&2
   echo " for Restore (previous version)  : icoadmin restore <server name>" >&2
   echo "" >&2
   echo " for Restore Patch               : icoadmin restorePatch <server name> <version>" >&2
   echo "" >&2
   echo " for Patch apply        : icoadmin patch <server name>" >&2
   echo "" >&2
   echo " for Restore Version (specific)  : icoadmin restore <server name> <version>" >&2
   echo "" >&2
   echo " for doing JSPC                  : icoadmin jspc <server name>" >&2
   echo "" >&2
   echo " for querying iCargo  version    : icoadmin version <server name>" >&2
   echo "" >&2
   echo " for querying deployment history : icoadmin history <server name>" >&2
   echo "" >&2
   echo " for enabling all logs on an instance : icoadmin elog <server name>" >&2
   echo "" >&2
   echo " for disabling all logs on an instance : icoadmin dlog <server name>" >&2
   echo "" >&2
   echo " The ear and iCargoConfig.zip should be placed in <domain>/user_stage/landing/app" >&2
   echo "" >&2
   echo " For patches the patch artefacts bundled as an EAR should be placed in  <domain>/user_stage/landing/app" >&2
   echo "" >&2
   echo "The <server name> can be any of the following. " >&2
   echo "$(cat ${CONF_FILE} | grep -v '#' |awk '{ print $1 ,"\t" ,$2 ,"\t", $5 }' | grep `hostname`)">&2
   echo "" >&2
}

#
# function to deploy icargo 
# @arg 1 : type of deployment FULL | PATCH
#
deploy() {
   typeset TYPE=${1}
   
   doDeploy ${TYPE}
   if [[ $? -eq 0 ]]; then
      echoi "********************************************************"
      echoi "*                                                      *"
      echoi "* Version ${VERSION} deployed succesfully!.            *"
      echoi "*                                                      *"
      echoi "********************************************************"
      
      recordDeployment ${DOMAIN_NAME} ${VERSION} ${TYPE}
      return 0
   else
      echoe "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      echoe "X                                                      X"
      echoe "X FAILED deploying version ${VERSION}.                 X"
      echoe "X                                                      X"
      echoe "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      return 1
   fi
}

#
# function to deploy patch builds
# @arg 1 : domain name
#
applyPatch(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset SRCDIR="${MYDOMDIR}/${LANDING}"
   typeset TRGDIR="${MYDOMDIR}/${LIVE}"
   typeset ARCHDIR="${MYDOMDIR}/${ARCHIVE}"
   typeset EARFOUND="no"
   typeset CFGFOUND="no"

   echoi "Applying Patches for domain ${DOMAIN}"

   for file in $(find ${SRCDIR} \( -name icargo.ear -o -name iCargoConfig.zip \) ); do
      if [[ ! -w ${file} ]]; then
         echoe "$file is not writeable ... exiting"
         return 1
      fi
      BASEFILE=$(basename ${file})
      if [[ ${BASEFILE} == "icargo.ear" ]]; then
         EARFOUND="yes"
      fi
      if [[ ${BASEFILE} == "iCargoConfig.zip" ]]; then
         CFGFOUND="yes"
      fi
   
   done
   if [[ ${EARFOUND} = "yes" || ${CFGFOUND} = "yes" ]]; then
   #Proceed
      deploy "PATCH"
      return $?
   else
      echoe "No icargo.ear or iCargoConfig.zip found to patch "
      echoe "Only these artefacts are supported to patch"
      return 1
   fi
}


#
# internal function to perform deployment for a type FULL | PATCH
#
doDeploy() {
   typeset TYPE=${1}
   typeset -i EXTEXISTS=0
   
   echoi "Deploying iCargo version ${VERSION}(${TYPE})"

   #Move app from landing to live
   moveApp ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echoe "Could not move app to live"  >&2
      return 1
   fi
   
   moveConfig ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      #Return with error only if this is a full deployment
      if [[ ${TYPE} != ${PATCH_REL_TYPE} ]]; then
         echoe "Could not move config zip to live" >&2
         return 1
      fi
   fi

   #Record present version
   removeVersionId ${DOMAIN_NAME}
   recordVersionId ${DOMAIN_NAME} ${VERSION}
   if [[ $? -ne 0 ]]; then
      echoe "Could not record current version id" >&2
      return 1
   fi
   
   #Record Previously Patch or Full 
   archivePreviousReleaseType ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echoe "Could not Archive Previous release type" >&2
      #return 1
   fi   
   
   #Patch or Full 
   recordReleaseType ${DOMAIN_NAME} ${TYPE}
   if [[ $? -ne 0 ]]; then
      echoe "Could not record release type" >&2
      return 1
   fi      
   
   #Archive previous app
   archivePreviousApp ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echoe "Could not Archive Previous version of App" >&2
      return 1
   fi
   archivePreviousConfig ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echoe "Could not Archive Previous version of App Config" >&2
      return 1
   fi
 
   cleanApp ${DOMAIN_NAME} ${TYPE}
   if [[ $? -ne 0 ]]; then
      echoe "Could not clean  App location" >&2
      return 1
   fi

   cleanConfig ${DOMAIN_NAME} ${TYPE}
   if [[ $? -ne 0 ]]; then
      echoe "Could not clean  Config location" >&2
      return 1
   fi
   
   #Explode KABOOM !!!
   explodeEar ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echoe "Could not Explode EAR" >&2
      return 1
   fi
   
   explodeWar ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      #Return  only if not a patch release
      if [[ ${TYPE} != ${PATCH_REL_TYPE} ]]; then
         echoe "Could not Explode WAR" >&2
         return 1
      fi
   fi

   explodeConfig ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      #Return  only if not a patch release
      if [[ ${TYPE} != ${PATCH_REL_TYPE} ]]; then
         echoe "Could not Explode Config ZIP" >&2
         return 1
      fi
   fi
   
   #Change context path and web-app
   #Change only if not a patch release
   if [[ ${TYPE} != ${PATCH_REL_TYPE} ]]; then
      changeWebAppAndContext ${DOMAIN_NAME}
      if [[ $? -ne 0 ]]; then
         echoe "Could not Change web-app and context in application.xml" >&2
         return 1
      fi
   fi

   #Replace Config from maintained config
   writeOutConfig ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echow "No maintained iCargoConfig folder found." >&2
   fi
        
   #Replace Config from maintained host specific config
   writeOutHostConfig ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
       echow "No host specific config folder present." >&2
   fi

   #Replace Ear files from maintained application
   writeOutEar ${DOMAIN_NAME}
   if [[ $? -ne 0 ]]; then
      echow "Could not replace ear files with stored outer-level defaults" >&2
   fi

   #Move current ear and config zip to archive
   archiveCurrentApp ${DOMAIN_NAME}
   #Raise error if not patch release
   if [[ ${TYPE} != ${PATCH_REL_TYPE} ]]; then
      if [[ $? -ne 0 ]]; then
         echoe "Could not Archive Current version of App" >&2
         return 1
      fi
   fi
   
   archiveCurrentConfig ${DOMAIN_NAME}
   #Raise error if not patch release
   if [[ ${TYPE} != ${PATCH_REL_TYPE} ]]; then
      if [[ $? -ne 0 ]]; then
         echoe "Could not Archive Current version of App Config ZIP" >&2
         return 1
      fi
   fi

   #Clean Temp Location
   cleanTemp ${DOMAIN_NAME}

   if [[ $? -ne 0 ]]; then
      echow "Could not Clean Temp Location for all instances" >&2
      echow "Please delete the tmp/_WL_user location of each server instance manually.">&2
      return 0
   fi

   if [[ ${OPTION} != "nojspc" || ${OPTION} != "NOJSPC" ]]; then
      doJSPC ${DOMAIN_NAME}
      if [[ $? -ne 0 ]]; then
         echow "Could not do JSPC" >&2
         return 0
      fi
   else
      echoi "Not doing JSPC "
   fi
   
}

#
# function to restore a version from archive
#
restoreVersion() {
   typeset PRVVRSN=${1}
   echoi "Restoring Version ${PRVVRSN}"
   echow "<Warning> Application EAR in Landing will be over-written <Warning>"
   echow "<Warning> Application Config ZIP in Landing will be over-written <Warning>"
   
   typeset RELTYPE=$(retrieveReleaseType4Version ${DOMAIN_NAME} ${PRVVRSN})
   if [[ $? -ne 0 ]]; then      
      return $?
   fi
   
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN_NAME})
   typeset SRC=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}/icargo.ear
   typeset DST=${MYDOMDIR}/${LANDING}

   restoreToLanding ${SRC} ${DST}
   if [[ $? -ne 0 ]]; then
      echoe "Could not Restore Version ${PRVVRSN} of App to Landing"  >&2
      return 1
   fi

   typeset SRC=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}/iCargoConfig.zip
   typeset DST=${MYDOMDIR}/${LANDING}

   restoreToLanding ${SRC} ${DST}
   if [[ $? -ne 0 ]]; then
      echoe "Could not Restore Version ${PRVVRSN} of CargoConfig ZIP to Landing"  >&2
      return 1
   fi

   echoi "Deploying app...."
   deploy "FULL"
   return $?
}

#
# function to freeze the application
# the strategy is to fail the LB health check
#
freeze(){
   typeset DOMAIN=${1}
   LOCAL_INS="true"
   ADMORD="I" 
   isInstanceName ${DOMAIN}
   typeset -i ANS=$?
   
   if [[ ${ANS} -ne 1 ]]; then      
      DOM_SHORT_NAME=$(getDomainShortNameForInstance ${DOMAIN})
      INST=${DOMAIN}
      URL=$(getInstanceUrl ${INST} "http")
      URL="${URL}/iCargoHealthCheck/HealthCheck"
      if [[ "${DOM_SHORT_NAME}" != "-" ]]; then
         URL="${URL}_${DOM_SHORT_NAME}"
      fi
      doFreeze ${INST} ${URL}      
      typeset -i ANS=$?      
      return $ANS
   else        
      INSTS=$(findAllInstancesForDomain ${DOMAIN} ${LOCAL_INS} ${ADMORD})
      if [[ -n ${INSTS} ]]; then
         DOM_SHORT_NAME=$(getDomainShortName ${DOMAIN})
         for INST in ${INSTS} ; do
            URL=$(getInstanceUrl ${INST} "http")
            URL="${URL}/iCargoHealthCheck/HealthCheck"
               if [[ ! -z ${DOM_SHORT_NAME} && "${DOM_SHORT_NAME}" != "-" ]]; then
                  URL="${URL}_${DOM_SHORT_NAME}"
               fi
            doFreeze ${INSTS} ${URL}   
            typeset -i ANS=$?                  
         done   
      return $ANS       
      else
         echoe "No instances for the domain OR instance name ${NAME} in this box"
         return 1
      fi
   fi
}

doFreeze(){
   typeset INST=${1}
   typeset URL=${2}
   wget -O /dev/null -o /dev/null --post-data="action=deactivate&password=icargo123" "${URL}"
   if [[ $? -ne 0 ]]; then
      echoe "Deactivating ${INST} failed" >&2
   else
      echoi "${INST} is now inactive" >&2
    fi
   return 0
}

#
# function to thaw the application
# the strategy is to enable LB health check
#
thaw(){
   typeset DOMAIN=${1}
   LOCAL_INS="true"
   ADMORD="I" 
   isInstanceName ${DOMAIN}
   typeset -i ANS=$?

   if [[ ${ANS} -ne 1 ]]; then      
      DOM_SHORT_NAME=$(getDomainShortNameForInstance ${DOMAIN})
      INST=${DOMAIN}
      URL=$(getInstanceUrl ${INST} "http")
      URL="${URL}/iCargoHealthCheck/HealthCheck"
      if [[ "${DOM_SHORT_NAME}" != "-" ]]; then
         URL="${URL}_${DOM_SHORT_NAME}"
      fi
      doThaw ${INST} ${URL}
      typeset -i ANS=$?      
      return $ANS
   else
      INSTS=$(findAllInstancesForDomain ${DOMAIN} ${LOCAL_INS} ${ADMORD})     
      if [[ -n ${INSTS} ]]; then
         DOM_SHORT_NAME=$(getDomainShortName ${DOMAIN})
   
         for INST in ${INSTS} ; do
            URL=$(getInstanceUrl ${INST} "http")       
            URL="${URL}/iCargoHealthCheck/HealthCheck"
            if [[ ! -z ${DOM_SHORT_NAME} && "${DOM_SHORT_NAME}" != "-" ]]; then
               URL="${URL}_${DOM_SHORT_NAME}"
            fi
            doThaw ${INST} ${URL}
            typeset -i ANS=$?
         done
         return $ANS
      else
         echoe "No instances for the domain OR instance name ${NAME} in this box" >&2
         return 1
      fi
   fi   
}

doThaw(){
   typeset INST=${1}
   typeset URL=${2}
   wget -O /dev/null -o /dev/null --post-data="action=activate&password=icargo123" "${URL}"
   if [[ $? -ne 0 ]]; then
      echoe "Activating ${INST} failed" >&2
   else
      echoi "${INST} is now active" >&2
    fi
   return 0
}

#
# Main execution block
#

CMD=${1}
DOMAIN_NAME=${2}
VERSION=${3}
OPTION=${4}

if [[ ${CMD} == "" ]]; then
   echoe "A command has to be specified !!"
   prt_usage
   exit 1
fi

#Not checks for help !
if [[ ${CMD} != "help" ]]; then
   if [[ ${DOMAIN_NAME} == "" ]]; then
      echoe "A domain name has to be specified !!"
      prt_usage
      exit 1
   fi

   if [[ ${CMD} != "elog" && ${CMD} != "dlog" && ${CMD} != "freeze" && ${CMD} != "thaw" ]]; then
      isDomainInThisBox ${DOMAIN_NAME}
         if [[ $? -ne 0 ]]; then
            echoe "Instance ${DOMAIN_NAME} is not a weblogic instance in this partition. Maybe on the other one! " >&2
            echo "My instances follow" >&2
            echo "$(cat ${CONF_FILE} | grep -v '#' |awk '{ print $1 ,"\t" ,$2 ,"\t", $5 }' | grep `hostname`)"
            exit 1
         fi
   fi
fi

if [[ ${CMD} = "deploy" || ${CMD} = "restoreVersion" || ${CMD} = "patch" || ${CMD} = "restorePatch" ]]; then
   if [[ ${VERSION} == "" ]]; then
      echoe "A version for the application has to be specified !!"
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
           typeset VERSION=$(retrievePreviousVersionId ${DOMAIN_NAME})
           restoreVersion ${VERSION}
           exit $?
           ;;
        restoreVersion)
           restoreVersion ${VERSION}
           exit $?
           ;;
        patch)
           applyPatch ${DOMAIN_NAME}
           exit $?
           ;;
        patchstruct)
           echo makePatchesHierarchy
           typeset AREA=${VERSION}
           makePatchesHierarchy ${DOMAIN_NAME} ${AREA}
           exit 1
           ;;
        user_stage_struct)
           echo "makeUserStageHierarchy for ${DOMAIN_NAME}"
           makeUserStages ${DOMAIN_NAME}
           exit 1
           ;;
        jspc)
           doJSPC ${DOMAIN_NAME}   
           exit 1
           ;;
       version)
           typeset VERSION=$(retrieveCurrentVersionId ${DOMAIN_NAME})
           typeset PRVVERSION=$(retrievePreviousVersionId ${DOMAIN_NAME})
	   if [[ ${PRVVERSION} == "" ]]; then
              PRVVERSION="unknown"
           fi
           echo "Version of iCargo in domain ${DOMAIN_NAME} is ${VERSION}"
           echo "Previous Version was ${PRVVERSION}"
           exit 1
           ;;
        freeze)
           freeze ${DOMAIN_NAME}
           exit 1
           ;;
        thaw)
           thaw ${DOMAIN_NAME}
           exit 1
           ;;
        history)
           viewDeploymentHistory ${DOMAIN_NAME}
           exit 1
           ;;
        dlog)
           disableICOLogging ${DOMAIN_NAME}
           exit 1
           ;;
        elog)
           enableICOLogging ${DOMAIN_NAME}
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
