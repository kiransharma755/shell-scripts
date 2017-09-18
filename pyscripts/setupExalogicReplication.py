import sys
from java.lang import System

user_name="system"
password="webl0g!c"
admin_url="t3://localhost:7001"

managedServers={ "ico_prf_vm1_ms1" : "4005-4007" ,
	         "ico_prf_vm1_ms2" : "5005-5007" ,
	         "ico_prf_vm2_ms1" : "4005-4007" ,
	         "ico_prf_vm2_ms2" : "5005-5007" ,
	         "ico_prf_vm3_ms1" : "4005-4007" ,
	         "ico_prf_vm3_ms2" : "5005-5007" ,
	         "ico_prf_vm4_ms1" : "4005-4007" ,
	         "ico_prf_vm4_ms2" : "5005-5007" ,
	         "ico_prf_vm5_ms1" : "4005-4007" ,
	         "ico_prf_vm5_ms2" : "5005-5007" ,
	         "ico_prf_vm6_ms1" : "4005-4007" ,
	         "ico_prf_vm6_ms2" : "5005-5007" ,
	         "ico_prf_vm7_ms1" : "4005-4007" ,
	         "ico_prf_vm7_ms2" : "5005-5007" ,
	         "ico_prf_vm8_ms1" : "4005-4007" ,
	         "ico_prf_vm8_ms2" : "5005-5007" ,
	         "ico_prf_vm9_ms1" : "4005-4007" ,
	         "ico_prf_vm9_ms2" : "5005-5007" ,
	         "ico_prf_vm10_ms1" : "4005-4007" ,
	         "ico_prf_vm10_ms2" : "5005-5007" ,
	         "ico_prf_vm11_ms1" : "4005-4007" ,
	         "ico_prf_vm11_ms2" : "5005-5007" ,
	         "ico_prf_vm12_ms1" : "4005-4007" ,
	         "ico_prf_vm12_ms2" : "5005-5007" ,
	         "ico_prf_vm13_ms1" : "4005-4007" ,
	         "ico_prf_vm13_ms2" : "5005-5007"
	      }

def setupListenAddressForInstance(managedServer, listenAddress):
   print 'setting replication port for server ' + managedServer
   cd('/Servers/'+managedServer)
   set('ReplicationPorts', listenAddress)
   

def setupChannelConfig(managedServer, channelName):
   print 'setting channel config for server ' + managedServer
   cd('/Servers/'+managedServer)
   # create the t3 channel
   #cmo.createNetworkAccessPoint(channelName)
   # change to the channel and configure it
   cd('/Servers/'+managedServer+'/NetworkAccessPoints/'+channelName)
   #com.setSDPEnabled(true)
   #cmo.setProtocol('t3')
   #cmo.setListenPort(4005)# 5005
   #cmo.setEnabled(true)
   #cmo.setOutboundEnabled(true)
   cmo.setHttpEnabledForThisProtocol(false)
   #cmo.setTunnelingEnabled(false)
   #cmo.setOutboundEnabled(false)
   #cmo.setTwoWaySSLEnabled(false)
   #cmo.setClientCertificateEnforced(false)


def setupReplicationForCluster():
   for managedServer,listenAddress in managedServers.items():
      setupListenAddressForInstance(managedServer, listenAddress)
      setupChannelConfig(managedServer,'ReplicationChannel')
   



print "Starting the script ..."

connect(user_name,password,admin_url)
edit()
startEdit()

setupReplicationForCluster()

# Lets try to save the change now ....
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()


