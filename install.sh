#!/bin/bash

true=0 false=1 ok=0 error=1

print_users(){
  cat /etc/passwd | awk -F: '{print $1}'
}

print_groups(){
  cat /etc/group | awk -F: '{print $1}'
}

check_group(){
  print_groups | grep -q "^$1$"
}

check_user(){
  print_users | grep -q "^$1$"
}

get_hostname_ip(){
  cat /etc/hosts  | grep -w $HOSTNAME | tr ' \t' '\n' | head -1
}

remove_heading_spaces(){
  tee | sed 's/ *//'
}

create_groups(){
  local groups uid group
  groups="502 oinstall
  503 dba
  504 oper
  505 asmadmin
  501 nobody"
  echo "$groups" | remove_heading_spaces | while read uid group ; do
    check_group $group || { 
      groupadd -g $uid $group
    }
  done
  return $true
}

create_oracle_user(){
  check_user oracle || {
    useradd -u 502 -g oinstall -G dba,asmadmin,oper -s /bin/bash -m oracle || return $error
  }
  return $true
}

change_oracle_password(){
  [ "$1" == "" ] || {
    echo "oracle:$1" | chpasswd || return $error
  }
  return $true
}

decompress_oracle12c_package(){
  local software_dir="$PWD"
  [ -d /tmp/database ] || {
    (
    cd /tmp &&
    rm -rf database
    unzip -q -o "$software_dir/linuxx64_12201_database.zip" || return $error
    chown -R oracle:oinstall database || return $error
    )
  }
  return $true
}

install_oracle12c(){
  xhost si:localuser:oracle
  [ -f ~/.Xauthority ] && {
    cp ~/.Xauthority /home/oracle/.Xauthority
    chown oracle:oinstall /home/oracle/.Xauthority
  }
  su - oracle -c 'export DISPLAY='$DISPLAY' ; cd /tmp/database && ./runInstaller -responseFile ~/response_files/db.rsp'
}

