
To install Oracle 12.2 on a fresh Virtual machine with RHEL 7 with minimum install:

0. Download the file linuxx64_12201_database.zip from here, and copy it over the empty file with the same name:

  https://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html

1. Enable RHEL DVD repository:

  bash rhel-post-install-script.sh

2. Install oracle database (Only the software, Enterprise Edition): 

  bash install.sh

3. Create instance:

  bash go-oracle.sh
  dbca

4. Execute this script if you want that the instance to start at boot time: 

  bash enable-database-startup-at-boot.sh

5. Remove the Oracle installer files:

  bash remove_installer_files.sh


enjoy
