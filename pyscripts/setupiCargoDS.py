from java.io import FileInputStream
 
propInputStream = FileInputStream("details.properties")
configProps = Properties()
configProps.load(propInputStream)
 
domainName=configProps.get("domain.name")
adminURL=configProps.get("admin.url")
adminUserName=configProps.get("admin.userName")
adminPassword=configProps.get("admin.password")
 
dsName=configProps.get("datasource.name")
dsDatabaseName=configProps.get("datasource.database.name")
datasourceTarget=configProps.get("datasource.target")
dsJNDIName=configProps.get("datasource.jndiname")
dsDriverName=configProps.get("datasource.driver.class")
dsURL=configProps.get("datasource.url")
dsUserName=configProps.get("datasource.username")
dsPassword=configProps.get("datasource.password")
dsTestQuery=configProps.get("datasource.test.query")
 
connect(adminUserName, adminPassword, adminURL)
edit()
startEdit()
cd('/')

cmo.createJDBCSystemResource(dsName)
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName)
cmo.setName(dsName) 
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCDataSourceParams/' + dsName )
set('JNDINames',jarray.array([String('jdbc/' + dsName )], String)) 
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCDriverParams/' + dsName )
cmo.setUrl(dsURL)
cmo.setDriverName( dsDriverName )
cmo.setPassword(dsPassword)
 
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCConnectionPoolParams/' + dsName )
cmo.setTestTableName(dsTestQuery)
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCDriverParams/' + dsName + '/Properties/' + dsName )
cmo.createProperty('user')
 
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCDriverParams/' + dsName + '/Properties/' + dsName + '/Properties/user')
cmo.setValue(dsUserName)
 
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCDriverParams/' + dsName + '/Properties/' + dsName )
cmo.createProperty('databaseName')
 
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCDriverParams/' + dsName + '/Properties/' + dsName + '/Properties/databaseName')
cmo.setValue(dsDatabaseName)
 
cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName + '/JDBCDataSourceParams/' + dsName )
cmo.setGlobalTransactionsProtocol('OnePhaseCommit')
 
cd('/SystemResources/' + dsName )
set('Targets',jarray.array([ObjectName('com.bea:Name=' + datasourceTarget + ',Type=Server')], ObjectName))
 
--------------------------------------

cd('/')
create('myDataSource', 'JDBCSystemResource')
cd('JDBCSystemResource/myDataSource/JdbcResource/myDataSource')
create('myJdbcDriverParams','JDBCDriverParams')
cd('JDBCDriverParams/NO_NAME_0')
set('DriverName','com.pointbase.jdbc.jdbcUniversalDriver')
set('URL','jdbc:pointbase:server://localhost/demo')

set('PasswordEncrypted', 'PBPUBLIC')
set('UseXADataSourceInterface', 'false')
create('myProps','Properties')
cd('Properties/NO_NAME_0')
create('user', 'Property')
cd('Property/user')
cmo.setValue('PBPUBLIC')

cd('/JDBCSystemResource/myDataSource/JdbcResource/myDataSource')
create('myJdbcDataSourceParams','JDBCDataSourceParams')
cd('JDBCDataSourceParams/NO_NAME_0')
set('JNDIName', java.lang.String("myDataSource_jndi"))

cd('/JDBCSystemResource/myDataSource/JdbcResource/myDataSource')
create('myJdbcConnectionPoolParams','JDBCConnectionPoolParams')
cd('JDBCConnectionPoolParams/NO_NAME_0')
set('TestTableName','SYSTABLES')

Target the resources.

cd('/')
assign('JDBCSystemResource', 'myDataSource', 'Target', 'AdminServer')

--------------------------------------------


from java.lang import Exception
from jarray import array
from com.bea.plateng.domain.script.jython import WLSTException
import re


class SkipConfError(Exception):
  def __init__(self, msg):
    self.msg = msg

  def __str__(self):
    return repr(self.msg)

