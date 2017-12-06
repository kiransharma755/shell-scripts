#!/bin/bash

ACCDIR="$1"
HURL='/iCargoHealthCheck/HealthCheck'
FPFX='icargo-prod'

analyzeForServer(){
   local SRV="$1"
   local TFILE="${ACCDIR}/${FPFX}_${SRV}.lst"
   local AFILE="${ACCDIR}/${FPFX}_${SRV}.hca"
   echo "" > $TFILE
   for ACFILE in ${ACCDIR}/${FPFX}${SRV}_Access.log????? ; do
      echo ${ACFILE} >> $TFILE
   done 
   sort $TFILE > $TFILE.sorted
   mv $TFILE.sorted $TFILE
   if [[ -r "${ACCDIR}/${FPFX}${SRV}_Access.log" ]]; then
      echo "${ACCDIR}/${FPFX}${SRV}_Access.log" >> $TFILE
   fi
   while read LFILE; do
      if [[ -r ${LFILE} ]]; then
         grep "${HURL}" "${LFILE}" >> "${AFILE}"
      fi
   done < $TFILE 
   #echo "Created aggregated access log for server ${FPFX}${SRV} as ${AFILE}"
   rm ${TFILE}
   collateEntries ${SRV} ${AFILE}
   rm ${AFILE}
}

collateEntries(){
   local SRV="$1"
   local HFILE="$2"
   local RFILE="${ACCDIR}/${FPFX}_${SRV}.hc"
   awk 'BEGIN {
 prev=""
 curr=""
 totalTime=0
 count=0
 print "Time(byMinute) numChecks totalResponseTime"
}
{
  curr = $3 "~" substr($4, 0, 5);
  if (prev != "" && curr != prev){
     if (count > 0 && (totalTime > 2 || count < 10)){
        print curr " " count " " totalTime;
     }
     totalTime = 0;
     count = 0;
  }
  prev = curr;
  count++;
  totalTime += $8
}
END {
   if (count > 0 && totalTime > 2){
      print curr " " count " " totalTime;
   }
}' "$HFILE" > ${RFILE} 
   local LINES=$(wc -l ${RFILE} | awk ' { print $1} ')
   if [[ ${LINES} -lt 2 ]]; then
      echo "Server ${FPFX}_${SRV} healthy"
      rm $RFILE
   else
      echo "Health report file : $RFILE"
   fi
}

if [[ -z ${ACCDIR} ]]; then
   echo "Specify a directory for the parsing of allcess logs."
   exit 1
fi

for INS in {1,2,3,4}{1,2,3,4}; do
   analyzeForServer ${INS}
done
#analyzeForServer 11
