#
# python script to update the ws queue delivery policy
#
# usage : /app/mw1/bea/wls/common/bin/wlst.sh updateQueue.py

WLUSER='icargo_adm'
WLPASSWD='adm_icargo'
#
# Change the url to reflect the environment
#
WLURL='t3://vmh-lcag-icargo-app01-test.lsy.fra.dlh.de:8101'
QPATH='edit:/JMSSystemResources/iCargoJMSModule/JMSResource/iCargoJMSModule'

def updateWSQueue():
   isStandalone = len(cmo.getClusters()) == 0
   cd(QPATH)
   if isStandalone:
      queues = cmo.getQueues()
   else:
      queues = cmo.getUniformDistributedQueues()
   for q in queues:
      jndiName = q.getJNDIName()
      if jndiName.endswith('ws.request') or jndiName.endswith('ws.response'):
         print "Updating queue : " + jndiName
         deliveryOverrides = q.getDeliveryParamsOverrides()
         deliveryOverrides.setDeliveryMode('Non-Persistent')
   


print "Starting the script ..."

connect(WLUSER, WLPASSWD, WLURL)
edit()
startEdit()

# we are done now lets save all the work
try:
   updateWSQueue()
   save()
   activate(block="true")
   print "Current edit is saved successfully ..."
except:
   print "Error while trying to save and/or activate!!!"
   dumpStack()
