import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "icargo_adm"
weblogicPassword = "adm_icargo"
weblogicAdminUrl = "t3://vmh-lcag-icargo-app01-test.lsy.fra.dlh.de:8001"

# Preferences not required to change
jmsModuleName='iCargoExtModule'
jmsServerPfx='JMSServer_'
jmsStorePfx='FileStore_'
# Distributed Queues Required - in case of cluster
createUDD=False
# Migratable Targets Applicable - in case of clusters
useMigratableTargets=False
# Applicable if using Oracle Exalogic Servers
enableExaLogicOptimizations=False

def resolveJmsServerName(managedServer):
   jmsServerName = jmsServerPfx + managedServer
   return jmsServerName

def resolveJmsStoreName(managedServer):
   storeName = jmsStorePfx + managedServer
   return storeName

def resolveTargetJmsServers(jmsModuleName):
   # resolution can be done wrt to module name
   targetServers=[]
   adminServerName = cmo.getAdminServerName()
   if len(cmo.getClusters()) == 0:
      jmsServerName = resolveJmsServerName(adminServerName)
      targetServers.append(jmsServerName)
   else:
      for managedServer in cmo.getServers():
         managedServerName = managedServer.getName()
         if managedServerName != adminServerName:
            jmsServerName = resolveJmsServerName(managedServerName)
            targetServers.append(jmsServerName)
   return targetServers


def getServerMBean(managedServer):
   if useMigratableTargets:
      managedServer = managedServer + " (migratable)";
      return getMBean("/MigratableTargets/" + managedServer)
   else:
      return getMBean("/Servers/" + managedServer)


def createGetJmsStore(managedServer):
   jmsStoreName = resolveJmsStoreName(managedServer)
   jmsStore = getMBean("/FileStores/" + jmsStoreName)
   if jmsStore is None:
      print "creating Jms persistent FileStore : " + jmsStoreName
      jmsStore = create(jmsStoreName, "FileStores")
      serverMBean = getServerMBean(managedServer)
      jmsStore.addTarget(serverMBean)
      jmsStore.setSynchronousWritePolicy("Cache-Flush");
      jmsStore.setDirectory("user_stage/store/" + managedServer + "/jms")
   return jmsStore


def createGetJmsServer(managedServer):
   jmsServerName = resolveJmsServerName(managedServer)
   jmsServer = getMBean("/JMSServers/" + jmsServerName)
   if jmsServer is None:
      print "creating Jms server : " + jmsServerName
      jmsServer = create(jmsServerName, "JMSServer")
      serverMBean = getServerMBean(managedServer)
      jmsServer.addTarget(serverMBean)
      jmsStore = createGetJmsStore(managedServer)
      jmsServer.setPersistentStore(jmsStore)
      if enableExaLogicOptimizations:
         jmsServer.setStoreMessageCompressionEnabled(True)
         jmsServer.setPagingMessageCompressionEnabled(True)
         jmsServer.setMessageCompressionOptions("LZF")
   return jmsServer


def createDefaultJmsServers():
   global createUDD
   global useMigratableTargets
   adminServerName = cmo.getAdminServerName()   
   if len(cmo.getClusters()) == 0:
      createUDD = False
      useMigratableTargets = False
      jmsServer = createGetJmsServer(adminServerName)
   else:
      createUDD = True
      useMigratableTargets = True
      for managedServer in cmo.getServers():
         managedServerName = managedServer.getName()
         if managedServerName != adminServerName:
            jmsServer = createGetJmsServer(managedServerName)
         
      
   


def createGetJmsModule(moduleName):
   eaiResource = getMBean("JMSSystemResources/" + moduleName)
   if eaiResource is None:
      print 'Creating JMSModule : ' + moduleName 
      eaiResource = create(moduleName,"JMSSystemResource")
      subDep = eaiResource.createSubDeployment("Target_To_Cluster")
      targetServers = resolveTargetJmsServers(moduleName)
      for jmsServer in targetServers:
         jmsServerMBean = getMBean("JMSServers/" + jmsServer)
         subDep.addTarget(jmsServerMBean)
      if len(cmo.getClusters()) == 0:
         eaiResource.setTargets(cmo.getServers())
      else:
         eaiResource.setTargets(cmo.getClusters())
   theResource = eaiResource.getJMSResource();
   return theResource


def createQueue(queue_name,jndi_name):
   print "Creating Queue : "+queue_name+"..."
   eaiResource = createGetJmsModule(jmsModuleName);
   if createUDD:
      jmsqueue = eaiResource.lookupDistributedQueue(queue_name)
   else:
      jmsqueue = eaiResource.lookupQueue(queue_name)
   if jmsqueue is None:
      if createUDD:
         jmsqueue = eaiResource.createUniformDistributedQueue(queue_name)
      else:
         jmsqueue = eaiResource.createQueue(queue_name)
   jmsqueue.setJNDIName(jndi_name)
   jmsqueue.setSubDeploymentName('Target_To_Cluster')
   deliveryFailureParams = jmsqueue.getDeliveryFailureParams()
   deliveryFailureParams.setRedeliveryLimit(1)
   deliveryFailureParams.setExpirationPolicy('Discard')
   deliveryOverrides = jmsqueue.getDeliveryParamsOverrides()
   deliveryOverrides.setDeliveryMode('Non-Persistent')
   deliveryOverrides.setRedeliveryDelay(30000)


