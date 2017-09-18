# Script for setting up datasources for iCargo
# - create iCargoDataSource, iCargoAsyncDataSource and iCargoBPMNDataSource
#

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "webl0g!c"
weblogicAdminUrl = "t3://localhost:4000"

# Database connection details
databaseUser = 'ICOBSSTGDEV4'
databasePassword = 'ICOBSSTGDEV4'
databaseJdbcUrl = 'jdbc:oracle:thin:@192.168.16.196:1522:ICODB32'
databaseDriverKlass = 'oracle.jdbc.xa.client.OracleXADataSource'


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
   



# main block starts here

print "Starting the script ..."

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

# Lets create the datasources
createGenericDataSource('iCargoAsyncDataSource', databaseUser, databasePassword, databaseJdbcUrl)
createGenericDataSource('iCargoDataSource', databaseUser, databasePassword, databaseJdbcUrl, 20)
createGenericDataSource('iCargoBPMNDataSource', databaseUser, databasePassword, databaseJdbcUrl, 5)

# Lets try to save the change now ....
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()
