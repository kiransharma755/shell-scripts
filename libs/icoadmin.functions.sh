#!/bin/bash
#########################################################################
#                                                                       #
# icoadmin.functions.sh Created on Jan, 2009                            #
#                                                                       #
#########################################################################

#########################################################################
# Utility function supporting the icargo deployment/maintenace script   #
#  - icoadmin                                                           #
#                                                                       #
# @ Author : Binu K (IBS Software Services (P) Ltd)                     #
#########################################################################
#set -x

# folder names
_USER_STAGE="user_stage"
_LIVE="live"
_LANDING="landing"
_ARCHIVE="archive"
_APP="app"
_INTF="intf"
export ARCHIVE="${_USER_STAGE}/${_ARCHIVE}/${_APP}"
export LANDING="${_USER_STAGE}/${_LANDING}/${_APP}"
export LIVE="${_USER_STAGE}/${_LIVE}/${_APP}"
export INTF="${_USER_STAGE}/${_INTF}"

export ICOCONFIG=iCargoConfig
export APP="${APP_DEP_NAME:-icargo}"
export APP_CONFIG=${ICOCONFIG}
export VERSION_FILE="${APP}.ver"
export JIGSAW_VERSION_FILE=jigsaw.ver
export TMPLOC=tmp/_WL_user
export ICARGO_WAR=icargo-web.war
export RELEASE_TYPE_FILE=.icargorel.typ

export BOLD="\033[1m"
export NORM="\033[0m"
export BLINK="\033[5m"
export UNDR="\033[4m" 
export WHITE_F="\033[37m";
export WHITE_B="\033[47m"
export RED_F="\033[31m";
export RED_B="\033[41m"
export BLUE_F="\033[34m";
export BLUE_B="\033[44m"
export YELLOW_F="\033[33m";
export YELLOW_B="\033[43m"
export GREEN_F="\033[32m";
export GREEN_B="\033[42m"
export WHITE_F="\033[37m";
export WHITE_B="\033[47m"
export PATCH_REL_TYPE="PATCH"

#
# $1 - domain name, $2 - version
#
recordVersionId() {
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   echo ${MYDOMDIR}
   typeset VERSION=${2}
   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${VERSION_FILE}
      echo ${VERSION} > ${FILE}
      if [[ $? == 0 ]]; then
          echoi "Recorded ${VERSION} in ${FILE}."
          return 0
       else
          return 1
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi

}

removeVersionId() {
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${VERSION_FILE}
      typeset OUTFILE=${FILE}.old
      if [ -e ${FILE} ]; then
         mv ${FILE} ${OUTFILE} 
         if [[ $? == 0 ]]; then
            echoi "Renamed ${FILE} to ${OUTFILE}"
            return 0
         else
            return 1
         fi
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi
}

moveApp(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LANDING}/icargo.ear
      if [[ -w ${FILE} ]]; then
         typeset DESTFILE=${MYDOMDIR}/${LIVE}/icargo.ear
         cp ${FILE} ${DESTFILE}
         if [[ $? == 0 ]]; then
            echoi "Moved ${FILE} to ${DESTFILE}"
            return 0
         else
            return 1
         fi
      else
         echoe "No write permission on ${FILE} or file does not exist" >&2
         return 1
      fi
   fi
}

cleanApp(){
   typeset DOMAIN=${1}
   typeset TYPE=${2}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset APPLOC=${MYDOMDIR}/${LIVE}/${APP}
   typeset APPLOCHIDDEN=${MYDOMDIR}/${LIVE}/.${APP}

   if [[ -d ${APPLOC} ]]; then
      rm -rf ${APPLOCHIDDEN}
      if [[ ${TYPE} == ${PATCH_REL_TYPE} ]]; then
         cp -R ${APPLOC} ${APPLOCHIDDEN}
         if [[ $? -ne 0 ]]; then
            echoe "Could not back-up App location ${APPLOC}" >&2
            return 1
         fi
      else
         echoi "Cleaning App Folder"
         mv ${APPLOC} ${APPLOCHIDDEN}
      fi
   
      if [[ $? -ne 0 ]]; then
         echoe "Could not clean App location ${APPLOC}" >&2
         return 1
      fi
   fi
}

cleanConfig(){
   typeset DOMAIN=${1}
   typeset TYPE=${2}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset CONFIGLOC=${MYDOMDIR}/${LIVE}/${ICOCONFIG}
   typeset CONFIGLOCHIDDEN=${MYDOMDIR}/${LIVE}/.${ICOCONFIG}

   if [[ -d ${CONFIGLOC} ]]; then
      rm -rf ${CONFIGLOCHIDDEN}
      if [[ ${TYPE} == ${PATCH_REL_TYPE} ]]; then
         cp -R ${CONFIGLOC} ${CONFIGLOCHIDDEN}
         if [[ $? -ne 0 ]]; then
            echoe "Could not back-up Config location ${APPLOC}" >&2
            return 1
         fi
      else
         echoi "Cleaning Config Folder"
         mv ${CONFIGLOC} ${CONFIGLOCHIDDEN}
      fi
   
      if [[ $? -ne 0 ]]; then
         echoe "Could not clean Config location ${CONFIGLOC}" >&2
         return 1
      fi
   fi
}