class OracleRAC:
  instance = None
  
  def __init__(self):
    try:
      self.sid = oracle_rac_sid
    except NameError, ne:
      raise SkipConfError, "Oracle RAC disabled, skipping. "

    print "Re-configuring data sources to target Oracle RAC: " + self.sid
    self.initClusterSize()
    self.vips=[]
    self.ports=[]
    self.sids=[]
    for i in range(self.size):
      index = i + 1
      self.vips.append( eval("oracle_rac_vip_" + str(index)) )
      self.ports.append( eval("oracle_rac_port_" + str(index)) )
      self.sids.append( eval("oracle_rac_sid_" + str(index)) )
    self.initDriverURL()
    self.xa_driver = oracle_xa_driver
    self.nonxa_driver = oracle_nonxa_driver
    OracleRAC.instance = self
    
  def initClusterSize(self):
    self.size = 0
    while true:
      try:
        eval('oracle_rac_vip_' + str(self.size+1))
        self.size += 1
      except NameError:
        return

  def initDriverURL(self):
    self.driver_url = 'jdbc:oracle:thin:@(DESCRIPTION =(ADDRESS_LIST ='
    for i in range(self.getSize()):
      self.driver_url += '(ADDRESS = (PROTOCOL = TCP)(HOST = ' + self.vips[i] + ')(PORT = ' + self.ports[i] + '))'
    self.driver_url += '(FAILOVER=on)(LOAD_BALANCE=load_balancing_var))(CONNECT_DATA =(SERVER = DEDICATED)(SERVICE_NAME = ' + self.sid + ')))'
    
  def getSize(self):
    if self.size < 0:
      self.initClusterSize()
    return self.size
    
  def getDriverDSURL(self, loadbal):
    return self.driver_url.replace('load_balancing_var',loadbal)
      
  def getMultiDSURL(self, node):
    index = node - 1
    return 'jdbc:oracle:thin:@'+ self.vips[index] +':'+ self.ports[index] +':'+ self.sids[index]

    
class DataSource:
  
  def __init__(self, dsName, user, passwd):
    self.dsName = dsName
    self.user = user
    self.passwd = passwd
    
    cd('/JDBCSystemResource/' + dsName + '/JdbcResource/' + dsName + '/JDBCDataSourceParams/NO_NAME_0')
    jarray_jndi_names=get('JNDINames')
    self.jndi_names=[]
    for jname in jarray_jndi_names:
      self.jndi_names.append(jname)

  def deleteDataSource(self, dsName):
    try:
      WLDomain.instance.all_datasources.index(dsName)
      cd('/')
      print "Deleting datasource: " + dsName
      delete(dsName,'JDBCSystemResource')
      print dsName + " deleted!"
    except ValueError:
      print dsName + " does not exist!"
    
    
  def createPhysicalDataSource(self, dsName, jndiName, xaProtocol, url, xa_driver, user, passwd):
    print 'Creating Physical DataSource ' + dsName 
    self.deleteDataSource(dsName)
      
    cd('/')
    
    sysRes = create(dsName, "JDBCSystemResource")  
    
    cd('/JDBCSystemResource/' + dsName + '/JdbcResource/' + dsName)
    dataSourceParams=create('dataSourceParams','JDBCDataSourceParams')
    dataSourceParams.setGlobalTransactionsProtocol(xaProtocol)
    cd('JDBCDataSourceParams/NO_NAME_0')
    print "Setting JNDI Names: " 
    print jndiName
    set('JNDIName',jndiName)
    
    cd('/JDBCSystemResource/' + dsName + '/JdbcResource/' + dsName)
    connPoolParams=create('connPoolParams','JDBCConnectionPoolParams')
    connPoolParams.setMaxCapacity(20)
    connPoolParams.setInitialCapacity(5)
    connPoolParams.setCapacityIncrement(1)
    connPoolParams.setTestConnectionsOnReserve(true)
    connPoolParams.setTestTableName('SQL SELECT 1 FROM DUAL')
    
    cd('/JDBCSystemResource/' + dsName + '/JdbcResource/' + dsName)
    driverParams=create('driverParams','JDBCDriverParams')
    driverParams.setUrl(url)
    if xa_driver == "true":
      driverParams.setDriverName(OracleRAC.instance.xa_driver)
    else:
      driverParams.setDriverName(OracleRAC.instance.nonxa_driver)
    driverParams.setPasswordEncrypted(passwd)
    cd('JDBCDriverParams/NO_NAME_0')
    create(dsName,'Properties')
    cd('Properties/NO_NAME_0')
    create('user', 'Property')
    cd('Property/user')
    cmo.setValue(user)
    
    if xaProtocol != "None":
      cd('/JDBCSystemResource/' + dsName + '/JdbcResource/' + dsName)
      XAParams=create('XAParams','JDBCXAParams')
      XAParams.setKeepXaConnTillTxComplete(true)
      XAParams.setXaRetryDurationSeconds(300)
      XAParams.setXaTransactionTimeout(120)
      XAParams.setXaSetTransactionTimeout(true)
      XAParams.setXaEndOnlyOnce(true)
      
    assign('JDBCSystemResource',dsName,'Target',WLDomain.instance.targetServer)
    print dsName + ' successfully created.'
  
