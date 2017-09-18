#
# WebLogic domain setup python script
# @Author : Jens J P : 15-May-2015
#

import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "webl0g!c"
weblogicAdminUrl = "t3://localhost:7001"

# Enable if using Base impl
createWebServiceJMSQueues=True


# Database configurations
databaseUser = 'ICO_READ_ICAPSIT'
databasePassword = 'Dfg1234cvb'
databaseJdbcUrl = 'jdbc:oracle:thin:@57.20.86.162:1850:XICGARCB'
databaseDriverKlass = 'oracle.jdbc.xa.client.OracleXADataSource'

# Root folders for all logs
LOG_ROOT='/data/logs'

# ----------------------- Not required to be edited ----------------------- #
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

# ----------------------- jms configurations ------------------------- #

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
      createWSQueue("ADMIN_DEFAULTS_WS_REQUEST", "com.ibsplc.icargo.admin.defaults.ws.request");
      createWSQueue("ADMIN_DEFAULTS_WS_RESPONSE", "com.ibsplc.icargo.admin.defaults.ws.response");
      createWSQueue("SHARED_DEFAULTS_WS_REQUEST", "com.ibsplc.icargo.shared.defaults.standard.ws.request");
      createWSQueue("SHARED_DEFAULTS_WS_RESPONSE", "com.ibsplc.icargo.shared.defaults.standard.ws.response");
      createWSQueue("SHARED_SCC_WS_REQUEST", "com.ibsplc.icargo.shared.scc.standard.ws.request");
      createWSQueue("SHARED_SCC_WS_RESPONSE", "com.ibsplc.icargo.shared.scc.standard.ws.response");
      createWSQueue("SHARED_CUSTOMER_WS_REQUEST", "com.ibsplc.icargo.shared.customer.standard.ws.request");
      createWSQueue("SHARED_CUSTOMER_WS_RESPONSE", "com.ibsplc.icargo.shared.customer.standard.ws.response");
      createWSQueue("TARIFF_OTHERS_WS_REQUEST", "com.ibsplc.icargo.tariff.others.standard.ws.request");
      createWSQueue("TARIFF_OTHERS_WS_RESPONSE", "com.ibsplc.icargo.tariff.others.standard.ws.response");
      createWSQueue("CAPACITY_BOOKING_LHEXTMIS_WS_REQUEST", "com.ibsplc.icargo.capacity.booking.external.lhmis.ws.request");
      createWSQueue("CAPACITY_BOOKING_LHEXTMIS_WS_RESPONSE", "com.ibsplc.icargo.capacity.booking.external.lhmis.ws.response");
      createWSQueue("ADDONS_ETRACKING_EXT_WS_REQUEST", "com.ibsplc.icargo.addons.etracking.external.ws.request");
      createWSQueue("ADDONS_ETRACKING_EXT_WS_RESPONSE", "com.ibsplc.icargo.addons.etracking.external.ws.response");
      createWSQueue("PRODUCT_DEFAULTS_EXT_WS_REQUEST", "com.ibsplc.icargo.products.defaults.external.ws.request");
      createWSQueue("PRODUCT_DEFAULTS_EXT_WS_RESPONSE", "com.ibsplc.icargo.products.defaults.external.ws.response");
      createWSQueue("CAPACITY_BOOKING_EXT_LHPORTAL_WS_REQUEST", "com.ibsplc.icargo.capacity.booking.external.lhportal.ws.request");
      createWSQueue("CAPACITY_BOOKING_EXT_LHPORTAL_WS_RESPONSE", "com.ibsplc.icargo.capacity.booking.external.lhportal.ws.response");
      createWSQueue("ADDONS_SOCO_EXT_WS_REQUEST", "com.ibsplc.icargo.addons.solutionconfigurator.external.ws.request");
      createWSQueue("ADDONS_SOCO_EXT_WS_RESPONSE", "com.ibsplc.icargo.addons.solutionconfigurator.external.ws.response");
      createWSQueue("ADDONS_RECO_EXT_WS_REQUEST", "com.ibsplc.icargo.reco.defaults.external.ws.request");
      createWSQueue("ADDONS_RECO_EXT_WS_RESPONSE", "com.ibsplc.icargo.reco.defaults.external.ws.response");
      createWSQueue("CAPACITY_BOOKING_XADDONS_EXT_WS_REQUEST", "com.ibsplc.icargo.xaddons.capacity.booking.external.lh.ws.request");
      createWSQueue("CAPACITY_BOOKING_XADDONS_EXT_WS_RESPONSE", "com.ibsplc.icargo.xaddons.capacity.booking.external.lh.ws.response");
      createWSQueue("ADDONS_CUSTOMEROFFER_EXT_WS_REQUEST", "com.ibsplc.icargo.addons.customeroffer.external.ws.request");
      createWSQueue("ADDONS_CUSTOMEROFFER_EXT_WS_RESPONSE", "com.ibsplc.icargo.addons.customeroffer.external.ws.response");