explodeEar(){
   echoi "Exploding EAR ..."
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      
      typeset FILE=${MYDOMDIR}/${LIVE}/icargo.ear
      if [[ -w ${FILE} ]]; then
         
         typeset RCODE=`unzip -l ${FILE} | grep icargo/ | wc -l`
         if [[ $? -eq 0 ]]; then
            if [[ ${RCODE} -le 1 ]]; then
                mkdir -p ${MYDOMDIR}/${LIVE}/${APP}
                typeset OUTFILE=${MYDOMDIR}/${LIVE}/${APP}
            else
                echoi "The ear ${FILE} has an icargo sub-directory"   
                typeset OUTFILE=${MYDOMDIR}/${LIVE}
            fi
            unzip -oq ${FILE} -d ${OUTFILE}
            if [[ $? -ne 0 ]]; then
               echoe "Could not unzip ${FILE}"
               return 1
            fi
         else
            echoe "Could not unzip ${FILE}" >&2
            return 1
         fi
      else
         echoe "No write permission on ${FILE}" >&2
         return 1
      fi
   else
      echoe "Cannot cd to ${MYDOMDIR}/${LIVE}" >&2
      return 1
   fi
}

explodeWar(){
   echoi "Exploding WAR ..."
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${APP}/icargo-web.war
      if [[ -w ${FILE} ]]; then
         typeset RCODE=`unzip -l ${FILE} | grep icargo-web/ | wc -l`
         if [[ $? -eq 0 ]]; then
            if [[ ${RCODE} -le 1 ]]; then
               mkdir -p ${MYDOMDIR}/${LIVE}/${APP}/icargo-web
               typeset OUTFILE=${MYDOMDIR}/${LIVE}/${APP}/icargo-web
            else
               echoi "The war ${FILE} has an icargo-web sub-directory"
               typeset OUTFILE=${MYDOMDIR}/${LIVE}/${APP}
            fi
            unzip -oq ${FILE} -d ${OUTFILE}
            if [[ $? -ne 0 ]]; then
               echoe "Could not unzip ${FILE}" >&2
               return 1
            else
               rm -f ${FILE}
               if [[ $? -ne 0 ]]; then
                  echoe "Could not remove ${FILE}" >&2
                  return 1
               fi
            fi
        else
           echoe "Could not unzip ${FILE}" >&2
           return 1
        fi
      else
        echoe "No write permission on ${FILE}" >&2
        return 1
      fi
   else
      echoe "Cannot cd to ${MYDOMDIR}/${LIVE}" >&2
      return 1
   fi
}

moveConfig(){
typeset DOMAIN=${1}
typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LANDING}/${ICOCONFIG}.zip
      if [[ -w ${FILE} ]]; then
         typeset DESTFILE=${MYDOMDIR}/${LIVE}/${ICOCONFIG}.zip
         cp ${FILE} ${DESTFILE}
         if [[ $? == 0 ]]; then
      echoi "Moved ${FILE} to ${DESTFILE}"
      return 0
   else
      return 1
   fi
      else
         echoe "No write permission on ${FILE} or file does not exist" >&2
         return 1
      fi
fi
}

explodeConfig(){
   echoi "Exploding iCargoConfig ..."
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${ICOCONFIG}.zip
      if [[ -w ${FILE} ]]; then
         typeset RCODE=`unzip -l ${FILE} | grep ${ICOCONFIG}/ | wc -l`
         if [[ $? -eq 0 ]]; then
            if [[ ${RCODE} -le 1 ]]; then
               mkdir ${MYDOMDIR}/${LIVE}/${ICOCONFIG}
               typeset OUTFILE=${MYDOMDIR}/${LIVE}/${ICOCONFIG}
            else
               echoi "The zip ${FILE} has an ${ICOCONFIG} sub-directory"
               typeset OUTFILE=${MYDOMDIR}/${LIVE}
            fi
            unzip -oq ${FILE} -d ${OUTFILE}
            if [[ $? -ne 0 ]]; then
               echoe "Could not unzip ${FILE}"
               return 1
            fi
         else
            echoe "Could not unzip ${FILE}" >&2
            return 1
         fi
      else
         echoe "No write permission on ${FILE} or file does not exist" >&2
         return 1
      fi
   else
      echoe "Cannot cd to ${MYDOMDIR}/${LIVE}" >&2
      return 1
   fi
}

retrieveCurrentVersionId(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${VERSION_FILE}
      if [ -e ${FILE} ]; then
         echo `cat ${FILE}`
         return 0
      else
         echoe "File ${FILE} does not exist." >&2
         return 1
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi
}

retrievePreviousVersionId(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${VERSION_FILE}.old
      
      if [ -e ${FILE} ]; then
         echo `cat ${FILE}`
         return 0
      else
         echoe "File ${FILE} does not exist." >&2
         return 1
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi
}

