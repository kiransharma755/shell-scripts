#!/bin/bash

# A fuzzing script which takes out servers from the LB pool to trigger failovers and session replications

typeset -i SLEEP_SECS=1200
typeset -r ALL_SERVERS='vmh-lcag-icargo-app02-sit.lsy.fra.dlh.de:8011 vmh-lcag-icargo-app02-sit.lsy.fra.dlh.de:8021 vmh-lcag-icargo-app02-sit.lsy.fra.dlh.de:8111 vmh-lcag-icargo-app02-sit.lsy.fra.dlh.de:8121 vmh-lcag-icargo-app03-sit.lsy.fra.dlh.de:8011 vmh-lcag-icargo-app03-sit.lsy.fra.dlh.de:8021 vmh-lcag-icargo-app03-sit.lsy.fra.dlh.de:8111 vmh-lcag-icargo-app03-sit.lsy.fra.dlh.de:8121 vmh-lcag-icargo-app04-sit.lsy.fra.dlh.de:8011 vmh-lcag-icargo-app04-sit.lsy.fra.dlh.de:8021 vmh-lcag-icargo-app04-sit.lsy.fra.dlh.de:8111 vmh-lcag-icargo-app04-sit.lsy.fra.dlh.de:8121'

while true; do
   for SERVER in ${ALL_SERVERS}; do
      echo "Freezing server $SERVER"
      curl --fail -XGET "${SERVER}/iCargoHealthCheck/HealthCheck?action=deactivate&password=icargo123"
      typeset -i ANS=${?}
      if [[ ${ANS} -eq 0 ]]; then
         echo "Sucessfully freezed server"
         sleep ${SLEEP_SECS}
         echo "Thawing server ..."
         curl --fail -XGET "${SERVER}/iCargoHealthCheck/HealthCheck?action=activate&password=icargo123"
         sleep 30
      fi
   done
done
