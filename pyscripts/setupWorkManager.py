# Create WorkManager

import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "weblogic"
weblogicAdminUrl = "t3://localhost:7001"


def createMaxThreadWorkManager(workManagerName, maxThreads):
   cd('/')
   domainName = cmo.getName()
   workMBean = getMBean('/SelfTuning/' + domainName + '/WorkManagers/' + workManagerName)
   if workMBean is not None:
      print 'WorkManager ' + workManagerName + ' present.'
      return
   cd('/SelfTuning/' + domainName + '/WorkManagers')
   workMBean = cmo.createWorkManager(workManagerName)
   cd('/')
   adminServerName = cmo.getAdminServerName()
   if len(cmo.getClusters()) == 0:
      workMBean.setTargets(cmo.getServers())
   else:
      workMBean.setTargets(cmo.getClusters())
   
   cd('/SelfTuning/' + domainName + '/WorkManagers')
   maxWorkMBean = cmo.createMaxThreadsConstraint(workManagerName + '.maxThreadConstraint')
   maxWorkMBean.setCount(maxThreads)
   maxWorkMBean.setTargets(workMBean.getTargets())
   workMBean.setMaxThreadsConstraint(maxWorkMBean)
   print 'maxThreadConstraintWorkManager Created : ' + workManagerName
   

# Main Block
connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

createMaxThreadWorkManager('AdviceQueueWorkManager', 5)
createMaxThreadWorkManager('AuditQueueWorkManager', 5)
createMaxThreadWorkManager('EventQueueWorkManager', 5)
createMaxThreadWorkManager('AsyncQueueWorkManager', 5)
createMaxThreadWorkManager('ConcurrentDispatchWorkManager', 5)
createMaxThreadWorkManager('wm/ExcelExportManager', 5)

# Lets try to save the change now ....
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()
