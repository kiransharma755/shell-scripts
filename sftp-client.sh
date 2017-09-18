#!/bin/bash
#set -x

##############################################################
#                                                            #
# SFTP Client script			                     #
# @Author : Jens J P                                         #
#                                                            #
##############################################################

CURRDIR=`echo $0 | awk '$0 ~ /^\// { print }'`
if [[ ${CURRDIR} != "" ]]; then
  CURRDIR=`dirname $0`
else
  CURRDIR="`pwd``dirname $0 | cut -c2-`"
fi

CONF_FILE="${CURRDIR}/etc/sftp-client.conf"

# check if the configuration file exists
if [[ ! -r ${CONF_FILE} ]]; then
   echo "[ERROR] sftp-client configuration file ${CONF_FILE} does not exists." >&2
   exit 1
fi

CONF_ENTRY="\$0"
CONF_CLIENT_ID_COLUMN="\$1"
CONF_HOSTNAME_COLUMN="\$2"
CONF_PORT_COLUMN="\$3"
CONF_USERNAME_COLUMN="\$4"
CONF_PASSWORD_COLUMN="\$5"
CONF_AUTH_METHOD_COLUMN="\$6"
CONF_REMOTE_GET_FOLDER_COLUMN="\$7"
CONF_FILE_PATTERN_COLUMN="\$8"
CONF_LOCAL_GET_FOLDER_COLUMN="\$9"
CONF_READ_MODE_COLUMN="\$10"
CONF_REMOTE_PUT_FOLDER_COLUMN="\$11"
CONF_LOCAL_PUT_FOLDER_COLUMN="\$12"
CONF_WRITE_MODE_COLUMN="\$13"

# interval to sleep to ensure file is not written while being downloaded
typeset -i FTP_SLEEP_INTERVAL=2
# the maximum files that would be transfered in one session
typeset -i FTP_MAX_FILES=25

showUsage(){
   echo "Usage :"
   echo "   sftp-client <operation> <client id>"
   echo "   valid operations are \"get\" \"put\" \"list\""
   echo ""
}

# checks if the client id is valid
isValidClient(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_ENTRY}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] client configuration for id ${CLIENTID} does not exists." >&2
      return 1
   fi
   echo $CLIENTID
   return 0
}