# ------------- datasource configuration --------------- #

def createGenericDataSource(dsName, user, password, url, maxConnections=15):
   datasourceDS = getMBean("JDBCSystemResources/" + dsName)
   if datasourceDS is None:
      datasourceDS = create(dsName, "JDBCSystemResource")
   else:
      delete(dsName,'JDBCSystemResource')
      datasourceDS = create(dsName, "JDBCSystemResource")
   datasourceDS.setName(dsName)
   datasource = datasourceDS.getJDBCResource()
   datasource.setName(dsName)
   dataSourceParams = datasource.getJDBCDataSourceParams()
   dataSourceParams.setGlobalTransactionsProtocol('TwoPhaseCommit')
   dataSourceParams.setJNDINames(jarray.array([String( dsName )], String))
   # Connection Pool 
   connPoolParams = datasource.getJDBCConnectionPoolParams();
   connPoolParams.setMaxCapacity(maxConnections)
   connPoolParams.setMinCapacity(1)
   connPoolParams.setInitialCapacity(1)
   connPoolParams.setCapacityIncrement(1)
   connPoolParams.setTestConnectionsOnReserve(True)
   connPoolParams.setTestTableName('SQL SELECT 1 FROM DUAL')
   connPoolParams.setStatementCacheSize(0)
   connPoolParams.setTestFrequencySeconds(900)
   connPoolParams.setSecondsToTrustAnIdlePoolConnection(15)
   connPoolParams.setShrinkFrequencySeconds(600)
   connPoolParams.setRemoveInfectedConnections(True)
   # Driver Config
   driverParams = datasource.getJDBCDriverParams()
   driverParams.setUrl(url)
   driverParams.setPassword(password)
   driverParams.setDriverName(databaseDriverKlass)
   driverParams.setUseXaDataSourceInterface(True)
   driverParams.getProperties().createProperty('user',user)
   # XA Parameters
   xAParams = datasource.getJDBCXAParams()
   xAParams.setKeepXaConnTillTxComplete(True)
   xAParams.setNewXaConnForCommit(False)
   xAParams.setRollbackLocalTxUponConnClose(False)
   xAParams.setXaEndOnlyOnce(True)
   xAParams.setRecoverOnlyOnce(True)
   xAParams.setXaSetTransactionTimeout(True)
   xAParams.setXaTransactionTimeout(0)
   # Target the datasource
   if len(cmo.getClusters()) == 0:
      datasourceDS.setTargets(cmo.getServers())
   else:
      datasourceDS.setTargets(cmo.getClusters())
   

# -------------- security configuration ------------- #

def fixDefaultSecurityConfiguration():
   cd('/')
   securityConfiguration = cmo.getSecurityConfiguration()
   realm = securityConfiguration.lookupRealm('myrealm')
   authenticator = realm.lookupAuthenticationProvider('DefaultAuthenticator')
   authenticator.setControlFlag('SUFFICIENT')
   domainName = cmo.getName()
   xacmlAuthorizer = getMBean('/SecurityConfiguration/' + domainName + '/Realms/myrealm/Authorizers/XACMLAuthorizer')
   if xacmlAuthorizer is not None:
      realm.destroyAuthorizer(xacmlAuthorizer)
   

