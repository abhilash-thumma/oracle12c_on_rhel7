
To install Oracle 12.2 on a fresh Virtual machine with RHEL 7 with minimum install:

0. Download the file linuxx64_12201_database.zip from here, and copy it over the empty file with the same name:

  https://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html

1. Enable RHEL DVD repository:

  bash rhel-init-script.sh

2. Install oracle database (Only the software, Enterprise Edition): 

  bash install.sh

3. Launch this command after the previous task is complete:

  bash post-install.sh              

4. Create instance:

  bash go-oracle.sh

  dbca



enjoy
