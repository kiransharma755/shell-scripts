import sys
from java.lang import System

user_name="system"
password="webl0g!c"
admin_url="t3://localhost:7001"
jmsModuleName="iCargoModule"
               
managedServers={ "ico_prf_vm1_ms1" : "vm1ms1" ,
	         "ico_prf_vm1_ms2" : "vm1ms2" ,
	         "ico_prf_vm2_ms1" : "vm2ms1" ,
	         "ico_prf_vm2_ms2" : "vm2ms2" ,
	         "ico_prf_vm3_ms1" : "vm3ms1" ,
	         "ico_prf_vm3_ms2" : "vm3ms2" ,
	         "ico_prf_vm4_ms1" : "vm4ms1" ,
	         "ico_prf_vm4_ms2" : "vm4ms2" ,
	         "ico_prf_vm5_ms1" : "vm5ms1" ,
	         "ico_prf_vm5_ms2" : "vm5ms2" ,
	         "ico_prf_vm6_ms1" : "vm6ms1" ,
	         "ico_prf_vm6_ms2" : "vm6ms2" ,
	         "ico_prf_vm7_ms1" : "vm7ms1" ,
	         "ico_prf_vm7_ms2" : "vm7ms2" ,
	         "ico_prf_vm8_ms1" : "vm8ms1" ,
	         "ico_prf_vm8_ms2" : "vm8ms2" ,
	         "ico_prf_vm9_ms1" : "vm9ms1" ,
	         "ico_prf_vm9_ms2" : "vm9ms2" ,
	         "ico_prf_vm10_ms1" : "vm10ms1" ,
	         "ico_prf_vm10_ms2" : "vm10ms2" ,
	         "ico_prf_vm11_ms1" : "vm11ms1" ,
	         "ico_prf_vm11_ms2" : "vm11ms2" ,
	         "ico_prf_vm12_ms1" : "vm12ms1" ,
	         "ico_prf_vm12_ms2" : "vm12ms2" ,
	         "ico_prf_vm13_ms1" : "vm13ms1" ,
	         "ico_prf_vm13_ms2" : "vm13ms2"
	      }   


jmsServerPfx="JMSServer_"
jmsStorePfx="FileStore_"
createUDD=True
useMigratableTargets=True
enableExaLogicOptimizations=True

def resolveJmsServerName(managedServer):
   shortName = managedServers[managedServer]
   jmsServerName = jmsServerPfx + shortName
   return jmsServerName

def resolveJmsStoreName(managedServer):
   shortName = managedServers[managedServer]
   storeName = jmsStorePfx + shortName
   return storeName

def resolveTargetJmsServers(jmsModuleName):
   # resolution can be done wrt to module name
   targetServers=[]
   for managedServer in managedServers.keys():
      jmsServerName = resolveJmsServerName(managedServer)
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
      jmsStore.setDirectory("servers/" + managedServer + "/data/store/" + jmsStoreName)
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
   for managedServer in managedServers.keys():
      jmsServer = createGetJmsServer(managedServer)
   


def createGetJmsModule(moduleName):
   eaiResource = getMBean("JMSSystemResources/" + moduleName)
   if eaiResource is None:
      print 'Creating ' + jmsModuleName + '...'
      eaiResource = create(moduleName,"JMSSystemResource")
      # target the jms module
      #for jmsServer in resolveTargetJmsServers(moduleName):
      #   jmsServerMBean=getMBean("JMSServers/" + jmsServer)
      #   #eaiResource.addTarget(jmsServerMBean)
      subDep = eaiResource.createSubDeployment("Target_To_Cluster")
      for jmsServer in resolveTargetJmsServers(moduleName):
         jmsServerMBean=getMBean("JMSServers/" + jmsServer)
         subDep.addTarget(jmsServerMBean)
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
   deliveryFailureParams.setRedeliveryLimit(3)
   deliveryFailureParams.setExpirationPolicy('Discard')
   deliveryOverrides = jmsqueue.getDeliveryParamsOverrides()
   deliveryOverrides.setRedeliveryDelay(30000)


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
   deliveryFailureParams.setRedeliveryLimit(3)
   deliveryFailureParams.setExpirationPolicy('Discard')
   deliveryOverrides = jmsTopic.getDeliveryParamsOverrides()
   deliveryOverrides.setRedeliveryDelay(30000)