# returns the client sftp hostname
getClientHost(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_HOSTNAME_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get hostname for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client sftp port
getClientPort(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_PORT_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get port for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client sftp username
getClientUser(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_USERNAME_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get username for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client sftp password
getClientPassword(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_PASSWORD_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get password for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client sftp authentication method can be PB - password based or KB - key based
getClientAuthMethod(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_AUTH_METHOD_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get authentication method for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client sftp folder
getClientRemoteGetFolder(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_REMOTE_GET_FOLDER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get remote get folder for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client sftp folder file pattern
getClientFilePattern(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_FILE_PATTERN_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get file pattern for client id ${CLIENTID}." >&2
      return 1
   fi
   if [[ "${ENTRY}" == "-" ]]; then
      ENTRY=""
   fi
   echo "$ENTRY"
   return 0
}

# returns the client local folder, the place where the remote files would be downloaded
getClientLocalGetFolder(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_LOCAL_GET_FOLDER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" || ! -r ${ENTRY} ]]; then
      echo "[ERROR] unable to get local get folder for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client read mode, RD - read and delete
getClientReadMode(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_READ_MODE_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get read mode for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client sftp put folder
getClientRemotePutFolder(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_REMOTE_PUT_FOLDER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get remote put folder for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client local put folder, the place from where the files would be uploaded
getClientLocalPutFolder(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_LOCAL_PUT_FOLDER_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" || ! -r ${ENTRY} ]]; then
      echo "[ERROR] unable to get local put folder for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# returns the client write mode, WD - write and delete
getClientWriteMode(){
   CLIENTID="$1"
   ENTRY=$(awk '$0 !~ /^#/ && '${CONF_CLIENT_ID_COLUMN}' == '\"${CLIENTID}\"' { print '${CONF_WRITE_MODE_COLUMN}' }' ${CONF_FILE})
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 || ${ENTRY} == "" ]]; then
      echo "[ERROR] unable to get write mode for client id ${CLIENTID}." >&2
      return 1
   fi
   echo $ENTRY
   return 0
}

# check if a process is already executing in which case it has to be terminated
checkProcess(){
   CLIENTID="$1"
   OPERATION="$2"
   PIDFILE="${CURRDIR}/.${CLIENTID}_${OPERATION}.pid"
   if [[ -r ${PIDFILE} ]]; then
      PREVPID=$(cat ${PIDFILE})
      kill -0 ${PREVPID} >/dev/null 2>&1
      typeset -i ANS=$?
      if [[ ${ANS} -eq 0 ]]; then
         echo "[WARN] prior operation is still alive . This would be terminated."
         echo "[WARN] displaying the process tree"
         ps -ef | grep ${PREVPID}
         kill -9 -${PREVPID}
      fi
   fi
   echo "${$}" >${PIDFILE}
}

# method to find the number of lines
getNumLines(){
   THE_FILE="$1"
   if [[ $(uname) == "SunOS" ]]; then
      typeset -i NUMLINES=$(wc -l ${THE_FILE} | tr -s ' ' | cut -d' ' -f2)
      typeset -i ANS="$?"
      echo $NUMLINES
      return $ANS
   else
      typeset -i NUMLINES=$(wc -l ${THE_FILE} | cut -d' ' -f1)
      typeset -i ANS="$?"
      echo $NUMLINES
      return $ANS
   fi
}

# lists the sftp remote folder
listClient(){
   CLIENT_ID="$1"
   isValidClient ${CLIENT_ID}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] listing failed."
      return 1;
   fi
   
   FTPHOST=$(getClientHost ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPPORT=$(getClientPort ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPUSER=$(getClientUser ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPAUTH=$(getClientAuthMethod ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   if [[ ${FTPAUTH} != "KB" ]]; then
      echo "[ERROR] only keybased (KB) authentication is supported."
      return 1
   fi
   
   FTPDIR=$(getClientRemoteGetFolder ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPFILPTR=$(getClientFilePattern ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] listing failed."
      return 1
   fi
   # finally do the listing
   sftp -oPort=${FTPPORT} ${FTPUSER}@${FTPHOST} << EOF
cd ${FTPDIR}
ls -ltr ${FTPFILPTR}
bye
EOF
   return $?
}

# santizes the file
sanitizeFilterFile(){
   TRGFIL="$1"
   typeset -i NUMLINES=$(getNumLines ${TRGFIL})
   typeset -i SNIPELINE=$(expr ${NUMLINES} - 2)
   TRGFILTMP="${TRGFIL}.tmp"
   tail -${SNIPELINE} ${TRGFIL} > ${TRGFILTMP}
   typeset -i ANS=${?}
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] error while sanitizing file"
      rm ${TRGFILTMP}
      return 1
   fi
   # finally filter it out
   head -${FTP_MAX_FILES} ${TRGFILTMP} > ${TRGFIL}
   awk '$0 ~ /^-/ { print $9 " " $5 } ' ${TRGFIL} > ${TRGFILTMP}
   mv ${TRGFILTMP} ${TRGFIL}
   return ${?}
}

# read and deletes the files from the ftp remote site
readAndDeleteFiles(){
   CLIENT_ID="$1"
   FTPHOST="$2"
   FTPPORT="$3"
   FTPUSER="$4"
   FTPDIR="$5"
   LOCALDIR="$6"
   FILELST="$7"
   BTHFILE="${CURRDIR}/.${CLIENT_ID}_get_batch.sftp"
   
   # create the batch file to be executed
   echo "cd ${FTPDIR}" >${BTHFILE}
   echo "lcd ${LOCALDIR}" >>${BTHFILE}
   while read ftpFile ; do
      echo "get ${ftpFile}" >>${BTHFILE}
      echo "rm ${ftpFile}" >>${BTHFILE}
   done < ${FILELST}
   echo "bye" >>${BTHFILE}
   sftp -oPort=${FTPPORT} -b ${BTHFILE} ${FTPUSER}@${FTPHOST}
   return $?
}

# subroutine for downloading the files from the ftp remote site
getInternal(){
   CLIENT_ID="$1"
   FTPHOST="$2"
   FTPPORT="$3"
   FTPUSER="$4"
   FTPDIR="$5"
   FTPFILPTR="$6"
   LOCALDIR="$7"
   OPER="get"
   # ensure that only one process is executing if previous process is still running or is
   # hung then terminate it and run this 
   checkProcess ${CLIENT_ID} ${OPER}
   
   #TMS=$(date '+%Y%m%d_%H%M%S')
   LST_FILE_START="${CURRDIR}/.${CLIENT_ID}_${OPER}_start.log"
   LST_FILE_END="${CURRDIR}/.${CLIENT_ID}_${OPER}_end.log"
   BTCH_FILE="${CURRDIR}/.${CLIENT_ID}_${OPER}.batch"
   
   cat << EOF > ${BTCH_FILE}
cd ${FTPDIR}
ls -l ${FTPFILPTR}
! cp -p ${LST_FILE_END} ${LST_FILE_START} && echo >${LST_FILE_END} && sleep ${FTP_SLEEP_INTERVAL}
ls -l ${FTPFILPTR}
bye
EOF
   
   sftp -oPort=${FTPPORT} -b ${BTCH_FILE} ${FTPUSER}@${FTPHOST} > ${LST_FILE_END}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] sftp operation failed , connection args \"sftp -oPort=${FTPPORT} ${FTPUSER}@${FTPHOST}\""
      return 1
   fi
   # sanitize and filter the entries
   sanitizeFilterFile ${LST_FILE_END}
   sanitizeFilterFile ${LST_FILE_START}
   # filter the files which are common - ie which are completly written to remote folder
   LST_FILES="${CURRDIR}/.${CLIENT_ID}_${OPER}_files.log"
   comm -12 ${LST_FILE_START} ${LST_FILE_END} | cut -d' ' -f1 > ${LST_FILES}
   # check if there are files to be downloaded
   typeset -i NUMFILES=$(getNumLines ${LST_FILES})
   if [[ ${NUMFILES} -eq 0 ]]; then
      echo "[INFO] no files to download from ${CLIENT_ID}."
      return 0
   fi
   echo "[INFO] number of files to download from ${CLIENT_ID} : ${NUMFILES}"
   readAndDeleteFiles ${CLIENT_ID} ${FTPHOST} ${FTPPORT} ${FTPUSER} ${FTPDIR} ${LOCALDIR} ${LST_FILES}
   return ${?}
}

# downloads the file from the remote ftp site
getFromClient(){
   CLIENT_ID="$1"
   isValidClient ${CLIENT_ID}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] download failed."
      return 1;
   fi
   
   FTPHOST=$(getClientHost ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPPORT=$(getClientPort ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPUSER=$(getClientUser ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPAUTH=$(getClientAuthMethod ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   if [[ ${FTPAUTH} != "KB" ]]; then
      echo "[ERROR] only keybased (KB) authentication is supported."
      return 1
   fi
   
   FTPDIR=$(getClientRemoteGetFolder ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPFILPTR=$(getClientFilePattern ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   LOCALDIR=$(getClientLocalGetFolder ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] download failed."
      return 1
   fi
   getInternal "${CLIENT_ID}" "${FTPHOST}" "${FTPPORT}" "${FTPUSER}" "${FTPDIR}" "${FTPFILPTR}" "${LOCALDIR}"
   return $?
}

# writes the files to sftp folder and delete it from the local folder
writeAndDeleteFiles(){
   CLIENT_ID="$1"
   FTPHOST="$2"
   FTPPORT="$3"
   FTPUSER="$4"
   FTPDIR="$5"
   LOCALDIR="$6"
   FILELST="$7"
   BTHFILE="${CURRDIR}/.${CLIENT_ID}_put_batch.sftp"
   
   # create the batch file to be executed
   echo "cd ${FTPDIR}" >${BTHFILE}
   echo "lcd ${LOCALDIR}" >>${BTHFILE}
   while read ftpFile ; do
      echo "put ${ftpFile}" >>${BTHFILE}
   done < ${FILELST}
   echo "bye" >>${BTHFILE}
   sftp -oPort=${FTPPORT} -b ${BTHFILE} ${FTPUSER}@${FTPHOST}
   typeset -i ANS="${?}"
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] error occured while uploading to sftp folder arguments are \"sftp -oPort=${FTPPORT} -b ${BTHFILE} ${FTPUSER}@${FTPHOST}\""
      return 1
   fi
   echo "[INFO] ftp messages uploaded successfully, clearing local folder ..."
   # if all goes well delete from the local folder
   while read ftpFile ; do
      rm "${LOCALDIR}/${ftpFile}"
   done < ${FILELST}
   return $?
}

# subroutine for uploading the files to the ftp remote site
putInternal(){
   CLIENT_ID="$1"
   FTPHOST="$2"
   FTPPORT="$3"
   FTPUSER="$4"
   FTPDIR="$5"
   FTPFILPTR="$6"
   LOCALDIR="$7"
   OPER="put"
   # ensure that only one process is executing if previous process is still running or is
   # hung then terminate it and run this 
   checkProcess ${CLIENT_ID} ${OPER}
   
   #TMS=$(date '+%Y%m%d_%H%M%S')
   LST_FILE_START="${CURRDIR}/.${CLIENT_ID}_${OPER}_start.log"
   LST_FILE_END="${CURRDIR}/.${CLIENT_ID}_${OPER}_end.log"
   
   # two empty lines added to maintain conformity with the sftp remote listing
   echo "" > ${LST_FILE_START}
   echo "" >> ${LST_FILE_START}
   ls -ltr ${LOCALDIR} >>${LST_FILE_START}
   
   sleep ${FTP_SLEEP_INTERVAL}
   
   echo "" > ${LST_FILE_END}
   echo "" >> ${LST_FILE_END}
   ls -ltr ${LOCALDIR} >>${LST_FILE_END}
   
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] local file listing operation failed , local folder : ${LOCALDIR}"
      return 1
   fi
   # sanitize and filter the entries
   sanitizeFilterFile ${LST_FILE_END}
   sanitizeFilterFile ${LST_FILE_START}
   # filter the files which are common - ie which are completly written to remote folder
   LST_FILES="${CURRDIR}/.${CLIENT_ID}_${OPER}_files.log"
   comm -12 ${LST_FILE_START} ${LST_FILE_END} | cut -d' ' -f1 > ${LST_FILES}
   # check if there are files to be downloaded
   typeset -i NUMFILES=$(getNumLines ${LST_FILES})
   if [[ ${NUMFILES} -eq 0 ]]; then
      echo "[INFO] no files to upload from ${CLIENT_ID}."
      return 0
   fi
   echo "[INFO] number of files to upload from ${CLIENT_ID} : ${NUMFILES}"
   writeAndDeleteFiles ${CLIENT_ID} ${FTPHOST} ${FTPPORT} ${FTPUSER} ${FTPDIR} ${LOCALDIR} ${LST_FILES}
   return ${?}
}

# moves the files from the local folder to the remote sftp folder
putIntoClient(){
   CLIENT_ID="$1"
   isValidClient ${CLIENT_ID}
   typeset -i ANS=$?
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] upload failed."
      return 1;
   fi
   
   FTPHOST=$(getClientHost ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPPORT=$(getClientPort ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPUSER=$(getClientUser ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   FTPAUTH=$(getClientAuthMethod ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   if [[ ${FTPAUTH} != "KB" ]]; then
      echo "[ERROR] only keybased (KB) authentication is supported."
      return 1
   fi
   
   FTPDIR=$(getClientRemotePutFolder ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   # anything in the put folder will be uploaded
   FTPFILPTR="*"
   
   LOCALDIR=$(getClientLocalPutFolder ${CLIENT_ID})
   typeset -i ANSTMP=$?
   ANS=$(expr ${ANS} + ${ANSTMP})
   
   if [[ ${ANS} -ne 0 ]]; then
      echo "[ERROR] upload failed."
      return 1
   fi
   putInternal "${CLIENT_ID}" "${FTPHOST}" "${FTPPORT}" "${FTPUSER}" "${FTPDIR}" "${FTPFILPTR}" "${LOCALDIR}"
   return $?
}

#
# Main block
#

ACTION="${1}"
CLIENTID="${2}"

case ${ACTION} in
         list)
               listClient ${CLIENTID}
               ;;
          get)
               getFromClient ${CLIENTID}
               ;;
          put)
               putIntoClient ${CLIENTID}
               ;;
            *)
               showUsage
               ;;
esac
