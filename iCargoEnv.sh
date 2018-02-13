#!/bin/bash

SERVER_NAME="${1}"
if [[ ${SERVER_NAME} == "" ]]; then
   echo "The script needs to be sourced with the server name as argument !"
   exit 1
fi
IS_MIN="${2}"
# to prevent duplicate entries in classpath
[[ ${IS_MIN} != "min" ]] && CLASSPATH=""

echoi "Configuring environment for ${1} server ..."

#
# Customisable Parameters
#
DOMAIN_NAME='icoebldomain'
DOMAIN_HOME="/app/icargo/${DOMAIN_NAME}"
COMMON_HOME="${DOMAIN_HOME}/user_stage/common"
IC_DOMAIN_HOME="${DOMAIN_HOME}/user_stage/live/app/iCargoConfig"
LOG_DIR="${DOMAIN_HOME}/user_stage/logs"
TMPDIR='/app/mw/logs/tmp'

# JMX Ports configuration
JMX_PORT_ADM=7099
JMX_PORT_MS1=7199
JMX_PORT_MS2=7299

#Uncomment this when debug is to enabled in the corresponding managed servers.
#ADM_DEBUG="-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=7088,server=y,suspend=n"
MS1_DEBUG="-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=7188,server=y,suspend=n"
#MS3_DEBUG="-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=7288,server=y,suspend=n"

# Addditional java argments
#MS1_EXTRA="-Xshare:off -XX:+UnlockCommercialFeatures -XX:+IgnoreEmptyClassPaths -XX:DumpLoadedClassList=${DOMAIN_HOME}/JavaClass_${DOMAIN_NAME}.clist -XX:+UseAppCDS"
export USE_ARCHIVE=true
export APPCDS_ARCHIVE="${DOMAIN_HOME}/JavaClass_${DOMAIN_NAME}.jsa"


#
# iCargo specific classpath settings
#
TIBCO_CLASSPATH="${COMMON_HOME}/lib/tibcrypt-7.0.0.jar:${COMMON_HOME}/lib/tibjms-7.0.0.jar:${COMMON_HOME}/lib/tibjmsadmin-7.0.0.jar"
ICOCLASSPATH="${COMMON_HOME}/lib/iCSecurityDependency.jar:${COMMON_HOME}/lib/mbeantypes/icSecurityProviders.jar:${COMMON_HOME}/lib/icargo-custom-log.jar:${COMMON_HOME}/lib/:${TIBCO_CLASSPATH}"

export EXT_PRE_CLASSPATH="${ICOCLASSPATH}"

OLD_JAVA_OPTIONS="${JAVA_OPTIONS}"

# DLH Specific Configurations
DLH_WLS_OPTS="-Dweblogic.security.SSL.minimumProtocolVersion=TLSv1.0 -Ddh.output.path=/app/mw/statistics/dhStats -Dweblogic.security.audit.auditLogDir=/app/mw/logs/audit -Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=${DOMAIN_HOME}/localhost.truststore -Dweblogic.security.CustomTrustKeyStoreType=JKS"

#Generic java options for all
JAVA_OPTIONS_CMN="${OLD_JAVA_OPTIONS} ${DLH_WLS_OPTS} -Dweblogic.ProductionModeEnabled=true -Djava.io.tmpdir=${TMPDIR} -Dweblogic.unicast.HttpPing=true -Dweblogic.configuration.schemaValidationEnabled=false -Djava.net.preferIPv4Stack=true -Dappserver.name=Weblogic -Dweblogic.wsee.skip.async.response=true -Djava.security.egd=file:/dev/./urandom -Dweblogic.alternateTypesDirectory=${COMMON_HOME}/lib/mbeantypes -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dcom.sun.jersey.server.impl.cdi.lookupExtensionInBeanManager=true -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dweblogic.system.BootIdentityFile=${DOMAIN_HOME}/servers/${SERVER_NAME}/security/boot.properties"

# For Admin Server - minimum profile
JAVA_OPTIONS_ADM_MIN="${JAVA_OPTIONS_CMN}"

