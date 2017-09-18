import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "weblogic"
weblogicAdminUrl = "t3://localhost:7001"

queueName = "JOB_SCHEDULER_PROCESS_QUEUE"
queueJndi = "com.ibsplc.xibase.jobscheduler.process"

### do not edit

def findQueueByJndiName(jndiName):
   cd('/JMSSystemResources')
   answer = {}
   jmsModules = cmo.getJMSSystemResources()
   for jmsModule in jmsModules:
      cd('/JMSSystemResources/' + jmsModule.getName() + '/JMSResource/' + jmsModule.getName())
      queues = cmo.getUniformDistributedQueues()
      for queue in queues:
         if queue.getJNDIName() == jndiName:
            answer['subDep'] = queue.getSubDeploymentName()
            answer['udd'] = True
            answer['jmsResource'] = jmsModule.getJMSResource()
            return answer
      queues = cmo.getQueues()
      for queue in queues:
         if queue.getJNDIName() == jndiName:
            answer['subDep'] = queue.getSubDeploymentName()
            answer['udd'] = False
            answer['jmsResource'] = jmsModule.getJMSResource();
            return answer      
   return None   
   
def createQueue(queueName, jndiName):
   asyncQueueJndi = "com.ibsplc.xibase.framework.async.ConcurrentQueue" # a queue which is used as the template
   queueMD = findQueueByJndiName(asyncQueueJndi)
   if queueMD is None:
      print "Unable to lookup queue details JNDIName : " + asyncQueueJndi
      return
   jmsResource = queueMD['jmsResource']
   if queueMD['udd']:
      jmsqueue = jmsResource.lookupDistributedQueue(queueName)
   else:
      jmsqueue = jmsResource.lookupQueue(queueName)
   if jmsqueue is None:
      print "Queue : " + queueName + " does not exists... creating ..."
      if queueMD['udd']:
         jmsqueue = jmsResource.createUniformDistributedQueue(queueName)
      else:
         jmsqueue = jmsResource.createQueue(queueName)
   else:
      print "Queue : " + queueName + " exists... updating details ..."
   jmsqueue.setJNDIName(jndiName)
   jmsqueue.setSubDeploymentName(queueMD['subDep'])
   deliveryFailureParams = jmsqueue.getDeliveryFailureParams()
   deliveryFailureParams.setRedeliveryLimit(3)
   deliveryFailureParams.setExpirationPolicy('Discard')
   deliveryOverrides = jmsqueue.getDeliveryParamsOverrides()
   deliveryOverrides.setRedeliveryDelay(30000)
   deliveryOverrides.setDeliveryMode('Non-Persistent')


connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()
createQueue(queueName, queueJndi)

# we are done now lets save all the work
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()

