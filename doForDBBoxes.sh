#!/bin/bash

#SERVERS="192.168.9.102 192.168.9.101 192.168.9.49 192.168.9.100 192.168.9.48 192.168.9.43 192.168.9.42 192.168.9.41 192.168.9.40 192.168.9.47 192.168.9.46 192.168.9.45 192.168.9.44"

SERVERS="10.183.122.64 10.183.122.65 10.183.122.66 10.183.122.67"

for SERVER in ${SERVERS} ; do
   echo "doing for $SERVER "
   ssh oracle@${SERVER} bash -c '
echo "# added for iCargo perf test" >> ~/.bashrc
echo "export JAVA_HOME=\"/u01/app/oracle/product/11.2.0.3/dbhome_1/jdk\"" >> ~/.bashrc
echo "export PATH=\"${PATH}:${JAVA_HOME}/bin\"" >> ~/.bashrc
echo "export PS1=\"\u@\h:\w $\"" >> ~/.bashrc
echo "alias icob=\"cd /home/oracle/icob\"" >> ~/.bashrc
echo "alias dorcl=\"cd ${ORACLE_HOME}\"">> ~/.bashrc

echo "" >> ~/.bashrc
   '

done
