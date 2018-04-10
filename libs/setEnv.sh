#!/bin/bash
#
# This is the common environmental settings for WebLogic
#
# Specific environmental settings should be kept on ${DOMAIN_BASE}/${DOMAIN_NAME}/${ENVSCRIPT}
#
#set -x

export WLADM_WL_HOME='/app/mw/weblogic/wlserver'
export ANT_HOME='/app/mw/weblogic/oracle_common/modules/thirdparty/org.apache.ant/1.9.8.0.0/apache-ant-1.9.8'
# set the weblogic env 
. ${WLADM_WL_HOME}/server/bin/setWLSEnv.sh > /dev/null 2>&1

# if remote dispatch of commands is required over ssh
typeset -r ENABLE_REMOTE_DISPATCH='true'

# enable piped out log file
typeset -r ENABLE_PIPED_LOG='false'

# enable shell colors
typeset -r ENABLE_COLOR='true'

# FORCESHUTDOWN - will result in rollback of current txns ( faster shutdown )
# SHUTDOWN - will give time for current txns to complete
typeset -r WLS_SHUTDOWN_CMD='FORCESHUTDOWN'

# Connect to admin server using t3s over SSL
typeset -r WLS_ADMIN_SSL='false'

# WLST startup options
export WLST_PROPERTIES='-Djava.security.egd=file:/dev/./urandom'

# Shutdown timeout
typeset -i WLS_SHUTDOWN_TIMEOUT=30000

# ps argument tool for the environment
# Use java process tool jps for displaying command line
# export WLADM_PS="${JAVA_HOME}/bin/jps -lv"

# for solaris
#WLADM_PS="/usr/ucb/ps auwwwx"
# for linux and AIX
WLADM_PS="/bin/ps auwwwx"

# environment file which has to be executed
ENV_FILE_NAME="iCargoEnv.sh"

# should the process wait till the server starts
WAIT_FOR_START="true"

# Number of times to loop while waiting for weblogic server to stop during restart (before killing)
typeset -i RESTART_STOP_LOOPTIMES=10

# Number of times to loop while waiting for weblogic server to start during restart (before giving up)
typeset -i RESTART_START_LOOPTIMES=12

# Number of seconds to wait during each tloop while waiting for weblogic server to stop during restart (before killing)
typeset -i RESTART_STOP_WAIT=3

# Number of seconds to wait during each tloop while waiting for weblogic server to start during restart (before giving up)
typeset -i RESTART_START_WAIT=30

# the delay seconds between starting muliple servers in a cluster/domain
typeset -i STARTUP_DELAY=5

# common entries for icoadmin starts
# Root directory for log of all environments. Domain specific folders will build from here
ROOT_LOG_DIR='/app/mw/logs'

# Root landing directory. Domain specific folders will build from here
ROOT_LANDING_DIR='/app/icargo/ico_root/landing'

# Root ICO_HOME directry. Domain specific folders will build from here
ROOT_ICO_HOME_DIR='/app/icargo/ico_root/app'

# Root mount where Persistent stores has to be mounted
ROOT_STORE_DIR='/app/icargo/ico_root/store'