archivePreviousApp(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset PRVVRSN=$(retrievePreviousVersionId ${DOMAIN})
   if [ -n "${PRVVRSN}" ]; then
      typeset CURRENTAPPDIR=${MYDOMDIR}/${LIVE}/${APP}
      if [[ -d ${CURRENTAPPDIR} ]]; then
         if [[ ! -d ${MYDOMDIR}/${ARCHIVE}/${PRVVRSN} ]]; then
            mkdir -p ${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}
         fi
         typeset DESTFILE=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}
         cp -pr ${CURRENTAPPDIR} ${DESTFILE}   
            if [[ $? == 0 ]]; then
               echoi "Moved -> ${CURRENTAPPDIR} to ${DESTFILE}"
            else
               return 1
            fi
      else
         echoe "No write permission on ${CURRENTAPPDIR} or directory does not exist" >&2
      fi      
      CURDIR=$(pwd) 
      if [[ -d ${DESTFILE}/${APP}/icargo-web} ]]; then
         cd ${DESTFILE}/${APP}/icargo-web
         jar -cf icargo-web.war .
         mv icargo-web.war ../
         cd ${DESTFILE}/${APP}
         rm ${DESTFILE}/${APP}/icargo-web
      fi
      if [[ -d ${DESTFILE}/${APP} ]]; then
         cd ${DESTFILE}/${APP}
         jar -cf icargo.ear .      
         mv icargo.ear ../
         cd ../  
         rm -r ${APP}
      fi
      cd ${CURDIR}
      typeset FILE=${DESTFILE}/icargo.ear
      echoi "Archived iCargo to ${FILE}"
   else
      echow "No previous iCargo to archive... So skipping"
   fi
   return 0
}

archiveCurrentApp(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/icargo.ear
      if [[ -w ${FILE} ]]; then
         typeset DESTFILE=${MYDOMDIR}/${ARCHIVE}/icargo.ear
         mv ${FILE} ${DESTFILE}
         if [[ $? == 0 ]]; then
            echoi "Moved ${FILE} to ${DESTFILE}"
            return 0
         else
            return 1
         fi   
      else
         echoe "No write permission on ${FILE}" >&2
         return 1
      fi
   fi
}

archivePreviousConfig(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset PRVVRSN=$(retrievePreviousVersionId ${DOMAIN})
   if [ -n "${PRVVRSN}" ]; then
      typeset CURRENTCONFIGDIR=${MYDOMDIR}/${LIVE}/${ICOCONFIG}
      if [[ -d ${CURRENTCONFIGDIR} ]]; then
         if [[ ! -d ${MYDOMDIR}/${ARCHIVE}/${PRVVRSN} ]]; then
            mkdir -p ${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}
         fi
         typeset DESTFILE=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}
         cp -pr ${CURRENTCONFIGDIR} ${DESTFILE}   
         if [[ $? == 0 ]]; then
            echoi "Moved -> ${CURRENTCONFIGDIR} to ${DESTFILE}"
         else
            return 1
         fi
      else
         echoe "No write permission on ${CURRENTCONFIGDIR} or file does not exist" >&2
      fi
      CURDIR=$(pwd) 
      if [[ -d ${DESTFILE}/${ICOCONFIG} ]]; then
         cd ${DESTFILE}/${ICOCONFIG}
         jar -cf ${ICOCONFIG}.zip .
         mv ${ICOCONFIG}.zip ../
         cd ../  
         rm -r ${ICOCONFIG}
      fi
      cd ${CURDIR}
      typeset FILE=${DESTFILE}/${ICOCONFIG}.zip
      echoi "Archived ${ICOCONFIG} to ${FILE}"
      return 0
   else
      echow "No pervious iCargoConfig to archive... So skipping"
   fi
}

archiveCurrentConfig(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${ICOCONFIG}.zip
      if [[ -w ${FILE} ]]; then
         typeset DESTFILE=${MYDOMDIR}/${ARCHIVE}/${ICOCONFIG}.zip
         mv ${FILE} ${DESTFILE}
         if [[ $? == 0 ]]; then
            echoi "Moved ${FILE} to ${DESTFILE}"
            return 0
         else
            return 1
         fi
      else
         echoe "No write permission on ${FILE}" >&2
         return 1
      fi
   fi
}

changeWebAppAndContext(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset CTXPATH=$(getDomainContextPath ${DOMAIN})

   if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${APP}/META-INF/application.xml
      typeset OUTFILE=${FILE}.new
      if [[ -w ${FILE} ]]; then
         sed -e 's/>icargo</>'${CTXPATH}'</' <${FILE} > ${OUTFILE}
         if [[ $? == 0 ]]; then
            echoi "Changed context icargo to ${CTXPATH}"
         else
            return 1
         fi
         mv ${OUTFILE} ${FILE}
         sed -e 's/>icargo-web.war</>icargo-web</' <${FILE} > ${OUTFILE}
         if [[ $? == 0 ]]; then
            echoi "Changed icargo-web.war to icargo-web"
         else
            return 1
         fi
         mv ${OUTFILE} ${FILE}
      
      else
         echoe "No write permission on ${FILE} or file does not exist" >&2
         return 1
      fi
      return 0
   fi
}

