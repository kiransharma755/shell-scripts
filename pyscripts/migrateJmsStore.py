#
# python script to update the jms persistent store path
#
# usage : /app/mw/bea/wls/common/bin/wlst.sh migrateJmsStore.py

import os

WLUSER='icargo_adm'
WLPASSWD='adm_icargo'
#
# Change the url to reflect the environment
#
WLURL='t3://vmh-lcag-icargo-app02-sit.lsy.fra.dlh.de:8001'

def modifyFileStore(store):
   jmsDir = store.getDirectory()
   newJmsDir = jmsDir.replace('nfs', 'jms')
   store.setDirectory(newJmsDir)

def modifyFileStore_revert(store):
   jmsDir = store.getDirectory()
   newJmsDir = jmsDir.replace('jms', 'nfs')
   store.setDirectory(newJmsDir)


print "Starting the script ..."
connect(WLUSER, WLPASSWD, WLURL)
edit()
startEdit()

stores = cmo.getFileStores()
for store in stores:
   print "Migrating store : " + store.getName()
   modifyFileStore(store)
   


# Lets try to save the change now ....
try:
   save()
   activate(block="true")
   print "Current edit is saved successfully ..."
except:
   print "Error while trying to save and/or activate!!!"
   dumpStack()
   
