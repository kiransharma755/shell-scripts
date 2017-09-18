#!/bin/bash
#
# This is the common environmental settings for WebLogic
#
# Specific environmental settings should be kept on ${DOMAIN_BASE}/${DOMAIN_NAME}/${ENVSCRIPT}
#
#set -x

export JAVA_HOME="/cellone/jdk1.7.0_75"
#export BEA_HOME="/home/bea/bea12/weblogic12"
export WLADM_WL_HOME="/cellone/Oracle/Middleware/Oracle_Home/wlserver"
export ANT_HOME="/cellone/Oracle/Middleware/Oracle_Home/oracle_common/modules/org.apache.ant_1.9.2"
# set the weblogic env 
. ${WLADM_WL_HOME}/server/bin/setWLSEnv.sh > /dev/null 2>&1

# if remote dispatch of commands is required over ssh
ENABLE_REMOTE_DISPATCH="true"

# enable piped out log file
ENABLE_PIPED_LOG="true"

# enable shell colors
ENABLE_COLOR="true"

# FORCESHUTDOWN - will result in rollback of current txns ( faster shutdown )
# SHUTDOWN - will give time for current txns to complete
WLS_SHUTDOWN_CMD='FORCESHUTDOWN'

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
RESTART_STOP_LOOPTIMES=6

# Number of times to loop while waiting for weblogic server to start during restart (before giving up)
RESTART_START_LOOPTIMES=12

# Number of seconds to wait during each tloop while waiting for weblogic server to stop during restart (before killing)
RESTART_STOP_WAIT=10

# Number of seconds to wait during each tloop while waiting for weblogic server to start during restart (before giving up)
RESTART_START_WAIT=30

# the delay seconds between starting muliple servers in a cluster/domain
STARTUP_DELAY=5

# common entries for icoadmin starts
# Root directory for log of all environments. Domain specific folders will build from here
ROOT_LOG_DIR=/cellone/logs

# Root landing directory. Domain specific folders will build from here
ROOT_LANDING_DIR=/cellone/landing

# Root ICO_HOME directry. Domain specific folders will build from here
ROOT_ICO_HOME_DIR=/cellone/ico_app

