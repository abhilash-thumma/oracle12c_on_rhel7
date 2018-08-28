  xhost si:localuser:oracle
  [ -f ~/.Xauthority ] && {
    cp ~/.Xauthority /home/oracle/.Xauthority
    chown oracle:oinstall /home/oracle/.Xauthority
  }
  su - oracle -c 'export DISPLAY='$DISPLAY' ; bash'
