#
# WebLogic domain setup python script
# @Author : Jens J P : 15-May-2015
#

import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "icargo_adm"
weblogicPassword = "ix+oo3Aes0wo"
weblogicAdminUrl = "t3://vmh-lcag-icargo-app03-test.lsy.fra.dlh.de:7000"

LOG_ROOT='user_stage/logs'

def setupLogConfigForInstance(managedServer):
   cd('/')
   adminServerName = cmo.getAdminServerName()
   if managedServer == adminServerName:
      return
   print 'setting log config for server ' + managedServer
   domainName = cmo.getName()
   logRoot = LOG_ROOT + '/' + domainName + '/wls/'
   cd('/Servers/' + managedServer + '/Log/' + managedServer)
   set('FileName', logRoot + managedServer + '.log')
   set('FileCount', 2)
   set('FileMinSize', 51250)
   set('LoggerSeverity', 'Warning')
   set('RotateLogOnStartup', True)
   # setting the webserver access logs
   cd('/Servers/' + managedServer + '/WebServer/' + managedServer + '/WebServerLog/' + managedServer)
   set('FileCount', 1)
   set('FileMinSize', 51250)
   set('FileName', logRoot + managedServer + '_access.log')


def setupLogConfigForCluster():
   cd('/')
   for managedServer in cmo.getServers():
      managedServerName = managedServer.getName()
      setupLogConfigForInstance(managedServerName)
   

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

setupLogConfigForCluster()

# we are done now lets save all the work
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()
