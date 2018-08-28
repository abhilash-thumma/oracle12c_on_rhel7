#!/bin/bash

remove_trailing_spaces(){
  tee | sed 's/^ *//'
}

fix_sshd(){
  [ -f /etc/ssh/sshd_config ] && {
    sshd=$(cat /etc/ssh/sshd_config | egrep -v 'AllowTcpForwarding|X11Forwarding|X11DisplayOffset|X11UseLocalhost')
    echo "
    $sshd
    AllowTcpForwarding yes
    X11Forwarding yes
    X11DisplayOffset 10
    X11UseLocalhost no
    " | remove_trailing_spaces > /etc/ssh/sshd_config
    systemctl restart sshd
  }
}

mount_dvd(){
  mkdir -p /mnt/dvd
  df -h /mnt/dvd | grep -q '^/dev/sr0' || {
    cat /etc/fstab | grep -q '^/dev/sr0' || {
      echo '/dev/sr0 /mnt/dvd iso9660 ro 0 0' >>/etc/fstab
    }
    mount /mnt/dvd || {
      echo Error cannot mount dvd-rom
      exit 1
    }
  }
}

create_dvd_repo(){
  echo '[InstallMedia]
  name=DVD
  gpgcheck=0
  enabled=1
  baseurl=file:///mnt/dvd
  ' | remove_trailing_spaces > /etc/yum.repos.d/dvd.repo
  ls -1d /etc/yum.repos.d/public-*.repo 2>/dev/null | while read f ; do
    [ -f $f ] && mv $f ~/
  done
}

main(){
  mount_dvd
  create_dvd_repo
  yum update &&
  yum -y install zip unzip wget elfutils-libelf-devel telnet kernel-devel gcc make perl
  yum -y install net-tools xorg-x11-server-utils xauth xorg-x11-utils
  fix_sshd
}

main
