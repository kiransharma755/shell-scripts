connect('system','webl0g!c', 't3://ISV-VM1:7001');

servers = domainRuntimeService.getServerRuntimes();
for server in servers:
   print 'SERVER: ' + server.getName();

   print('APPLICATION RUNTIME INFORMATION');
   apps = server.getApplicationRuntimes();
   for app in apps:
      print 'Application: ' + app.getName();
      crs = app.getComponentRuntimes();
      for cr in crs:
         #if (cr.getType() == 'EJBComponentRuntime'):
         #   print '-Component Type: ' + cr.getType();
         #   ejbRTs = cr.getEJBRuntimes();
         #   for ejbRT in ejbRTs:
         #      print ' -EJBRunTime: ' + ejbRT.getName() + ' Type ' + ejbRT.getType();
         #      if (ejbRT.getType() == 'MessageDrivenEJBRuntime'):
         #         print '  -MDB Status: ' + ejbRT.getMDBStatus() + ', MDB Health State: ' + repr(ejbRT.getHealthState());
         #      if (ejbRT.getType() == 'StatelessEJBRuntime'):
         #         print '  -EJB Name: ' + ejbRT.getEJBName();
         #         print '  -Resources: ' + repr(ejbRT.getTransactionRuntime());
         if (cr.getType() == 'WebAppComponentRuntime'):
            print '-Component Type: ' + cr.getType();
            print ' -Name: ' + cr.getName() + ', Session Current Count: ' + repr(cr.getOpenSessionsCurrentCount());
            #servlets = cr.getServlets();
            #for servlet in servlets:
            #   print '  -Servlet: ' + servlet.getServletName() + ', total: ' + repr(servlet.getInvocationTotalCount()) + ', average time: ' + repr(servlet.getExecutionTimeAverage());


