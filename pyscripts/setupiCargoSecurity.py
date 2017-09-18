# iCargo Security Realm Configuration

import sys
from java.lang import System

# Weblogic Server Connection Details
weblogicUser = "system"
weblogicPassword = "webl0g!c"
weblogicAdminUrl = "t3://192.168.6.46:4000"

def fixDefaultSecurityConfiguration():
   cd('/')
   securityConfiguration = cmo.getSecurityConfiguration()
   realm = securityConfiguration.lookupRealm('myrealm')
   authenticator = realm.lookupAuthenticationProvider('DefaultAuthenticator')
   authenticator.setControlFlag('SUFFICIENT')
   domainName = cmo.getName()
   xacmlAuthorizer = getMBean('/SecurityConfiguration/' + domainName + '/Realms/myrealm/Authorizers/XACMLAuthorizer')
   if xacmlAuthorizer is not None:
      realm.destroyAuthorizer(xacmlAuthorizer)
   

def createAuthenticator(authName, authClass, isIdentityAsserter=False):
   cd('/')
   domainName = cmo.getName()
   authMBean = getMBean('/SecurityConfiguration/' + domainName + '/Realms/myrealm/AuthenticationProviders/' + authName)
   if authMBean is None:
      securityConfiguration = cmo.getSecurityConfiguration()
      realm = securityConfiguration.lookupRealm('myrealm')
      authMBean = realm.createAuthenticationProvider(authName, authClass)
      if not isIdentityAsserter:
         authMBean.setControlFlag('SUFFICIENT')
      

def createAuthorizer(authName, authClass):
   cd('/')
   domainName = cmo.getName()
   authorizer = getMBean('/SecurityConfiguration/' + domainName + '/Realms/myrealm/Authorizers/' + authName)
   if authorizer is None:
      # Configure iCargo Authorizer
      securityConfiguration = cmo.getSecurityConfiguration()
      realm = securityConfiguration.lookupRealm('myrealm')
      realm.createAuthorizer(authName, authClass);


def applyJTASettings():
   cd('/JTA/' + domainName)
   cmo.setTimeoutSeconds(300)
   cmo.setAbandonTimeoutSeconds(1800)
   cmo.setForgetHeuristics(True)
   cmo.setParallelXAEnabled(True)
   cmo.setTwoPhaseEnabled(True)

# Main Block
connect(weblogicUser, weblogicPassword, weblogicAdminUrl)
edit()
startEdit()

createAuthenticator('iCargoAuthenticator','com.ibsplc.icargo.framework.security.weblogic.providers.ICargoAuthenticator')
createAuthenticator('iCargoSSOAuthenticator','com.ibsplc.icargo.framework.security.weblogic.providers.sso.ICargoSSOAuthenticator')
createAuthenticator('iCargoSystemAuthenticator','com.ibsplc.icargo.framework.security.weblogic.providers.ICargoSystemAuthenticator')
createAuthenticator('iCargoIdentityAsserter','com.ibsplc.icargo.framework.security.weblogic.providers.sso.iCargoSSOIdentityAsserter', True)
createAuthorizer('iCargoAuthorizer', 'com.ibsplc.icargo.framework.security.weblogic.providers.ICargoAuthorizer')
fixDefaultSecurityConfiguration()
applyJTASettings()

# Lets try to save the change now ....
try:
    save()
    activate(block="true")
    print "Current edit is saved successfully ..."
except:
    print "Error while trying to save and/or activate!!!"
    dumpStack()
