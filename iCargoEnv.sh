#!/bin/bash

SERVER_NAME="${1}"
if [[ ${SERVER_NAME} == "" ]]; then
   echo "The script needs to be sourced with the server name as argument !"
   exit 1
fi
IS_MIN="${2}"
# to prevent duplicate entries in classpath
[[ ${IS_MIN} != "min" ]] && CLASSPATH=""

echo "Configuring environment for ${1} server ..."

#
# Customisable Parameters
#

DOMAIN_NAME="base_domain"
DOMAIN_HOME="/cellone/Oracle/Middleware/Oracle_Home/user_projects/domains/base_domain"
COMMON_HOME="${DOMAIN_HOME}/user_stage/common"
IC_DOMAIN_HOME="${DOMAIN_HOME}/user_stage/live/app/iCargoConfig"
LOG_DIR="${DOMAIN_HOME}/user_stage/logs"
SYSTEMUSER="system"
SYSTEMUSERPWD="webl0g!c"
TMPDIR="/cellone/tmp"

# JMX Ports configuration
JMX_PORT_ADM=7999
JMX_PORT_MS1=4999
JMX_PORT_MS2=5999

#Uncomment this when debug is to enabled in the corresponding managed servers.
#ADM_DEBUG="-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=7088,server=y,suspend=n"
#MS1_DEBUG="-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=4088,server=y,suspend=n"
#MS3_DEBUG="-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=5088,server=y,suspend=n"

#
# iCargo specific classpath settings
#
ICOCLASSPATH="${COMMON_HOME}/lib/iCSecurityDependency.jar:${COMMON_HOME}/lib/geronimo-ws-metadata_2.0_spec-1.1.2.jar:${COMMON_HOME}/lib/mbeantypes/icSecurityProviders.jar:${COMMON_HOME}/lib/icargo-custom-log.jar:${WL_HOME}/modules/com.bea.core.apache.xercesImpl_2.8.1.1.jar:${COMMON_HOME}/lib/:${COMMON_HOME}/lib/log4jdbc4-1.2.jar"

#
# MQ JMS Parameters
#
#export MQ_JAVA_INSTALL_PATH="/usr/mqm/java"
#export MQ_JAVA_LIB_PATH="/usr/mqm/java/lib"
#export MQ_JAVA_LIB_PATH="${COMMON_HOME}/lib"
#export MQ_JAVA_DATA_PATH="/var/mqm"
#export MQ_PROVIDER="IBM WebSphere MQ"
#MQ_JAVA_TRACE="false"
#MQCLASSPATH="$MQ_JAVA_INSTALL_PATH:$MQ_JAVA_LIB_PATH:$MQ_JAVA_LIB_PATH/com.ibm.mq.commonservices.jar:$MQ_JAVA_LIB_PATH/com.ibm.mq.headers.jar:$MQ_JAVA_LIB_PATH/com.ibm.mq.jar:$MQ_JAVA_LIB_PATH/com.ibm.mq.jmqi.jar:$MQ_JAVA_LIB_PATH/com.ibm.mq.jms.Nojndi.jar:$MQ_JAVA_LIB_PATH/com.ibm.mq.pcf.jar:$MQ_JAVA_LIB_PATH/com.ibm.mq.soap.jar:$MQ_JAVA_LIB_PATH/com.ibm.mq.tools.ras.jar:$MQ_JAVA_LIB_PATH/com.ibm.mqjms.jar:$MQ_JAVA_LIB_PATH/connector.jar:$MQ_JAVA_LIB_PATH/dhbcore.jar:$MQ_JAVA_LIB_PATH/fscontext.jar:$MQ_JAVA_LIB_PATH/providerutil.jar:$MQ_JAVA_LIB_PATH/rmm.jar"

export EXT_PRE_CLASSPATH="${ICOCLASSPATH}"

OLD_JAVA_OPTIONS="${JAVA_OPTIONS}"

#Generic java options for all
JAVA_OPTIONS_CMN="${OLD_JAVA_OPTIONS} -Djava.io.tmpdir=${TMPDIR} -Dweblogic.unicast.HttpPing=true -Djava.security.policy=${WL_HOME}/server/lib/weblogic.policy -Dweblogic.configuration.schemaValidationEnabled=false -Djava.net.preferIPv4Stack=true -Dappserver.name=Weblogic -Dweblogic.wsee.skip.async.response=true -Djava.security.egd=file:/dev/./urandom -Dweblogic.alternateTypesDirectory=${COMMON_HOME}/lib/mbeantypes -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dcom.sun.jersey.server.impl.cdi.lookupExtensionInBeanManager=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dweblogic.system.BootIdentityFile=${DOMAIN_HOME}/servers/${SERVER_NAME}/security/boot.properties"

# For Admin Server - minimum profile
JAVA_OPTIONS_ADM_MIN="${JAVA_OPTIONS_CMN}"

