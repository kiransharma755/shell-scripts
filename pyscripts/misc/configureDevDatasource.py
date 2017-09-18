#
# Developement server datasource configuration.
#

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "weblogic"
weblogicAdminUrl = "t3://localhost:7001"

# presets
maxSyncConn=5
maxAsyncConn=3

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

jdbcResources=cmo.getJDBCSystemResources()
for resource in jdbcResources:
   jdbcResource = resource.getJDBCResource()
   connPoolParams = jdbcResource.getJDBCConnectionPoolParams()
   datasourceParams = jdbcResource.getJDBCDataSourceParams()
   if datasourceParams.getJNDINames()[0] == 'iCargoDataSource':
      connPoolParams.setMaxCapacity(maxSyncConn)
   else:
      connPoolParams.setMaxCapacity(maxAsyncConn)
   try:
      connPoolParams.setMinCapacity(0)
   except:
      pass
   connPoolParams.setInitialCapacity(0)
   connPoolParams.setCapacityIncrement(1)
   connPoolParams.setTestConnectionsOnReserve(True)
   connPoolParams.setStatementCacheSize(0)
   connPoolParams.setTestFrequencySeconds(900)
   connPoolParams.setSecondsToTrustAnIdlePoolConnection(15)
   connPoolParams.setShrinkFrequencySeconds(60)
   connPoolParams.setRemoveInfectedConnections(True)
   # XA Params
   xAParams = jdbcResource.getJDBCXAParams()
   xAParams.setKeepXaConnTillTxComplete(True)
   xAParams.setNewXaConnForCommit(False)
   xAParams.setRollbackLocalTxUponConnClose(False)
   xAParams.setXaEndOnlyOnce(True)
   xAParams.setRecoverOnlyOnce(True)
   xAParams.setXaSetTransactionTimeout(True)
   xAParams.setXaTransactionTimeout(0)


# we are done now lets save all the work
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()
