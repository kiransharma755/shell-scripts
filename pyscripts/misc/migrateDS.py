#
# Datasource driver reconfiguration
#

# Weblogic Server Connection Details
weblogicUser = "icargo_adm"
weblogicPassword = "adm_icargo"
weblogicAdminUrl = "t3://vmh-lcag-icargo-app02-sit.lsy.fra.dlh.de:8001"

# The database details 
primary = { "user" : "ICO_OWR", "password" : "Dfg1234cvb", "url" : "jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=lx-lcag-icargo-db05-prod.lsy.fra.dlh.de)(PORT=1850)))(CONNECT_DATA=(SERVICE_NAME=PICGOPS_PROD)))" }
standby = { "user" : "ICO_OWR", "password" : "Dfg1234cvb", "url" : "jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=lx-lcag-icargo-db06-prod.lsy.fra.dlh.de)(PORT=1850)))(CONNECT_DATA=(SERVICE_NAME=PICGOPS_PROD)))" }
archive = { "user" : "ICO_ARCHIVE", "password" : "Dfg1234cvb", "url" : "jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=vmh-lcag-icargo-db08-prod.lsy.fra.dlh.de)(PORT=1850)))(CONNECT_DATA=(SERVICE_NAME=PICGARCB)))" }
reporting = { "user" : "ICO_APP_REPORT", "password" : "Dfg1234cvb", "url" : "jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=vmh-lcag-icargo-db01-prod.lsy.fra.dlh.de)(PORT=1850)))(CONNECT_DATA=(SERVICE_NAME=PICGODWH)(INSTANCE_NAME=PICGODWH)))" }

# Connection Pool details
primaryDS = ['DataSource-01', 'AsyncDataSource-01', 'TxnAudDataSource-01']
standbyDS = ['DataSource-02', 'AsyncDataSource-02', 'TxnAudDataSource-02']

connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

def doApplyDriverParams(driverParams, attribs):
   driverParams.setUrl(attribs.get('url'))
   driverParams.setPassword(attribs.get('password'))

def applyPrimaryAttribs(res):
   print "applyPrimaryAttribs : " + res.getName()
   jdbcResource = res.getJDBCResource()
   driverParams = jdbcResource.getJDBCDriverParams()
   user = driverParams.getProperties().lookupProperty('user').getValue()
   if user == 'ICO_OWR':
      doApplyDriverParams(driverParams, primary)
   else:
      doApplyDriverParams(driverParams, reporting)
   None

def applyStandabyAttribs(res):
   print "applyStandabyAttribs : " + res.getName()
   jdbcResource = res.getJDBCResource()
   driverParams = jdbcResource.getJDBCDriverParams()
   doApplyDriverParams(driverParams, standby)

def applyArchiveAttribs(res):
   print "applyArchiveAttribs : " + res.getName()
   jdbcResource = res.getJDBCResource()
   driverParams = jdbcResource.getJDBCDriverParams()
   doApplyDriverParams(driverParams, archive)


# Main block

jdbcResources = cmo.getJDBCSystemResources()
for resource in jdbcResources:
   name = resource.getName()
   if name in primaryDS:
      applyPrimaryAttribs(resource)
   elif name in standbyDS:
      applyStandabyAttribs(resource)
   elif name == 'iCargoArchiveJDBCSource':
      applyArchiveAttribs(resource)
   else:
      print "Skipping for multi DS : " + name   
  

# we are done now lets save all the work
try:
    save()
    activate(block="true")
    print "Updated datasource driver class sucessfully"
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()