def createWSQueue(queue_name,jndi_name):
   print "Creating WebService Queue : "+queue_name+"..."
   eaiResource = createGetJmsModule(jmsModuleName);
   if createUDD:
      jmsqueue = eaiResource.lookupDistributedQueue(queue_name)
   else:
      jmsqueue = eaiResource.lookupQueue(queue_name)
   if jmsqueue is None:
      if createUDD:
         jmsqueue = eaiResource.createUniformDistributedQueue(queue_name)
      else:
         jmsqueue = eaiResource.createQueue(queue_name)
   jmsqueue.setJNDIName(jndi_name)
   jmsqueue.setSubDeploymentName('Target_To_Cluster')
   deliveryFailureParams = jmsqueue.getDeliveryFailureParams()
   deliveryFailureParams.setRedeliveryLimit(0)
   deliveryFailureParams.setExpirationPolicy('Discard')
   deliveryOverrides = jmsqueue.getDeliveryParamsOverrides()
   deliveryOverrides.setRedeliveryDelay(30000)
   deliveryOverrides.setDeliveryMode('Non-Persistent')
   deliveryOverrides.setTimeToLive(5 * 60 * 1000) # 5 minutes


def createTopic(topicName,jndi_name):
   print "Creating Topic : "+topicName+"..."
   eaiResource = createGetJmsModule(jmsModuleName);
   if createUDD:
      jmsTopic = eaiResource.lookupDistributedTopic(topicName)
   else:
      jmsTopic = eaiResource.lookupTopic(topicName)
   if jmsTopic is None:
      if createUDD:
         jmsTopic = eaiResource.createUniformDistributedTopic(topicName)
      else:
         jmsTopic = eaiResource.createTopic(topicName)
   jmsTopic.setJNDIName(jndi_name)
   jmsTopic.setSubDeploymentName('Target_To_Cluster')
   deliveryFailureParams = jmsTopic.getDeliveryFailureParams()
   deliveryFailureParams.setRedeliveryLimit(1)
   deliveryFailureParams.setExpirationPolicy('Discard')
   deliveryOverrides = jmsTopic.getDeliveryParamsOverrides()
   deliveryOverrides.setRedeliveryDelay(30000)
   deliveryOverrides.setDeliveryMode('Non-Persistent')
   deliveryOverrides.setTimeToLive(5 * 60 * 1000) # 5 minutes

def createConnectionFactory(cnfName, jndi_name, isXA):
   print "Creating ConnectionFactory : "+cnfName+"..."
   eaiResource = createGetJmsModule(jmsModuleName);
   jmsCnf = eaiResource.lookupConnectionFactory(cnfName)
   if jmsCnf is None:
      jmsCnf = eaiResource.createConnectionFactory(cnfName)
   jmsCnf.setJNDIName(jndi_name)
   jmsCnf.setSubDeploymentName('Target_To_Cluster')
   try:
      txParams = jmsCnf.getTransactionParams()
      txParams.setXAConnectionFactoryEnabled(isXA)
   except:
      print "WARNING Enable XAConnectionFactory enabled setting manually for " + cnfName

def createiCargoJmsResources():
   # xibase stuff
   createQueue("ICGO.TIBCO.BKGENG.IN","ICGO.TIBCO.BKGENG.IN")
   createQueue("ICGO.TIBCO.CXML.IN","ICGO.TIBCO.CXML.IN")
   createQueue("ICGO.TIBCO.DCSFLTEVT.IN","ICGO.TIBCO.DCSFLTEVT.IN")
   createQueue("ICGO.TIBCO.MESX.IN","ICGO.TIBCO.MESX.IN")
   createQueue("ICGO.TIBCO.EFSU.IN","ICGO.TIBCO.EFSU.IN")
   createQueue("ICGO.TIBCO.EVTTRG.IN","ICGO.TIBCO.EVTTRG.IN")
   createQueue("ICGO.TIBCO.REGULATEDAGENTS.IN","ICGO.TIBCO.REGULATEDAGENTS.IN")
   createQueue("ICGO.TIBCO.SCALE.IN","ICGO.TIBCO.SCALE.IN")
   createQueue("ICARGO.PROCESSASM.PUB","ICARGO.PROCESSASM.PUB")
   createQueue("ICARGO.PROCESSSSM.PUB","ICARGO.PROCESSSSM.PUB")
   createQueue("ICGO.TIBCO.SMARTGATE.IN","ICGO.TIBCO.SMARTGATE.IN")
   createQueue("ICARGO.PROCESSASMEQT.PUB","ICARGO.PROCESSASMEQT.PUB")
   createQueue("ICARGO.PROCESSMVT.PUB","ICARGO.PROCESSMVT.PUB")
   createQueue("ICARGO.PROCESSYMSG.PUB","ICARGO.PROCESSYMSG.PUB")
   createQueue("ICGO.TIBCO.TRAXON.IN","ICGO.TIBCO.TRAXON.IN")
   createQueue("ICGO.TIBCO.ZABIS.IN","ICGO.TIBCO.ZABIS.IN")
   createQueue("ICGO.TIBCO.ZODIAK.IN","ICGO.TIBCO.ZODIAK.IN")




# main block starts here

print "Starting the script ..."

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()
# create the jms resources
createiCargoJmsResources()

# Lets try to save the change now ....
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
    print "[WARNING] Enable XA settings for connection factory manually !"
    print "[WARNING] Target the JMS Modules manually11 !"
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()