check_hostname_and_ip(){
  local line=$(cat /etc/hosts | grep -v ^# | grep -w $HOSTNAME | tr ' \t' '\n')
  [ "$(echo "$line" | head -1)" == "" ] && return $error
  echo "$line" | tail -n +2 | grep -q -w $HOSTNAME || return $error
}

configure_kernel_parameters(){
    local MemTotal shmall shmmax p
    MemTotal=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    shmall=$(( $MemTotal / 10 ))
    shmmax=$(( ($MemTotal * 1024) / 2 ))
    echo "
    fs.aio-max-nr = 1048576
    fs.file-max = 6815744
    kernel.panic_on_oops = 1
    kernel.sem = 250 32000 100 128
    kernel.shmall = $shmall
    kernel.shmmax = $shmmax
    kernel.shmmni = 4096
    net.core.rmem_default = 262144
    net.core.rmem_max = 4194304
    net.core.wmem_default = 262144
    net.core.wmem_max = 1048576
    net.ipv4.conf.all.rp_filter = 2
    net.ipv4.conf.default.rp_filter = 2
    net.ipv4.ip_local_port_range = 9000 65500
    " | remove_heading_spaces > /etc/sysctl.conf
    sysctl -p
}

set_user_limits(){
  [ -f /etc/security/limits.d/55-oracle.conf ] || {
    echo "
    oracle       soft  nproc  2047
    oracle       hard  nproc  16384
    oracle       soft  nofile 1024
    oracle       hard  nofile 65536
    oracle       soft  stack  10240
    " | remove_heading_spaces > /etc/security/limits.d/55-oracle.conf
  }
}

create_oracle_directories(){
  mkdir -p /u01/app/oracle/product/12c/dbhome
  chown -R oracle:oinstall /u01
  chmod -R 775 /u01
}

create_oraenv_file(){
  echo '
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=$ORACLE_BASE/product/12c/'$1'
  export ORACLE_SID='$2'
  export INVENTORY_LOCATION=/home/oracle/oraInventory
  export LD_LIBRARY_PATH=$ORACLE_HOME/lib
  export PATH=$ORACLE_HOME/bin:/bin:/sbin:/usr/bin:/usr/sbin
  ' | remove_heading_spaces > /home/oracle/oraenv
  [ -f /home/oracle/.bashrc ] || {
    cp /etc/skel/* /home/oracle
    chown -R oracle:oinstall /home/oracle
  }
  cat /home/oracle/.bashrc | grep -q 'source /home/oracle/oraenv' || {
    echo 'source /home/oracle/oraenv' >> /home/oracle/.bashrc
  }
}

create_response_file(){
  (
  source /home/oracle/oraenv
  mkdir -p /home/oracle/response_files
  echo "
  oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0
  oracle.install.option=INSTALL_DB_AND_CONFIG
  UNIX_GROUP_NAME=oinstall
  INVENTORY_LOCATION=$INVENTORY_LOCATION
  ORACLE_HOME=$ORACLE_HOME
  ORACLE_BASE=$ORACLE_BASE
  oracle.install.db.InstallEdition=EE
  oracle.install.db.OSDBA_GROUP=dba
  oracle.install.db.OSOPER_GROUP=oinstall
  oracle.install.db.OSBACKUPDBA_GROUP=dba
  oracle.install.db.OSDGDBA_GROUP=dba
  oracle.install.db.OSKMDBA_GROUP=dba
  oracle.install.db.OSRACDBA_GROUP=dba
  oracle.install.db.rac.configurationType=
  oracle.install.db.CLUSTER_NODES=
  oracle.install.db.isRACOneInstall=false
  oracle.install.db.racOneServiceName=
  oracle.install.db.rac.serverpoolName=
  oracle.install.db.rac.serverpoolCardinality=0
  oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
  oracle.install.db.config.starterdb.globalDBName=$ORACLE_SID
  oracle.install.db.config.starterdb.SID=$ORACLE_SID
  oracle.install.db.ConfigureAsContainerDB=false
  oracle.install.db.config.PDBName=
  oracle.install.db.config.starterdb.characterSet=AL32UTF8
  oracle.install.db.config.starterdb.memoryOption=true
  oracle.install.db.config.starterdb.memoryLimit=500
  oracle.install.db.config.starterdb.installExampleSchemas=false
  oracle.install.db.config.starterdb.password.ALL=
  oracle.install.db.config.starterdb.password.SYS=
  oracle.install.db.config.starterdb.password.SYSTEM=
  oracle.install.db.config.starterdb.password.DBSNMP=
  oracle.install.db.config.starterdb.password.PDBADMIN=
  oracle.install.db.config.starterdb.managementOption=DEFAULT
  oracle.install.db.config.starterdb.omsHost=
  oracle.install.db.config.starterdb.omsPort=0
  oracle.install.db.config.starterdb.emAdminUser=
  oracle.install.db.config.starterdb.emAdminPassword=
  oracle.install.db.config.starterdb.enableRecovery=false
  oracle.install.db.config.starterdb.storageType=FILE_SYSTEM_STORAGE
  oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=$ORACLE_BASE/oradata
  oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=
  oracle.install.db.config.asm.diskGroup=
  oracle.install.db.config.asm.ASMSNMPPassword=
  MYORACLESUPPORT_USERNAME=
  MYORACLESUPPORT_PASSWORD=
  SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
  DECLINE_SECURITY_UPDATES=true
  PROXY_HOST=
  PROXY_PORT=
  PROXY_USER=
  PROXY_PWD=
  COLLECTOR_SUPPORTHUB_URL=
  " | remove_heading_spaces > /home/oracle/response_files/db.rsp
  chown oracle:oinstall /home/oracle/response_files/db.rsp
  )
}

if_running_rhel(){
  [ -f /etc/redhat-release ]
}

install_packages(){
  if_running_rhel && {
    yum update || return $error
    yum install -y binutils.x86_64 smartmontools net-tools xorg-x11-server-utils xauth xorg-x11-utils compat-libcap1.x86_64 gcc.x86_64 gcc-c++.x86_64 glibc.i686 glibc.x86_64 glibc-devel.i686 glibc-devel.x86_64 ksh compat-libstdc++-33 libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libXi.i686 libXi.x86_64 libXtst.i686 libXtst.x86_64 make.x86_64 sysstat.x86_64 zip unzip || return $error
  }
}

open_firewall_for_oracle(){
  firewall-cmd --zone=public --add-port=1521/tcp --add-port=5500/tcp --add-port=5520/tcp --add-port=3938/tcp --permanent
  firewall-cmd --reload
}

create_oracle_service(){
  echo '
  [Unit]
  Description=Oracle Database(s) and Listener
  Requires=network.target

  [Service]
  Type=forking
  Restart=no
  ExecStart=/u01/app/oracle/product/12c/dbhome/bin/dbstart /u01/app/oracle/product/12c/dbhome
  ExecStop=/u01/app/oracle/product/12c/dbhome/bin/dbshut /u01/app/oracle/product/12c/dbhome
  User=oracle

  [Install]
  WantedBy=multi-user.target
  ' | remove_heading_spaces > /etc/systemd/system/oracle.service
  systemctl daemon-reload
  systemctl enable oracle
}

check_display(){
  xdpyinfo >/dev/null 2>/dev/null
}

main(){
  check_hostname_and_ip || {
    echo -e "\nError please assign an ip to your hostname ($HOSTNAME) in /etc/hosts\n"
    exit
  }
  install_packages &&
  configure_kernel_parameters &&
  create_groups 
  create_oracle_user &&
  change_oracle_password oracle &&
  set_user_limits &&
  create_oracle_directories &&
  create_oraenv_file dbhome dbcssi &&
  create_response_file &&
  decompress_oracle12c_package &&
  open_firewall_for_oracle &&
  create_oracle_service &&
  check_display || {
    echo "Error accessing X11 please check DISPLAY variable"
    exit 1
  }
  install_oracle12c
}

main
