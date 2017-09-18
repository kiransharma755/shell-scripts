#!/bin/bash

SERVERS="ico_prf_vm1_ms1 ico_prf_vm1_ms2 ico_prf_vm2_ms1 ico_prf_vm2_ms2 ico_prf_vm3_ms1 ico_prf_vm3_ms2 ico_prf_vm4_ms1 ico_prf_vm4_ms2 ico_prf_vm5_ms1 ico_prf_vm5_ms2 ico_prf_vm6_ms1 ico_prf_vm6_ms2 ico_prf_vm7_ms1 ico_prf_vm7_ms2 ico_prf_vm8_ms1 ico_prf_vm8_ms2 ico_prf_vm9_ms1 ico_prf_vm9_ms2 ico_prf_vm10_ms1 ico_prf_vm10_ms2 ico_prf_vm11_ms1 ico_prf_vm11_ms2 ico_prf_vm12_ms1 ico_prf_vm12_ms2 ico_prf_vm13_ms1 ico_prf_vm13_ms2"

for SERVER in ${SERVERS}; do
echo "for $SERVER "
SECDIR="/cellone/Oracle/Middleware/Oracle_Home/user_projects/domains/base_domain/servers/${SERVER}/security"
BOOTFILE="${SECDIR}/boot.properties"
if [[ ! -r ${SECDIR} ]]; then
   mkdir -p ${SECDIR}
fi
if [[ ! -e ${BOOTFILE} ]]; then
   echo "username=system" >>${BOOTFILE}
   echo "password=webl0g!c" >>${BOOTFILE}
   echo "" >> ${BOOTFILE}
   echo " boot file created ${BOOTFILE} "
   typeset -i ANS=0
   if [[ ${ANS} -ne 0 ]]; then
      echo "command execution failed for : ${SERVER} "
      exit ${ANS}
   fi

fi
done
echo " All done "

