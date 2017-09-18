import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "webl0g!c"
weblogicAdminUrl = "t3://localhost:4000"

def setupLogConfigForInstance(managedServer):
   print 'setting log config for server ' + managedServer
   cd('/Servers/'+managedServer+'/Log/'+managedServer)
   set('FileName', 'user_stage/logs/wls/' + managedServer + '.log')
   set('FileCount', 2)
   set('FileMinSize', 51250)
   set('LoggerSeverity', 'Warning')
   set('RotateLogOnStartup', True)
   # setting the webserver access logs
   cd('/Servers/'+managedServer+'/WebServer/'+managedServer+'/WebServerLog/'+managedServer)
   set('FileCount', 1)
   set('FileMinSize', 51250)
   set('FileName', 'user_stage/logs/wls/' + managedServer + '_access.log')

def setupLogConfigForCluster():
   for managedServer in cmo.getServers():
      managedServerName = managedServer.getName()
      setupLogConfigForInstance(managedServerName)
   

print "Starting the script ..."

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

setupLogConfigForCluster()

# Lets try to save the change now ....
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()
