uname = "system"
pwd = "webl0g!c"
url = "t3://localhost:7001"


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


def connectToAdminRuntime():
   connect(uname, pwd, url)
   domainRuntime()


def expireSessionForServer(servername):
   print "Expiring http sessions for server - "+servername
   cd('ServerRuntimes/' + servername + '/ApplicationRuntimes/icargo/ComponentRuntimes/' + servername + '_/icargo')
   count=0
   for id in cmo.getServletSessionsMonitoringIds():
   try:
      #print id
      count=count+1
      cmo.invalidateServletSession(id)
   except:
      print "Unexpected error:", sys.exc_info()[0]	
      print "A total of "+count.toString()+" sessions"	
            

connectToAdminRuntime()
for managedServer in managedServers.keys():
   expireSessionForServer(managedServer)