class MultiDataSource(DataSource):  
  def __init__(self, dsName, user, passwd):
    DataSource.__init__(self, dsName, user, passwd)
    self.xa_protocol = eval(dsName.replace('-','_') + '_xa_protocol')
    self.xa_driver = eval(dsName.replace('-','_') + '_xa_driver')
    self.mp_algorithm = eval(dsName.replace('-','_') + '_mp_algorithm')
    
  def configure(self):  
    print 'Creating Multi DataSource ' + self.dsName 
    self.deleteDataSource(self.dsName)
    
    ds_list = ''
    for i in range(OracleRAC.instance.size):
      index = i + 1
      physical_ds_name = self.dsName + '-' + str(index)
      self.createPhysicalDataSource(physical_ds_name, physical_ds_name, self.xa_protocol, OracleRAC.instance.getMultiDSURL(index), self.xa_driver, self.user, self.passwd)
      if i > 0:
        ds_list += ','
      ds_list += physical_ds_name
  
    cd('/')
    
    sysRes = create(self.dsName, "JDBCSystemResource")  
    
    cd('/JDBCSystemResource/' + self.dsName + '/JdbcResource/' + self.dsName)
    dataSourceParams=create('dataSourceParams','JDBCDataSourceParams')
    dataSourceParams.setAlgorithmType(self.mp_algorithm)
    dataSourceParams.setDataSourceList(ds_list)
    cd('JDBCDataSourceParams/NO_NAME_0')
    print "Setting JNDI Names: " 
    print self.jndi_names
    set('JNDINames',self.jndi_names)
    set('GlobalTransactionsProtocol',self.xa_protocol)
    
    assign('JDBCSystemResource',self.dsName,'Target',WLDomain.instance.targetServer)
    print 'Multi DataSource '+ self.dsName + ' successfully created.'
  
class PhysicalDataSource(DataSource):  
  def __init__(self, dsName, user, passwd):
    DataSource.__init__(self, dsName, user, passwd)
    self.loadbalance = eval(dsName.replace('-','_') + '_loadbalance')
    
  def configure(self):
    print "Re-configuring existing datasource: " + self.dsName
    self.createPhysicalDataSource(self.dsName, self.jndi_names, 'None', OracleRAC.instance.getDriverDSURL(self.loadbalance), 'false', self.user, self.passwd)
    print self.dsName + ' successfully re-configured.'
    
class WLDomain:
  instance = None
  def __init__(self):

    try:
      self.db_user = database_user
      self.db_passwd = database_passwd
    except NameError, ne:
      print "No databse user/password specified.  Will not configure portalDataSource, etc."

    try:
      self.gs_user = groupspace_user
      self.gs_passwd = groupspace_passwd
    except NameError, ne:
      print "No groupspace cmrepo user/password specified.  Will not configure appGroupSpaceDataSource"
    

    try:
      readDomain(domain_dir)
      server=ls('Server').splitlines()
      self.targetServer = re.split('\s+', server[0])[1]
    except IndexError, ie:
      raise SkipConfError, "No valid domain found at: " + domain_dir + ". Skipping RAC configuration. "
    except NameError, ne:
      print "Required parameter domain_dir not specified! "
      sys.exit(-1)

    self.all_datasources = ls('/JDBCSystemResource').splitlines()
    for i in range(len(self.all_datasources)):
      self.all_datasources[i]= re.split('\s+', self.all_datasources[i])[1]

    WLDomain.instance = self
    
  def configure(self):
    for dsName in self.all_datasources:
      print "Processing datasource: " + dsName + " ..."

      try:
        is_mp=eval(dsName.replace('-','_') + '_is_mp')
      except NameError:
        print "Skipping unknown datasource: " + dsName
        continue

      try:
        if dsName == 'appsGroupSpaceDataSource':
          user = self.gs_user
          passwd = self.gs_passwd
        else:
          user = self.db_user
          passwd = self.db_passwd
      except AttributeError, ae:
        print "Skipping un-used datasource: " + dsName
        continue
        
      if is_mp=="true":
        MultiDataSource(dsName, user, passwd).configure()
      else:
        PhysicalDataSource(dsName, user, passwd).configure()
    
    updateDomain()
    print "Successfully re-configured domain for Oracle RAC! "
        
    
for i in range(1,len(sys.argv)):
  exec sys.argv[i]

try:
  OracleRAC()
  WLDomain().configure()
except SkipConfError, sce:
  print sce

------------------------