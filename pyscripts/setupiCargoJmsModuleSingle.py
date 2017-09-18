import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "weblogic"
weblogicAdminUrl = "t3://localhost:7001"

# Enable if using Base impl
createWebServiceJMSQueues=True

# Preferences not required to change
jmsModuleName='iCargoModule'
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
      # target the jms module
      #for jmsServer in resolveTargetJmsServers(moduleName):
      #   jmsServerMBean=getMBean("JMSServers/" + jmsServer)
      #   #eaiResource.addTarget(jmsServerMBean)
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
   createConnectionFactory("DefaultJmsConnectionFactory", "DefaultJmsConnectionFactory", True);
   createConnectionFactory("DefaultTopicJmsConnectionFactory", "DefaultTopicJmsConnectionFactory", True);
   createConnectionFactory("DefaultNonXAConnectionFactory", "DefaultNonXAConnectionFactory", False);
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
   # WebService JMS Queues
   if createWebServiceJMSQueues:
      createWSQueue("CUSTOMER_DEFAULTS_WS_REPLY", "com.ibsplc.icargo.customer.defaults.ws.response");
      createWSQueue("SHARED_CURRENCY_WS_REPLY", "com.ibsplc.icargo.shared.currency.ws.response");
      createWSQueue("FLIGHT_OPERATION_WS_REPLY", "com.ibsplc.icargo.flight.operation.ws.response");
      createWSQueue("ADMIN_USER_WS_REPLY", "com.ibsplc.icargo.admin.user.ws.response");
      createWSQueue("CUSTOMER_DEFAULTS_WS_REQUEST", "com.ibsplc.icargo.customer.defaults.ws.request");
      createWSQueue("SHARED_CURRENCY_WS_REQUEST", "com.ibsplc.icargo.shared.currency.ws.request");
      createWSQueue("FLIGHT_OPERATION_WS_REQUEST", "com.ibsplc.icargo.flight.operation.ws.request");
      createWSQueue("ADMIN_USER_WS_REQUEST", "com.ibsplc.icargo.admin.user.ws.request");
      createWSQueue("CAPACITY_ALLOTMENT_WS_REQUEST", "com.ibsplc.icargo.capacity.allotment.ws.request");
      createWSQueue("CAPACITY_ALLOTMENT_WS_RESPONSE", "com.ibsplc.icargo.capacity.allotment.ws.response");
      createWSQueue("CAPACITY_BOOKING_WS_REQUEST", "com.ibsplc.icargo.capacity.booking.standard.ws.request");
      createWSQueue("CAPACITY_BOOKING_WS_RESPONSE", "com.ibsplc.icargo.capacity.booking.standard.ws.response");
      createWSQueue("CAPACITY_ULDBOOKING_WS_REQUEST", "com.ibsplc.icargo.capacity.booking.uldbooking.ws.request");
      createWSQueue("CAPACITY_ULDBOOKING_WS_RESPONSE", "com.ibsplc.icargo.capacity.booking.uldbooking.ws.response");
      createWSQueue("FLIGHT_CAPACITY_WS_REQUEST", "com.ibsplc.icargo.flight.capacity.external.ws.request");
      createWSQueue("FLIGHT_CAPACITY_WS_RESPONSE", "com.ibsplc.icargo.flight.capacity.external.ws.response");
      createWSQueue("OPERATIONS_SHIPMENT_EXTERNAL_WS_REQUEST", "com.ibsplc.icargo.operations.shipment.external.ws.request");
      createWSQueue("OPERATIONS_SHIPMENT_EXTERNAL_WS_RESPONSE", "com.ibsplc.icargo.operations.shipment.external.ws.response");
      createWSQueue("OPERATIONS_SHIPMENT_STANDARD_WS_REQUEST", "com.ibsplc.icargo.operations.shipment.standard.ws.request");
      createWSQueue("OPERATIONS_SHIPMENT_STANDARD_WS_RESPONSE", "com.ibsplc.icargo.operations.shipment.standard.ws.response");
      createWSQueue("FLIGHT_OPERATION_STANDARD_WS_REQUEST", "com.ibsplc.icargo.flight.operation.standard.ws.request");
      createWSQueue("FLIGHT_OPERATION_STANDARD_WS_RESPONSE", "com.ibsplc.icargo.flight.operation.standard.ws.response");
      createWSQueue("CAPACITY_BOOKING_EXTERNAL_WS_REQUEST", "com.ibsplc.icargo.capacity.booking.external.ws.request");
      createWSQueue("CAPACITY_BOOKING_EXTERNAL_WS_RESPONSE", "com.ibsplc.icargo.capacity.booking.external.ws.response");
      createWSQueue("OPERATIONS_EIP_SERVICE_REQUEST_QUEUE", "com.ibsplc.icargo.operations.shipment.external.eip.ws.request");
      createWSQueue("OPERATIONS_EIP_SERVICE_RESPONSE_QUEUE", "com.ibsplc.icargo.operations.shipment.external.eip.ws.response");
      createWSQueue("QUALITYMANAGEMENT_DEFAULTS_EXTERNAL_WS_REQUEST", "com.ibsplc.icargo.qualitymanagement.defaults.external.ws.request");
      createWSQueue("QUALITYMANAGEMENT_DEFAULTS_EXTERNAL_WS_RESPONSE", "com.ibsplc.icargo.qualitymanagement.defaults.external.ws.response");
      createWSQueue("QUALITYMANAGEMENT_DEFAULTS_REQUEST_QUEUE", "com.ibsplc.icargo.qualitymanagement.defaults.standard.ws.request");
      createWSQueue("QUALITYMANAGEMENT_DEFAULTS_RESPONSE_QUEUE", "com.ibsplc.icargo.qualitymanagement.defaults.standard.ws.response");
      createWSQueue("FLIGHT_SCHEDULE_STANDARD_WS_REQUEST", "com.ibsplc.icargo.flight.schedule.standard.ws.request");
      createWSQueue("FLIGHT_OPERATION_FLIGHTREQUEST_STANDARD_WS_REQUEST", "com.ibsplc.icargo.flight.operation.standard.ws.flightrequest");
      createWSQueue("OPERATIONS_FLTHANDLING_EXTERNAL_WS_REQUEST", "com.ibsplc.icargo.operations.flthandling.external.ws.request");
      createWSQueue("OPERATIONS_FLTHANDLING_STANDARD_WS_REQUEST", "com.ibsplc.icargo.operations.flthandling.standard.ws.request");
      createWSQueue("OPERATIONS_FLTHANDLING_STANDARD_WS_RESPONSE", "com.ibsplc.icargo.operations.flthandling.standard.ws.response");
      createWSQueue("WAREHOUSE_DEFAULTS_STANDARD_WS_REQUEST", "com.ibsplc.icargo.warehouse.defaults.standard.ws.request");
      createWSQueue("WAREHOUSE_DEFAULTS_STANDARD_WS_RESPONSE", "com.ibsplc.icargo.warehouse.defaults.standard.ws.response");
      createWSQueue("SHARED_FLIGHTRESTRICTION_WS_REQUEST", "com.ibsplc.icargo.shared.flightrestriction.standard.ws.request");
      createWSQueue("SHARED_FLIGHTRESTRICTION_WS_RESPONSE", "com.ibsplc.icargo.shared.flightrestriction.standard.ws.response");
      createWSQueue("WAREHOUSE_DEFAULTS_EXTERNAL_WS_REQUEST", "com.ibsplc.icargo.warehouse.defaults.external.ws.request");
      createWSQueue("WAREHOUSE_DEFAULTS_EXTERNAL_WS_RESPONSE", "com.ibsplc.icargo.warehouse.defaults.external.ws.response");
      createWSQueue("CAPACITY_MONITORING_WS_REQUEST", "com.ibsplc.icargo.capacity.monitoring.standard.ws.request");
      createWSQueue("CAPACITY_MONITORING_WS_RESPONSE", "com.ibsplc.icargo.capacity.monitoring.standard.ws.response");
      createWSQueue("CAPACITY_MONITORING_EXT_WS_REQUEST", "com.ibsplc.icargo.capacity.monitoring.external.ws.request");
      createWSQueue("CAPACITY_MONITORING_EXT_WS_RESPONSE", "com.ibsplc.icargo.capacity.monitoring.external.ws.response");
      createWSQueue("WAREHOUSE_DEFAULTS_EXTERNAL_EIP_WS_REQUEST", "com.ibsplc.icargo.warehouse.defaults.external.eip.ws.request");
      createWSQueue("WAREHOUSE_DEFAULTS_EXTERNAL_EIP_WS_RESPONSE", "com.ibsplc.icargo.warehouse.defaults.external.eip.ws.response");
      createWSQueue("SHARED_AIRCRAFT_WS_REQUEST", "com.ibsplc.icargo.shared.aircraft.standard.ws.request");
      createWSQueue("SHARED_AIRCRAFT_WS_RESPONSE", "com.ibsplc.icargo.shared.aircraft.standard.ws.response");
      createWSQueue("TARIFF_FREIGHT_STANDARD_WS_REQUEST", "com.ibsplc.icargo.tariff.freight.standard.ws.request");
      createWSQueue("TARIFF_FREIGHT_STANDARD_WS_RESPONSE", "com.ibsplc.icargo.tariff.freight.standard.ws.response");
      createWSQueue("SHARED_AIRLINE_WS_REQUEST", "com.ibsplc.icargo.shared.airline.standard.ws.request");
      createWSQueue("SHARED_AIRLINE_WS_RESPONSE", "com.ibsplc.icargo.shared.airline.standard.ws.response");
      createWSQueue("STOCKCONTROL_DEFAULTS_WS_REQUEST", "com.ibsplc.icargo.stockcontrol.defaults.standard.ws.request");
      createWSQueue("STOCKCONTROL_DEFAULTS_WS_RESPONSE", "com.ibsplc.icargo.stockcontrol.defaults.standard.ws.response");
      createWSQueue("SHARED_AIRPORT_WS_REQUEST", "com.ibsplc.icargo.shared.area.airport.standard.ws.request");
      createWSQueue("SHARED_AIRPORT_WS_RESPONSE", "com.ibsplc.icargo.shared.area.airport.standard.ws.response");
      createWSQueue("SHARED_COMMODITY_WS_REQUEST", "com.ibsplc.icargo.shared.commodity.standard.ws.request");
      createWSQueue("SHARED_COMMODITY_WS_RESPONSE", "com.ibsplc.icargo.shared.commodity.standard.ws.response");



# main block starts here

print "Starting the script ..."

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
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
    print "[WARNING] Enable XA settings for connection factory manually !"
    print "[WARNING] Target the JMS Modules manually11 !"
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()