cleanTemp(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   # find instances for domain - domainname localinstances ignoreAdmin
   LOCALINST="true"
   ADMSERVER="I"
   typeset INSTANCES=$(findAllInstancesForDomain ${DOMAIN} ${LOCALINST} ${ADMSERVER})
   for INSTANCE in ${INSTANCES}; do
      typeset TMPMDIR=${MYDOMDIR}/servers/${INSTANCE}/${TMPLOC}

      if [[ -x ${TMPMDIR} ]]; then
         rm -rf ${TMPMDIR}
         if [[ $? == 0 ]]; then
            echoi "Cleaned Temp"                
         else
            echow "Could not clean Temp Location ${TMPMDIR}"
         fi
      else
         echow "No write permission on ${TMPMDIR} or does not exist" >&2
      fi
   done
   return 0
}

# will replace the files in the iCargoConfig folder with the default config files
writeOutConfig(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEST_FOLDER=${MYDOMDIR}/${LIVE}/${ICOCONFIG}
   typeset SRC_FOLDER=${COMMON_CONFIG_DIR}/${DOMAIN}/${ICOCONFIG}

   if [[ -r ${SRC_FOLDER} ]]; then
      echow "#### WARNING!!   WARNING!!      WARNING!!   ######"
      echow "The following files will be replaced from backed up configuration"
      ls -R ${SRC_FOLDER}
      cp -R ${SRC_FOLDER}/* ${DEST_FOLDER}/
      return 0;
   else
      echow "Common ${ICOCONFIG} directory does not exist or is readonly: ${SRC_FOLDER}"
      return 1;
   fi
}

# will replace the files in the iCargoConfig folder with the host specific config files ie ${hostname}/iCargoConfig -> iCargoConfig
writeOutHostConfig(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEST_FOLDER=${MYDOMDIR}/${LIVE}/${ICOCONFIG}
   typeset HOST_NAME=$(hostname)
   typeset SRC_FOLDER=${COMMON_CONFIG_DIR}/${DOMAIN}/${HOST_NAME}/${ICOCONFIG}

   if [[ -r ${SRC_FOLDER} ]]; then
      echow "#### WARNING!!   WARNING!!      WARNING!!   ######"
      echow "The following files will be replaced from host specific backed up configuration"
      ls -R ${SRC_FOLDER}
      cp -R ${SRC_FOLDER}/* ${DEST_FOLDER}/
      return 0;
   else
      echow "Host specific ${ICOCONFIG} directory does not exist or is readonly: ${SRC_FOLDER}"
      return 1;
   fi
}

# will replace the files in icargo.ear with the default files from store
writeOutEar(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEST_FOLDER=${MYDOMDIR}/${LIVE}/${APP}
   typeset SRC_FOLDER=${COMMON_CONFIG_DIR}/${DOMAIN}/${APP}

if [[ -r ${SRC_FOLDER} ]]; then
   echow "#### WARNING!!   WARNING!!      WARNING!!   ######"
   echow "The following files will be replaced from backed up application"
   ls -R ${SRC_FOLDER}
   cp -R ${SRC_FOLDER}/* ${DEST_FOLDER}/
   return 0;
else
   echow "Common application directory does not exist or is readonly: ${SRC_FOLDER}"
   return 1;
fi

}

makeUserStages(){
  typeset DOMAIN=${1}
  isDomainInThisBox ${DOMAIN}
  if [[ $? -ne 0 ]]; then
    continue
  fi
  makeDirectories ${DOMAIN} APP_HOME
  makeDirectories ${DOMAIN} APP_LANDING
  makeDirectories ${DOMAIN} APP_LOGS
  makeDirectories ${DOMAIN} COMMON
}

makeDirectories(){
 typeset DOMAIN=${1}
 typeset AREA=${2}
 typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
 if [[ ! -d ${MYDOMDIR}/${_USER_STAGE} ]]; then
   mkdir -p ${MYDOMDIR}/${_USER_STAGE}
 fi
 case ${AREA} in
        APP_HOME)
      echo "Creating APP_HOME directories..."
                  $(checkPathExist ${ROOT_ICO_HOME_DIR})
      if [[ $? == 0 ]]; then
         APP_HOME_LIVE=${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_LIVE}/${_APP}
         if [[ ! -d ${APP_HOME_LIVE} ]]; then
            mkdir -p ${APP_HOME_LIVE}
            echoi "${APP_HOME_LIVE} created"
            # create simlink to USER_STAGE/LIVE
            ln -s ${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_LIVE} ${MYDOMDIR}/${_USER_STAGE}/${_LIVE} 
            echo "${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_LIVE} ${MYDOMDIR}/${_USER_STAGE}/${_LIVE} created"
         fi

         APP_HOME_ARCHIVE=${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_ARCHIVE}/${_APP}
         if [[ ! -d ${APP_HOME_ARCHIVE} ]]; then
            mkdir -p ${APP_HOME_ARCHIVE}
            echoi "${APP_HOME_ARCHIVE} created"
            # create simlink to USER_STAGE/ARCHIVE
            ln -s ${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_ARCHIVE} ${MYDOMDIR}/${_USER_STAGE}/${_ARCHIVE} 
            echo "${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_ARCHIVE} -> ${MYDOMDIR}/${_USER_STAGE}/${_ARCHIVE} created"
         fi
         APP_HOME_INTF=${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_INTF}
         if [[ ! -d ${APP_HOME_INTF} ]]; then
            mkdir -p ${APP_HOME_INTF}
            echoi "${APP_HOME_INTF} created"
            # create simlink to USER_STAGE/INTF
            ln -s ${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_INTF} ${MYDOMDIR}/${_USER_STAGE}/${_INTF}
            echo "${ROOT_ICO_HOME_DIR}/${DOMAIN}/${_INTF} -> ${MYDOMDIR}/${_USER_STAGE}/${_INTF} created"
         fi
      else
         echow "${ROOT_ICO_HOME_DIR} does not exists, so skipping"
      fi
                ;;
        APP_LANDING)
                echoi "Creating APP_LANDING directories..."
      $(checkPathExist ${ROOT_LANDING_DIR})
      if [[ $? == 0 ]]; then
         APP_LANDING=${ROOT_LANDING_DIR}/${DOMAIN}/${_APP}
         if [[ ! -d ${APP_LANDING} ]]; then
            mkdir -p ${APP_LANDING}
            echoi "${APP_LANDING} created"
         fi
         if [[ -d ${ROOT_LANDING_DIR}/${DOMAIN} ]]; then
            if [[ ! -d ${MYDOMDIR}/${_USER_STAGE}/${_LANDING} ]]; then   
               # create simlink to USER_STAGE/ARCHIVE
               ln -s ${ROOT_LANDING_DIR}/${DOMAIN} ${MYDOMDIR}/${_USER_STAGE}/${_LANDING} 
               echoi "${ROOT_LANDING_DIR}/${DOMAIN} -> ${MYDOMDIR}/${_USER_STAGE}/${_LANDING}  created"
            fi
         fi
      else
         echow "${ROOT_LANDING_DIR} does not exists, so skipping"
      fi
                ;;
   APP_LOGS)
      echoi "Creating APP_LOGS directories..."
      $(checkPathExist ${ROOT_LOG_DIR})
      if [[ $? == 0 ]]; then
         APP_LOGS=${ROOT_LOG_DIR}/${DOMAIN}
         if [[ ! -d ${APP_LOGS} ]]; then
            mkdir -p ${APP_LOGS}/app ${APP_LOGS}/wls
            echoi "${APP_LOGS} created"
         fi
         if [[ -d ${APP_LOGS} ]]; then
            # create simlink to USER_STAGE/LOGS
            if [[ ! -d ${MYDOMDIR}/${_USER_STAGE}/logs  ]]; then
               ln -s ${APP_LOGS} ${MYDOMDIR}/${_USER_STAGE}/logs 
               echo "${APP_LOGS} -> ${MYDOMDIR}/${_USER_STAGE}/logs  created"
            fi
         fi
      else
         echow "${ROOT_LOG_DIR} does not exists, so skipping"
      fi
                ;;
   COMMON)
      echoi "Creating COMMON directories..."
      $(checkPathExist ${COMMON_CONFIG_DIR})
      if [[ $? == 0 ]]; then
         if [[ ! -d ${MYDOMDIR}/${_USER_STAGE}/common ]]; then
         ln -s ${COMMON_CONFIG_DIR} ${MYDOMDIR}/${_USER_STAGE}/common 
         echo "${COMMON_CONFIG_DIR} -> ${MYDOMDIR}/${_USER_STAGE}/common  created"
         fi
      else
         echow "${COMMON_CONFIG_DIR} does not exists, so skipping"
      fi
                ;;
        *)
                echoe "Unknown AREA - ${AREA} specifed. Can be APP_LANDING,APP_HOME,APP_LOGS" >&2
                return 1
                ;;
 esac
}

checkPathExist(){
   typeset DIR_PATH=${1}
   if [[ ! -d ${DIR_PATH} ]]; then
      echoe "${DIR_PATH} does not exist or No write permission">&2
      return 1
   else
      return 0   
   fi
}

doJSPC(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset HOST=$(hostname)

   if [[ $? == 0 ]]; then
      ${ANT_HOME}/bin/ant -Dear.home=${MYDOMDIR}/${LIVE}/${APP} -DWL_HOME=$WL_HOME -DJAVA_HOME=$JAVA_HOME -f ${CURRDIR}/jspc.xml > ${MYDOMDIR}/${_USER_STAGE}/logs/wls/jspc_${DOMAIN}_${HOST}.log 2>&1 &
      echo ""
      echoi "JSPC has been initiated for DOMAIN : ${DOMAIN}"
      echoi "This takes approximately 15 minutes !"
      echoi "Please check ${MYDOMDIR}/${_USER_STAGE}/logs/wls/jspc_${DOMAIN}_${HOST}.log  for status of the JSPC"
      echo ""
   else
      echoe "Could not create icargo.properties for the jspc of domain ${DOMAIN}"
      return 1
   fi
}


# checks if the instance is running in this box
isDomainInThisBox(){
   DOMAIN="$1"
   LOCALINST="true"
   ADMSERVER="F"
   typeset INSTANCES=$(findAllInstancesForDomain ${DOMAIN} ${LOCALINST} ${ADMSERVER})   
   if [[ -z ${INSTANCES}] || ${INSTANCES} == "" ]]; then
   return 1
   else
      return 0
   fi
}

recordDeployment() {
   typeset DOMAIN=${1}
   typeset VERSION=${2}
   typeset TYPE=${3}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEPHISTORY=${MYDOMDIR}/${ARCHIVE}/.deployment_history.log

   if [[ -n ${MYDOMDIR}/${ARCHIVE} ]]; then  
      DATTE=$(date '+%d-%b-%y %H:%M:%S')
      touch ${DEPHISTORY}
      DAY=$(date '+%d %b %y %H:%M:%S')
      #MYHOST=$(who -m | awk '{ print $6 }')
      #ME=$(who -m | awk '{ print $1 }')
      echo "Domain ${DOMAIN} updated with version ${VERSION} of type ${TYPE} on ${DATTE}" >> ${DEPHISTORY}
      return 0
   else
      echoe "Could not find Archive Location  ${MYDOMDIR}/${ARCHIVE}." >&2
      return 1
fi

}

viewDeploymentHistory() {
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEPHISTORY=${MYDOMDIR}/${ARCHIVE}/.deployment_history.log

   if [[ -n ${MYDOMDIR}/${ARCHIVE} ]]; then  
      tail -15 ${DEPHISTORY}
   else
      echoe "Could not find Archive Location  ${MYDOMDIR}/${ARCHIVE}." >&2
      return 1
   fi
}

#
# $1 - domain name, $2 - release type
#
recordReleaseType() {
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset RELTYPE=${2}
   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${RELEASE_TYPE_FILE}
      echo ${RELTYPE} > ${FILE}
      if [[ $? == 0 ]]; then
         echoi "Recorded ${RELTYPE} in ${FILE}."
         return 0
      else
         return 1
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi

}

#
# $1 - domain name $2 - version
#

retrieveReleaseType4Version() {
   typeset DOMAIN=${1}
   typeset PRVVRSN=${2}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -d ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}/${RELEASE_TYPE_FILE}
      if [[ -f ${FILE} ]]; then
         echoe "${PRVVRSN} does not exist in the archive"   
         return 1
      fi
      typeset RELTYPE=$(cat ${FILE})
      echoi "Release type -> ${RELTYPE}"
   else
      echoe "Domain directory ${MYDOMDIR} or version ${PRVVRSN} is not correct." >&2
      return 1
   fi

}

archivePreviousReleaseType(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset PRVVRSN=$(retrievePreviousVersionId ${DOMAIN})

   if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${RELEASE_TYPE_FILE}
      if [[ -w ${FILE} ]]; then
         mkdir -p ${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}
         typeset DESTFILE=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}/${RELEASE_TYPE_FILE}
         mv ${FILE} ${DESTFILE}
         if [[ $? == 0 ]]; then
            echoi "Moved ${FILE} to ${DESTFILE}"
            return 0
         else
            return 1
         fi
      else
         echoe "No write permission on ${FILE} or file does not exist" >&2
      fi
      return 0
   fi
}

retrieveReleaseCandidates(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   if [[ -n ${MYDOMDIR} ]]; then
      typeset ARCHDIR=${MYDOMDIR}/${ARCHIVE}
      echo "\n"
      for file in $(find ${ARCHDIR} -name ${RELEASE_TYPE_FILE}); do
         typeset RELTYPE=$(cat ${file})
         if [[ ${RELTYPE} = "FULL" ]]; then
            typeset BASEDIR=$(dirname ${file})
            echo -e "${BOLD}${BASEDIR}${NORM}"
         fi
      done
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi
}

#Enable iCargo Logging on the instance
# Needs the name of the instance as the first argument
enableICOLogging() {
   WLS_INSTANCE=${1}
   LOG_CNTRL=${DIRCMD}/logControl.jar

   if [[ -e ${LOG_CNTRL} ]]; then
      JMX_PORT=$(getJMXPort ${WLS_INSTANCE})
      if [[ $? == 0 ]]; then
         #Enable ICO Logs
         java -jar ${LOG_CNTRL} -p ${JMX_PORT} -ea
         if [[ $? != 0 ]]; then
           echoe "Enabling ICO Logging Failed" >&2
         fi
         echoi "ICO Logger Levels"
         ${JAVA_HOME}/bin/java -jar ${LOG_CNTRL} -p ${JMX_PORT} -q
         echoi "Note:Logging will be DISABLED AUTOMATICALLY in 5 minutes."
         echo "icoadmin dlog ${WLS_INSTANCE}" | at now + 5 minutes
      fi
   else
      echoe "Log Control JAR ${LOG_CNTRL} cannot be found >&2"
   fi
}

#Disable iCargo Logging on the instance
# Needs the name of the instance as the first argument
disableICOLogging() {
   WLS_INSTANCE=${1}
   LOG_CNTRL=${DIRCMD}/logControl.jar

   if [[ -e ${LOG_CNTRL} ]]; then
      JMX_PORT=$(getJMXPort ${WLS_INSTANCE})
      if [[ $? == 0 ]]; then
         #Disable ICO Logs
         java -jar ${LOG_CNTRL} -p ${JMX_PORT} -da
         if [[ $? != 0 ]]; then
            echoe "Disable ICO Logging Failed" >&2
         fi
         echoi "ICO Logger Levels"
         ${JAVA_HOME}/bin/java -jar ${LOG_CNTRL} -p ${JMX_PORT} -q
      fi
   else
      echoe "Log Control JAR ${LOG_CNTRL} cannot be found >&2"
   fi
}

showDetailedHelp(){
   trap 'echo ${NORM} & exit 1' INT
   HLP_RAW_TXT=${DIRCMD}/script_help_2.txt
   PAGE_DISPLAY=56
   typeset -i lc=1
   if [[ -e ${HLP_RAW_TXT} ]]; then
      cat ${HLP_RAW_TXT} | \
      while read -p LINE ;do
         let lc=lc+1
         if [[ $lc -gt ${PAGE_DISPLAY} ]]; then
            echo -e ${BOLD}${RED_F}
            read resp?"Press Enter To Continue"
            echo -e $NORM
            clear
            lc=1
         fi
         eval $LINE
      done
   fi 
}

moveJigsawApp(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LANDING}/jigsaw.war
      if [[ -w ${FILE} ]]; then
         typeset DESTFILE=${MYDOMDIR}/${LIVE}/jigsaw.war
         cp ${FILE} ${DESTFILE}
         if [[ $? == 0 ]]; then
            echoi "Moved ${FILE} to ${DESTFILE}"
            return 0
         else
            return 1
         fi
      else
         echoe "No write permission on ${FILE} or file does not exist" >&2
         return 1
      fi
   fi
}

removeJigsawVersionId() {
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${JIGSAW_VERSION_FILE}
      typeset OUTFILE=${FILE}.old
      if [ -e ${FILE} ]; then
         mv ${FILE} ${OUTFILE} 
         if [[ $? == 0 ]]; then
            echoi "Renamed ${FILE} to ${OUTFILE}"
            return 0
         else
            return 1
         fi
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi
}

recordJigsawVersionId() {
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   echo ${MYDOMDIR}
   typeset VERSION=${2}
   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${JIGSAW_VERSION_FILE}
      echo ${VERSION} > ${FILE}
      if [[ $? == 0 ]]; then
         echoi "Recorded ${VERSION} in ${FILE}."
         return 0
      else
         return 1
      fi
  else
     echoe "Domain directory ${MYDOMDIR} is not correct." >&2
     return 1
  fi

}

archivePreviousJigsawApp(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset PRVVRSN=$(retrievePreviousJigsawVersionId ${DOMAIN})
   if [ -n "${PRVVRSN}" ]; then
      typeset CURRENTAPPDIR=${MYDOMDIR}/${LIVE}/jigsaw
      if [[ -d ${CURRENTAPPDIR} ]]; then
         if [[ ! -d ${MYDOMDIR}/${ARCHIVE}/${PRVVRSN} ]]; then
            mkdir -p ${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}
         fi
         typeset DESTFILE=${MYDOMDIR}/${ARCHIVE}/${PRVVRSN}
         cp -pr ${CURRENTAPPDIR} ${DESTFILE}   
         if [[ $? == 0 ]]; then
            echoi "Moved -> ${CURRENTAPPDIR} to ${DESTFILE}"
         else
            return 1
         fi
      else
         echoe "No write permission on ${CURRENTAPPDIR} or directory does not exist" >&2
      fi      
      CURDIR=$(pwd) 
      if [[ -d ${DESTFILE}/jigsaw} ]]; then
         cd ${DESTFILE}/jigsaw  
         jar -cf jigsaw.war .      
         mv jigsaw.war ../
         cd ../  
         rm -r jigsaw
      fi
      cd ${CURDIR}
      typeset FILE=${DESTFILE}/jigsaw.war
      echoi "Archived ${CURRENTAPPDIR} to ${FILE}"
   else
      echow "No previous jigsaw to archive... So skipping"
   fi
   return 0
}

cleanJigsawApp(){
   typeset DOMAIN=${1}
   typeset TYPE=${2}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset APPLOC=${MYDOMDIR}/${LIVE}/jigsaw
   typeset APPLOCHIDDEN=${MYDOMDIR}/${LIVE}/.jigsaw

   if [[ -d ${APPLOC} ]]; then
      rm -rf ${APPLOCHIDDEN}
      if [[ ${TYPE} == ${PATCH_REL_TYPE} ]]; then
         cp -R ${APPLOC} ${APPLOCHIDDEN}
         if [[ $? -ne 0 ]]; then
            echoe "Could not back-up App location ${APPLOC}" >&2
            return 1
         fi
      else
         echoi "Cleaning App Folder"
         mv ${APPLOC} ${APPLOCHIDDEN}
      fi
   
      if [[ $? -ne 0 ]]; then
         echoe "Could not clean App location ${APPLOC}" >&2
         return 1
      fi
   fi

}

explodeJigsawWar(){
   echoi "Exploding Jigsaw War ..."
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then      
      typeset FILE=${MYDOMDIR}/${LIVE}/jigsaw.war
      if [[ -w ${FILE} ]]; then   
         typeset RCODE=`unzip -l ${FILE} | grep jigsaw/ | wc -l`
         if [[ $? -eq 0 ]]; then
            if [[ ${RCODE} -le 1 ]]; then
               mkdir -p ${MYDOMDIR}/${LIVE}/jigsaw
               typeset OUTFILE=${MYDOMDIR}/${LIVE}/jigsaw
            else
               echoi "The war ${FILE} has an jigsaw sub-directory"   
               typeset OUTFILE=${MYDOMDIR}/${LIVE}
            fi
            unzip -oq ${FILE} -d ${OUTFILE}
            if [[ $? -ne 0 ]]; then
               echoe "Could not unzip ${FILE}"
               return 1
            fi
         else
            echoe "Could not unzip ${FILE}" >&2
            return 1
         fi
      else
         echoe "No write permission on ${FILE}" >&2
         return 1
      fi
   else
      echoe "Cannot cd to ${MYDOMDIR}/${LIVE}" >&2
      return 1
   fi
}

# will replace the files in the jigsaw folder with the default config files from jigsaw store
writeOutJigsawConfig(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEST_FOLDER=${MYDOMDIR}/${LIVE}/jigsaw
   typeset SRC_FOLDER=${COMMON_CONFIG_DIR}/${DOMAIN}/jigsaw

   if [[ -r ${SRC_FOLDER} ]]; then
      echow "#### WARNING!!   WARNING!!      WARNING!!   ######"
      echow "The following files will be replaced from backed up configuration"
      ls -R ${SRC_FOLDER}
      cp -R ${SRC_FOLDER}/* ${DEST_FOLDER}/
      return 0;
   else
      echow "Common jigsaw directory does not exist or is readonly: ${SRC_FOLDER}"
      return 1;
   fi
}

archiveCurrentJigsawApp(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -x ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/jigsaw.war
      if [[ -w ${FILE} ]]; then
         typeset DESTFILE=${MYDOMDIR}/${ARCHIVE}/jigsaw.war
         mv ${FILE} ${DESTFILE}
         if [[ $? == 0 ]]; then
            echoi "Moved ${FILE} to ${DESTFILE}"
            return 0
         else
            return 1
        fi  
      else
         echoe "No write permission on ${FILE}" >&2
         return 1
      fi
   fi
}

retrievePreviousJigsawVersionId(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${JIGSAW_VERSION_FILE}.old
      
      if [ -e ${FILE} ]; then
         echo `cat ${FILE}`
         return 0
      else
         echoe "File ${FILE} does not exist." >&2
         return 1
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi
}

retrieveCurrentJigsawVersionId(){
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})

   if [[ -n ${MYDOMDIR} ]]; then
      typeset FILE=${MYDOMDIR}/${LIVE}/${JIGSAW_VERSION_FILE}
      if [ -e ${FILE} ]; then
         echo `cat ${FILE}`
         return 0
      else
         echoe "File ${FILE} does not exist." >&2
         return 1
      fi
   else
      echoe "Domain directory ${MYDOMDIR} is not correct." >&2
      return 1
   fi
}

viewJigsawDeploymentHistory() {
   typeset DOMAIN=${1}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEPHISTORY=${MYDOMDIR}/${ARCHIVE}/.deployment_history_jigsaw.log

   if [[ -n ${MYDOMDIR}/${ARCHIVE} ]]; then  
      tail -15 ${DEPHISTORY}
   else
      echoe "Could not find Archive Location  ${MYDOMDIR}/${ARCHIVE}." >&2
      return 1
   fi
}

restoreToLanding(){
   typeset FILE=${1}
   typeset DST=${2}
   if [[ -w ${FILE} ]]; then
      cp ${FILE} ${DST}
      if [[ $? == 0 ]]; then
         echoi "Copied ${FILE} to ${DST}"
         return 0
      else
         return 1
      fi     
   else
      echoe "No write permission on ${DST} or  ${FILE} or file does not exist" >&2
   fi
}

recordJigsawDeployment() {
   typeset DOMAIN=${1}
   typeset VERSION=${2}
   typeset TYPE=${3}
   typeset MYDOMDIR=$(getDomainDirectoryForDomain ${DOMAIN})
   typeset DEPHISTORY=${MYDOMDIR}/${ARCHIVE}/.deployment_history_jigsaw.log

   if [[ -n ${MYDOMDIR}/${ARCHIVE} ]]; then
      DATTE=$(date '+%d-%b-%y %H:%M:%S')
      touch ${DEPHISTORY}
      DAY=$(date '+%d %b %y %H:%M:%S')
      #MYHOST=$(who -m | awk '{ print $6 }')
      #ME=$(who -m | awk '{ print $1 }')
      echoi "Domain ${DOMAIN} updated with version ${VERSION} of type ${TYPE} on ${DATTE}" >> ${DEPHISTORY}
      return 0
   else
      echoe "Could not find Archive Location  ${MYDOMDIR}/${ARCHIVE}." >&2
      return 1
   fi

}

