#!/bin/bash

TDIR='/opt/bea1223/user_projects/domains/icargodomain/user_stage/live/app/icargo/icargo-ebl'
SDIR='/opt/bea1223/user_projects/domains/icargodomain/user_stage/landing/app/icargo-ebl.war'

wladmin kill icargodomain

if [[ -d ${TDIR} ]]; then
   rm -rf $TDIR
   echo "Application binary cleared."
fi

if [[ -f ${SDIR} ]]; then
   echo "Exploding ...."
   unzip -q -d ${TDIR} ${SDIR}
   typeset -i ANS=${?}
   if [[ $ANS -eq 0 ]]; then
      echo "Sucessfully Exploded war"
      wladmin start icargodomain
   else
      echo "ERROR Explod operation failed."
   fi
   rm ${SDIR}
else
   echo "ERROR war not present in landing directory"
fi

