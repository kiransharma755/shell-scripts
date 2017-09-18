#!/bin/bash

#SERVERS="192.168.9.102 192.168.9.101 192.168.9.49 192.168.9.100 192.168.9.48 192.168.9.43 192.168.9.42 192.168.9.41 192.168.9.40 192.168.9.47 192.168.9.46 192.168.9.45 192.168.9.44"

SERVERS="inxlcn06 inxlcn05 inxlcn04 inxlcn03 inxlcn02 inxlcn01 inx24db01 inx24db02 inx24db03 inx24db04 192.168.9.101 192.168.9.102 192.168.9.100 192.168.9.48 192.168.9.43 192.168.9.42 192.168.9.41 192.168.9.40 192.168.9.47 192.168.9.46 192.168.9.45 192.168.9.44"

for SERVER in ${SERVERS} ; do
#   echo "doing for $SERVER "
   ssh oracle@${SERVER} 'echo "`hostname` : `date`"'
#echo "# added for iCargo perf test" >> ~/.bashrc
#echo "export JAVA_HOME=\"/cellone/jdk1.7.0_75\"" >> ~/.bashrc
#echo "export PATH=\"/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:/home/oracle/bin:/cellone/icob:/sbin:/usr/sbin:${JAVA_HOME}/bin\"" >> ~/.bashrc
#echo "export PS1=\"\u@\h:\w $\"" >> ~/.bashrc
#echo "alias icob=\"cd /cellone/icob\"" >> ~/.bashrc
#echo "alias ddom=\"cd /cellone/Oracle/Middleware/Oracle_Home/user_projects/domains/base_domain\"">> ~/.bashrc
#echo "" >> ~/.bashrc
#   '

done
