#
# python script to update the topic`s delivery policy
#
# usage : /app/mw1/bea/wls/common/bin/wlst.sh updateTopic.py

WLUSER='icargo_adm'
WLPASSWD='adm_icargo'
#
# Change the url to reflect the environment
#
WLURL='t3://localhost:8101'
QPATH='edit:/JMSSystemResources/iCargoJMSModule/JMSResource/iCargoJMSModule'

#
# Update the queues to Non-Persistent
#
def updateTopics():
   isStandalone = len(cmo.getClusters()) == 0
   cd(QPATH)
   if isStandalone:
      queues = cmo.getTopics()
   else:
      queues = cmo.getUniformDistributedTopics()
   for q in queues:
      jndiName = q.getJNDIName()
      print "Updating topic : " + jndiName
      deliveryOverrides = q.getDeliveryParamsOverrides()
      deliveryOverrides.setDeliveryMode('Non-Persistent')
   


print "Starting the script ..."

connect(WLUSER, WLPASSWD, WLURL)
edit()
startEdit()

# we are done now lets save all the work
try:
   updateTopics()
   save()
   activate(block="true")
   print "Current edit is saved successfully ..."
except:
   print "Error while trying to save and/or activate!!!"
   dumpStack()