def createAuthenticator(authName, authClass, isIdentityAsserter=False):
   cd('/')
   domainName = cmo.getName()
   authMBean = getMBean('/SecurityConfiguration/' + domainName + '/Realms/myrealm/AuthenticationProviders/' + authName)
   if authMBean is None:
      securityConfiguration = cmo.getSecurityConfiguration()
      realm = securityConfiguration.lookupRealm('myrealm')
      authMBean = realm.createAuthenticationProvider(authName, authClass)
      if not isIdentityAsserter:
         authMBean.setControlFlag('SUFFICIENT')
      

def createAuthorizer(authName, authClass):
   cd('/')
   domainName = cmo.getName()
   authorizer = getMBean('/SecurityConfiguration/' + domainName + '/Realms/myrealm/Authorizers/' + authName)
   if authorizer is None:
      # Configure iCargo Authorizer
      securityConfiguration = cmo.getSecurityConfiguration()
      realm = securityConfiguration.lookupRealm('myrealm')
      realm.createAuthorizer(authName, authClass);


# -------------- JTA Configurations -------------------- #

def applyJTASettings():
   cd('/JTA/' + domainName)
   cmo.setTimeoutSeconds(300)
   cmo.setAbandonTimeoutSeconds(1800)
   cmo.setForgetHeuristics(True)
   cmo.setParallelXAEnabled(True)
   cmo.setTwoPhaseEnabled(True)


# ------------------- weblogic logging configuration -------------- #

def setupLogConfigForInstance(managedServer):
   cd('/')
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
   

# ------------------- work manager configurations -------------- #

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
   

#
# Main block 
#

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

print '--------- Configuring JMS ---------'
# create the default jms servers and file stores
createDefaultJmsServers()

# create the jms resources
createiCargoJmsResources()

print '--------- Configuring JDBC ---------'
# Lets create the datasources
createGenericDataSource('iCargoAsyncDataSource', databaseUser, databasePassword, databaseJdbcUrl)
createGenericDataSource('iCargoDataSource', databaseUser, databasePassword, databaseJdbcUrl, 20)
createGenericDataSource('iCargoBPMNDataSource', databaseUser, databasePassword, databaseJdbcUrl, 5)

print '--------- Configuring JAAS ---------'
# Security
#createAuthenticator('iCargoAuthenticator','com.ibsplc.icargo.framework.security.weblogic.providers.ICargoAuthenticator')
#createAuthenticator('iCargoSSOAuthenticator','com.ibsplc.icargo.framework.security.weblogic.providers.sso.ICargoSSOAuthenticator')
#createAuthenticator('iCargoSystemAuthenticator','com.ibsplc.icargo.framework.security.weblogic.providers.ICargoSystemAuthenticator')
#createAuthenticator('iCargoSSOIdentityAsserter','com.ibsplc.icargo.framework.security.weblogic.providers.sso.iCargoSSOIdentityAsserter', True)
#createAuthenticator('iCargoIdentityAsserter','com.ibsplc.icargo.framework.security.weblogic.providers.identityassertion.ICargoIdentityAsserter', True)
#createAuthorizer('iCargoAuthorizer', 'com.ibsplc.icargo.framework.security.weblogic.providers.ICargoAuthorizer')

#fixDefaultSecurityConfiguration()

print '--------- Configuring JTA ---------'
applyJTASettings()

print '--------- Configuring WLS WorkManagers ---------'
createMaxThreadWorkManager('AdviceQueueWorkManager', 5)
createMaxThreadWorkManager('AuditQueueWorkManager', 5)
createMaxThreadWorkManager('EventQueueWorkManager', 5)
createMaxThreadWorkManager('AsyncQueueWorkManager', 5)
createMaxThreadWorkManager('ConcurrentDispatchWorkManager', 5)
createMaxThreadWorkManager('wm/ExcelExportManager', 5)
print '--------- Configuring WLS Logs ---------'
#setupLogConfigForCluster()

# we are done now lets save all the work
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()