#Generic managed server option.
JAVA_OPTIONS_MSCMN="${JAVA_OPTIONS_CMN} -Dweblogic.Name=${SERVER_NAME} -DnodeName=${SERVER_NAME} -Dicargo.environment.name=${SERVER_NAME} -Dxss.filter=true -Dicargo.csrf.guard=true -Dservice.properties=${IC_DOMAIN_HOME} -Djava.security.auth.login.config=${IC_DOMAIN_HOME}/jaas.config -DSprout_Config_Path=${IC_DOMAIN_HOME} -Dresultset.maxsize=50000 -Dicargo.uilayout=true -Dportaluserallowed=true -Dicargo.configuration=xconfig.xml -Dxibase.persistence.pageSize=25 -Djavax.xml.soap.MessageFactory=com.sun.xml.messaging.saaj.soap.ver1_1.SOAPMessageFactory1_1Impl -Denable.leak.profile=true -Dicargo.daterangecheckrequired=true -Dorg.jboss.weld.xml.disableValidating=true -Djava.endorsed.dirs=${COMMON_HOME}/lib/endorsed:${JAVA_HOME}/jre/lib/endorsed:${WL_HOME}/endorsed -Dorg.apache.cxf.Logger=org.apache.cxf.common.logging.Log4jLogger -Djava.awt.headless=true -Dpython.cachedir=${LOG_DIR}/python -Dlog4j.configuration=file:${IC_DOMAIN_HOME}/LoggerConfig.xml -Djigsaw.config=${DOMAIN_HOME}/user_stage/live/app/jigsaw/etc -Djigsaw.nodeName=${SERVER_NAME} -Dweblogic.spring.monitoring.instrumentation.disableInstrumentation=true -Dweblogic.spring.monitoring.instrumentation.disablePreClassLoader=true -Debl.bundle.ws.env=ICAPSIT"

JAVA_OPTIONS_ADM="${ADM_DEBUG} ${JAVA_OPTIONS_MSCMN} -Dcom.sun.management.jmxremote.port=${JMX_PORT_ADM} -DstartListeners=NONE -Dweblogic.management.discover=true"
JAVA_OPTIONS_MS1="${MS1_DEBUG} ${MS1_EXTRA} ${JAVA_OPTIONS_MSCMN} -Dcom.sun.management.jmxremote.port=${JMX_PORT_MS1} -DstartListeners=NONE -Dweblogic.management.discover=false" 
JAVA_OPTIONS_MS2="${MS2_DEBUG} ${JAVA_OPTIONS_MSCMN} -Dcom.sun.management.jmxremote.port=${JMX_PORT_MS2} -DstartListeners=NONE -Dweblogic.management.discover=false" 


# Memory Arguments for admin and managed server

MEM_ARGS_ADM="-Xms512M -Xmx512M -XX:+UseG1GC"
#MEM_ARGS_MS="-Xms2G -Xmx2G -XX:MaxNewSize=512M -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:+CMSPermGenSweepingEnabled -XX:PermSize=256m -XX:MaxPermSize=512M -Xloggc:${LOG_DIR}/wls/${SERVER_NAME}_GC_`date +%d%b%Y_%H%M`.log -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintHeapAtGC -XX:-UseGCOverheadLimit -XX:HeapDumpPath=${LOG_DIR}/wls/${SERVER_NAME}_heapdump_`date +%d%b%Y_%H%M`.hprof -XX:+HeapDumpOnOutOfMemoryError"
MEM_ARGS_MS="-Xms4G -Xmx4G -XX:+UnlockExperimentalVMOptions -XX:+UnlockCommercialFeatures -XX:G1NewSizePercent=50 -XX:MaxGCPauseMillis=350 -XX:-UseGCOverheadLimit -XX:+UseG1GC -XX:MetaspaceSize=1G -XX:MaxMetaspaceSize=1G -XX:+UseStringDeduplication -XX:+AlwaysPreTouch -Xloggc:${LOG_DIR}/wls/${SERVER_NAME}_GC.log -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintHeapAtGC -Xverify:none"

case ${SERVER_NAME} in
    'ico_ebl_msAdm')    
                      if [[ ${IS_MIN} == "min" ]]; then
                        export JAVA_OPTIONS="${JAVA_OPTIONS_ADM_MIN}"
                      else
                        export JAVA_OPTIONS="${JAVA_OPTIONS_ADM_MIN}"
                        export USER_MEM_ARGS="${MEM_ARGS_ADM}"
                      fi
		      ;;
    'ico_ebl_ms1' )
                      export JAVA_OPTIONS="${JAVA_OPTIONS_MS1}"
                      export USER_MEM_ARGS="${MEM_ARGS_MS}"
		      ;;
    'ico_ebl_ms2' )
		      export JAVA_OPTIONS="${JAVA_OPTIONS_MS2}"
		      export USER_MEM_ARGS="${MEM_ARGS_MS}"
		      ;;
	        *)
		     echoe "Invalid server name specified \"${SERVER_NAME}\""
		     ;;
esac


