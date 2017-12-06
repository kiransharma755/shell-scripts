#!/bin/bash

showJStatHelp(){
   cat << EOF_USG
   class               Class Loader Statistics 
   compiler            HotSpot Just-In-Time Compiler Statistics 
   gc                  Garbage-collected heap statistics
   gccapacity          Memory Pool Generation and Space Capacities 
   gccause             Summary of Garbage Collection Statistics with cause.
   gcnew               New Generation Statistics 
   gcnewcapacity       New Generation Space Size Statistics 
   gcold               Old and Permanent Generation Statistics 
   gcoldcapacity       Old Generation Statistics 
   gcpermcapacity      Permanent Generation Statistics 
   gcutil              Summary of Garbage Collection Statistics 
   printcompilation    HotSpot Compiler Method Statistics 
   
   Use help-<command> for further details, eg help-class
EOF_USG
}

# shows the jstat option help
showJStatOptionHelp(){
OPTION="$1"

   case ${OPTION} in
      'help')
           showJStatHelp
           ;;
  'help-class'|'class') 
           cat << EOF_USG
Class Loader Statistics 
      Column       Description
      ------------------------
      Loaded       Number of classes loaded.
      Bytes        Number of Kbytes loaded.
      Unloaded     Number of classes unloaded.
      Bytes        Number of Kbytes unloaded.
      Time         Time spent performing class load and unload operations.
EOF_USG
           ;;
'help-compiler'|'compiler')
           cat << EOF_USG
HotSpot Just-In-Time Compiler Statistics 
      Column       Description
      ------------------------
      Compiled     Number of compilation tasks performed.
      Failed 	   Number of compilation tasks that failed.
      Invalid      Number of compilation tasks that were invalidated.
      Time         Time spent performing compilation tasks.
      FailedType   Compile type of the last failed compilation.
      FailedMethod Class name and method for the last failed compilation.
EOF_USG
           ;;
  'help-gc'|'gc')
          cat << EOF_USG
Garbage-collected heap statistics 
      Column  Description
      --------------------
      S0C     Current survivor space 0 capacity (KB).
      S1C     Current survivor space 1 capacity (KB).
      S0U     Survivor space 0 utilization (KB).
      S1U     Survivor space 1 utilization (KB).
      EC      Current eden space capacity (KB).
      EU      Eden space utilization (KB).
      OC      Current old space capacity (KB).
      OU      Old space utilization (KB).
      PC      Current permanent space capacity (KB).
      PU      Permanent space utilization (KB).
      YGC     Number of young generation GC Events.
      YGCT    Young generation garbage collection time.
      FGC     Number of full GC events.
      FGCT    Full garbage collection time.
      GCT     Total garbage collection time.
EOF_USG
           ;;
   'help-gccapacity'|'gccapacity')
           cat << EOF_USG
Memory Pool Generation and Space Capacities 
      Column     Description
      ----------------------
      NGCMN      Minimum new generation capacity (KB).
      NGCMX      Maximum new generation capacity (KB).
      NGC        Current new generation capacity (KB).
      S0C        Current survivor space 0 capacity (KB).
      S1C        Current survivor space 1 capacity (KB).
      EC         Current eden space capacity (KB).
      OGCMN      Minimum old generation capacity (KB).
      OGCMX      Maximum old generation capacity (KB).
      OGC        Current old generation capacity (KB).
      OC         Current old space capacity (KB).
      PGCMN      Minimum permanent generation capacity (KB).
      PGCMX      Maximum Permanent generation capacity (KB).
      PGC        Current Permanent generation capacity (KB).
      PC         Current Permanent space capacity (KB).
      YGC        Number of Young generation GC Events.
      FGC        Number of Full GC Events.
EOF_USG
           ;;
   'help-gccause'|'gccause')
           cat << EOF_USG
Garbage Collection Statistics, Including GC Events 
      Column     Description
      ----------------------
      LGCC       Cause of last Garbage Collection.
      GCC        Cause of current Garbage Collection.
EOF_USG
           ;;
   'help-gcnew'|'gcnew')
          cat << EOF_USG