#Generic managed server option.
JAVA_OPTIONS_MSCMN="${JAVA_OPTIONS_CMN} -Dweblogic.Name=${SERVER_NAME} -DnodeName=${SERVER_NAME} -Dicargo.environment.name=${SERVER_NAME} -Dxss.filter=true -Dicargo.csrf.guard=false -Dwls.admin.username=${SYSTEMUSER} -Dwls.admin.password=${SYSTEMUSERPWD} -Dservice.properties=${IC_DOMAIN_HOME} -Djava.security.auth.login.config=${IC_DOMAIN_HOME}/jaas.config -DSprout_Config_Path=${IC_DOMAIN_HOME} -Dresultset.maxsize=50000 -Dicargo.uilayout=true -Dportaluserallowed=true -Dicargo.configuration=xconfig.xml -Dxibase.persistence.pageSize=25 -Djavax.xml.soap.MessageFactory=com.sun.xml.messaging.saaj.soap.ver1_1.SOAPMessageFactory1_1Impl -Denable.leak.profile=true -Dicargo.daterangecheckrequired=true -Dorg.jboss.weld.xml.disableValidating=true -Djava.endorsed.dirs=${COMMON_HOME}/lib/endorsed -Dorg.apache.cxf.Logger=org.apache.cxf.common.logging.Log4jLogger -Djava.awt.headless=true -Dpython.cachedir=${LOG_DIR}/python -Dlog4j.configuration=file:${IC_DOMAIN_HOME}/LoggerConfig.xml"
 
JAVA_OPTIONS_ADM="${ADM_DEBUG} ${JAVA_OPTIONS_MSCMN} -Dcom.sun.management.jmxremote.port=${JMX_PORT_ADM} -DstartListeners=NONE"
JAVA_OPTIONS_MS1="${MS1_DEBUG} ${JAVA_OPTIONS_MSCMN} -Dcom.sun.management.jmxremote.port=${JMX_PORT_MS1} -DstartListeners=NONE" 
JAVA_OPTIONS_MS2="${MS2_DEBUG} ${JAVA_OPTIONS_MSCMN} -Dcom.sun.management.jmxremote.port=${JMX_PORT_MS2} -DstartListeners=NONE" 


# Memory Arguments for admin and managed server

MEM_ARGS_ADM="-Xms512M -Xmx512M -XX:PermSize=512m -XX:MaxPermSize=512m"
#MEM_ARGS_MS="-Xms2G -Xmx2G -XX:MaxNewSize=512M -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:+CMSPermGenSweepingEnabled -XX:PermSize=256m -XX:MaxPermSize=512M -Xloggc:${LOG_DIR}/wls/${SERVER_NAME}_GC_`date +%d%b%Y_%H%M`.log -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintHeapAtGC -XX:-UseGCOverheadLimit -XX:HeapDumpPath=${LOG_DIR}/wls/${SERVER_NAME}_heapdump_`date +%d%b%Y_%H%M`.hprof -XX:+HeapDumpOnOutOfMemoryError"
MEM_ARGS_MS="-Xms6G -Xmx6G -XX:MaxPermSize=2G -XX:+UseG1GC -XX:G1ReservePercent=20 -Xloggc:${LOG_DIR}/wls/${SERVER_NAME}_GC.log -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintHeapAtGC -XX:-UseGCOverheadLimit"

case ${SERVER_NAME} in
    'AdminServer')    
                      if [[ ${IS_MIN} == "min" ]]; then
                        export JAVA_OPTIONS="${JAVA_OPTIONS_ADM_MIN}"
                      else
                        export JAVA_OPTIONS="${JAVA_OPTIONS_ADM_MIN}"
                        export USER_MEM_ARGS="${MEM_ARGS_ADM}"
                      fi
		      ;;
    ico_prf_vm?_ms1 )
                      export JAVA_OPTIONS="${JAVA_OPTIONS_MS1}"
                      export USER_MEM_ARGS="${MEM_ARGS_MS}"
		      ;;
    ico_prf_vm?_ms2 )
		      export JAVA_OPTIONS="${JAVA_OPTIONS_MS2}"
		      export USER_MEM_ARGS="${MEM_ARGS_MS}"
		      ;;
    ico_prf_vm??_ms1 )
		      export JAVA_OPTIONS="${JAVA_OPTIONS_MS1}"
		      export USER_MEM_ARGS="${MEM_ARGS_MS}"
		      ;;
    ico_prf_vm??_ms2 )
		      export JAVA_OPTIONS="${JAVA_OPTIONS_MS2}"
		      export USER_MEM_ARGS="${MEM_ARGS_MS}"
		      ;;	      		      
	        *)
		     echo "invalid server name specified \"${SERVER_NAME}\""
		     ;;
esac


