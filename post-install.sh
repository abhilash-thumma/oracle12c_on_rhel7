#!/bin/bash

[ -d /tmp/database ] && rm -rf /tmp/database

[ -f /etc/oratab ] && sed -i 's/:N$/:Y/' /etc/oratab 


[ -d /u01/app/oracle/product/12c/dbhome/network/admin ] && echo '
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )
' > /u01/app/oracle/product/12c/dbhome/network/admin/listener.ora