New Generation Statistics 
      Column     Description
      ----------------------
      S0C        Current survivor space 0 capacity (KB).
      S1C        Current survivor space 1 capacity (KB).
      S0U        Survivor space 0 utilization (KB).
      S1U        Survivor space 1 utilization (KB).
      TT         Tenuring threshold.
      MTT        Maximum tenuring threshold.
      DSS        Desired survivor size (KB).
      EC         Current eden space capacity (KB).
      EU         Eden space utilization (KB).
      YGC        Number of young generation GC events.
      YGCT       Young generation garbage collection time.
EOF_USG
           ;;
  'help-gcnewcapacity'|'gcnewcapacity')
         cat << EOF_USG
New Generation Space Size Statistics 
      Column  Description
      -------------------
      NGCMN   Minimum new generation capacity (KB).
      NGCMX   Maximum new generation capacity (KB).
      NGC     Current new generation capacity (KB).
      S0CMX   Maximum survivor space 0 capacity (KB).
      S0C     Current survivor space 0 capacity (KB).
      S1CMX   Maximum survivor space 1 capacity (KB).
      S1C     Current survivor space 1 capacity (KB).
      ECMX    Maximum eden space capacity (KB).
      EC      Current eden space capacity (KB).
      YGC     Number of young generation GC events.
      FGC     Number of Full GC Events.
EOF_USG
           ;;
   'help-gcold'|'gcold')
        cat << EOF_USG
Old and Permanent Generation Statistics 
      Column  Description
      --------------------
      PC      Current permanent space capacity (KB).
      PU      Permanent space utilization (KB).
      OC      Current old space capacity (KB).
      OU      old space utilization (KB).
      YGC     Number of young generation GC events.
      FGC     Number of full GC events.
      FGCT    Full garbage collection time.
      GCT     Total garbage collection time.
EOF_USG
          ;;
   'help-gcoldcapacity'|'gcoldcapacity')
        cat << EOF_USG
Old Generation Statistics 
      Column  Description
      --------------------
      OGCMN   Minimum old generation capacity (KB).
      OGCMX   Maximum old generation capacity (KB).
      OGC     Current old generation capacity (KB).
      OC      Current old space capacity (KB).
      YGC     Number of young generation GC events.
      FGC     Number of full GC events.
      FGCT    Full garbage collection time.
      GCT     Total garbage collection time.
EOF_USG
           ;;

   'help-gcpermcapacity'|'gcpermcapacity')
        cat << EOF_USG
Permanent Generation Statistics 
      Column Description
      -------------------
      PGCMN   Minimum permanent generation capacity (KB).
      PGCMX   Maximum permanent generation capacity (KB).
      PGC     Current permanent generation capacity (KB).
      PC      Current permanent space capacity (KB).
      YGC     Number of young generation GC events.
      FGC     Number of full GC events.
      FGCT    Full garbage collection time.
      GCT     Total garbage collection time.
EOF_USG
            ;;
   'help-gcutil'|'gcutil'|'help-gctail'|'gctail')
         cat << EOF_USG
Summary of Garbage Collection Statistics 
      Column  Description
      --------------------
      S0      Survivor space 0 utilization as a percentage of the space's current capacity.
      S1      Survivor space 1 utilization as a percentage of the space's current capacity.
      E       Eden space utilization as a percentage of the space's current capacity.
      O       Old space utilization as a percentage of the space's current capacity.
      P       Permanent space utilization as a percentage of the space's current capacity.
      YGC     Number of young generation GC events.
      YGCT    Young generation garbage collection time.
      FGC     Number of full GC events.
      FGCT    Full garbage collection time.
      GCT     Total garbage collection time.
EOF_USG
           ;;   
   'help-printcompilation'|'printcompilation')
           cat << EOF_USG
HotSpot Compiler Method Statistics 
      Column    Description
      -----------------------
      Compiled  Number of compilation tasks performed by the most recently compiled method.
      Size      Number of bytes of bytecode of the most recently compiled method.
      Type      Compilation type of the most recently compiled method.
      Method    Class name and method name identifying the most recently compiled method.
                Class name uses "/" instead of "." as namespace separator. 
                Method name is the method within the given class. 
                The format for these two fields is consistent with the HotSpot - XX:+PrintComplation option.
EOF_USG
          ;;
      *)
          jechoe "Invalid Option ${OPTION}"
          ;;
   esac
}