def createConnectionFactory(cnfName, jndi_name, isXA):
   print "Creating ConnectionFactory : "+cnfName+"..."
   eaiResource = createGetJmsModule(jmsModuleName);
   jmsCnf = eaiResource.lookupConnectionFactory(cnfName)
   if jmsCnf is None:
      jmsCnf = eaiResource.createConnectionFactory(cnfName)
   jmsCnf.setJNDIName(jndi_name)
   jmsCnf.setSubDeploymentName('Target_To_Cluster')
   print "[WARNING] enable XA settings for connection factory manually !"
   #jmsCnf.getTransactionParams().setXAConnectionFactoryEnabled(isXA)

def createiCargoJmsResources():
   createConnectionFactory("DefaultJmsConnectionFactory", "DefaultJmsConnectionFactory", true);
   createConnectionFactory("DefaultTopicJmsConnectionFactory", "DefaultTopicJmsConnectionFactory", true);
   createTopic("iCargoAutoRefreshTopic", "com.ibsplc.icargo.autorefresh.Topic");
   createTopic("iCargoAlertPaneTopic", "com.ibsplc.icargo.alert.Topic");
   createTopic("iCargoAppClientLoginBroadcastTopic", "com.ibsplc.icargo.iCargoAppClientLoginBroadcastTopic");
   createTopic("XIBASE_EHCACHE_BROADCAST_TOPIC", "com.ibsplc.xibase.ehcache.BroadCastTopic");
   # xibase stuff
   createQueue("XIBASE_TX_AUDIT_QUEUE", "com.ibsplc.xibase.txAudit.AuditQueue");
   createQueue("XIBASE_ASYNC_QUEUE", "com.ibsplc.xibase.framework.async.ConcurrentQueue");
   createQueue("XIBASE_ASYNC_SEQUENCED_QUEUE", "com.ibsplc.xibase.framework.async.SequencedQueue");
   createQueue("XIBASE_ASYNC_ERROR_QUEUE", "com.ibsplc.xibase.framework.async.ErrorQueue");
   createQueue("XIBASE_EVENT_QUEUE", "com.ibsplc.xibase.event.EventHandlerQueue");
   createQueue("XIBASE_ADVICE_QUEUE", "com.ibsplc.xibase.advice.AdviceHandlerQueue");
   createQueue("XIBASE_EVENT_LISTENER_QUEUE", "com.ibsplc.icargo.framework.event.queue");
   createQueue("ICARGO_NORMAL_REPORT_QUEUE", "com.ibsplc.icargo.framework.report.NormalReportQueue");
   # msgbroker stuff
   createQueue("MSGBROKER_OUTGOING_QUEUE", "com.ibsplc.icargo.msgbroker.message.OutgoingMessageQueue");
   createQueue("MSGBROKER_RETRY_QUEUE", "com.ibsplc.icargo.msgbroker.message.MessageRetryQueue");
   createQueue("MSGBROKER_INCOMING_QUEUE", "icargo.eai.IncomingMessageQueue");
   createQueue("MSGBROKER_INCOMING_SEQ_QUEUE", "icargo.eai.sequenced.IncomingMessageQueue");
   createQueue("MSGBROKER_OUTGOING_WEBSERVICE_QUEUE", "com.ibsplc.icargo.msgbroker.message.WebserviceMessageQueue");
   createQueue("MSGBROKER_ASYNC_QUEUE", "com.ibsplc.xibase.msgbroker.async.ConcurrentQueue");
   createQueue("SOAP_OVER_JMS_INCOMING_QUEUE", "com.ibsplc.icargo.webservice.async.incoming.SOAPOverJMSQueue");
   createQueue("CUSTOM_EAI_MESSAGE_QUEUE", "com.ibsplc.icargo.framework.eai.CustomMessageQueue");
   createQueue("CUSTOMS_PENDINGMESSAGE_QUEUE", "com.ibsplc.icargo.customs.message.PendingMessageQueue");
   # module audits
   createQueue("ACCOUNTING_AUDIT_QUEUE", "com.ibsplc.xibase.accounting.audit");
   createQueue("ADMIN_AUDIT_QUEUE", "com.ibsplc.xibase.admin.audit");
   createQueue("CAPACITY_AUDIT_QUEUE", "com.ibsplc.xibase.capacity.audit");
   createQueue("CAP_AUDIT_QUEUE", "com.ibsplc.xibase.cap.audit");
   createQueue("CASHIERING_AUDIT_QUEUE", "com.ibsplc.xibase.cashiering.audit");
   createQueue("CLAIMS_AUDIT_QUEUE", "com.ibsplc.xibase.claims.audit");
   createQueue("COURIER_AUDIT_QUEUE", "com.ibsplc.xibase.courier.audit");
   createQueue("CUSTOMS_AUDIT_QUEUE", "com.ibsplc.xibase.customs.audit");
   createQueue("FLIGHT_AUDIT_QUEUE", "com.ibsplc.xibase.flight.audit");
   createQueue("MAILTRACKING_AUDIT_QUEUE", "com.ibsplc.xibase.mailtracking.audit");
   createQueue("MSGBROKER_AUDIT_QUEUE", "com.ibsplc.xibase.msgbroker.audit");
   createQueue("OPERATIONS_AUDIT_QUEUE", "com.ibsplc.xibase.operations.audit");
   createQueue("PRODUCTS_AUDIT_QUEUE", "com.ibsplc.xibase.products.audit");
   createQueue("SALES_AUDIT_QUEUE", "com.ibsplc.xibase.sales.audit");
   createQueue("SHARED_AUDIT_QUEUE", "com.ibsplc.xibase.shared.audit");
   createQueue("SLAM_AUDIT_QUEUE", "com.ibsplc.xibase.slam.audit");
   createQueue("STOCKCONTROL_AUDIT_QUEUE", "com.ibsplc.xibase.stockcontrol.audit");
   createQueue("TARIFF_AUDIT_QUEUE", "com.ibsplc.xibase.tariff.audit");
   createQueue("TRACING_AUDIT_QUEUE", "com.ibsplc.xibase.tracing.audit");
   createQueue("TRACKING_AUDIT_QUEUE", "com.ibsplc.xibase.tracking.audit");
   createQueue("ULD_AUDIT_QUEUE", "com.ibsplc.xibase.uld.audit");
   createQueue("WAREHOUSE_AUDIT_QUEUE", "com.ibsplc.xibase.warehouse.audit");
   createQueue("WORKFLOW_AUDIT_QUEUE", "com.ibsplc.xibase.workflow.audit");
   createQueue("CRA_AUDIT_QUEUE", "com.ibsplc.xibase.cra.audit");
   createQueue("JOBSCHEDULER_AUDIT_QUEUE", "com.ibsplc.xibase.jobscheduler.audit");
   createQueue("REVENUE_AUDIT_QUEUE", "com.ibsplc.xibase.revenue.audit");
   createQueue("CUSTOMERMANAGEMENT_AUDIT_QUEUE", "com.ibsplc.xibase.customermanagement.audit");
   createQueue("RECO_AUDIT_QUEUE", "com.ibsplc.xibase.reco.audit");

# main block starts here

print "Starting the script ..."

connect(user_name,password,admin_url)
edit()
startEdit()

# create the default jms servers and file stores
createDefaultJmsServers()

# create the jms resources
createiCargoJmsResources()

# Lets try to save the change now ....
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()



