PENG masternode install & bootstrap script
----

For masternode install on VPS, use the install script by issuing these 3 commands in PuTTy:
1. wget https://raw.githubusercontent.com/coinpeng/pengcore_installer/master/peng_install.sh
2. chmod +x peng_install.sh
3. ./peng_install.sh

Choose option 1 for installation of new masternode.
Choose option 2 to bootstrap your masternode.
Choose option 3 to exit.

----

Bootstrap file
-----

PENG bootstrap will sync to block 787,500 at once.
Unzip in datafolder & restart wallet client. Instructions are below.

This bootstrap is on the same chain as the official explorers found here: 
http://149.28.12.158:88 && http://212.237.10.171:3001 && https://www.coinexplorer.net/peng

----

For desktop wallet:
1. Download bootstrap file
2. Open File Explorer
3. Click address bar, type **%appdata%** and enter
4. Open **PENG** folder
5. Paste bootstrap file here
6. Unzip bootstrap file and replace all
7. Open peng.conf
8. Copy-paste the addnodes in there, replacing any already there
9. Save, close everything and open wallet.

If MAC: step 3 is **~/Library/Application Support**
If Linux: step 3 is **/home** and step 4 is folder **.peng**

----

For multiple masternodes on one VPS, use these manual commands in PuTTy:
1. wget https://github.com/coinpeng/pengcore_installer/releases/download/PENG/bootstrap.zip
2. cp bootstrap.zip /root/.pengdatafolder      (replace with correct folder name) 
3. cd /root/.pengdatafolder                            (replace with correct folder name) 
4. unzip bootstrap.zip
5. Repeat lines 2 - 4 for each nodes datafolder

----

Addnodes (peng.conf)
----

- addnode=149.28.12.158
- addnode=212.237.10.171
- addnode=80.240.31.108
- addnode=45.32.33.152
- addnode=159.69.250.59
- addnode=213.225.2.119
- addnode=188.163.18.250
- addnode=173.249.32.90
- addnode=89.217.221.31
- addnode=80.211.173.51
- addnode=213.149.62.216
- addnode=118.108.150.127
- addnode=176.118.50.97
- addnode=80.211.92.210
- addnode=45.77.17.167
- addnode=108.61.201.235
- addnode=167.179.79.12
- addnode=202.182.103.214
- addnode=188.42.33.124
- addnode=178.210.146.93
- addnode=212.237.24.234
- addnode=92.99.223.134
- addnode=80.211.70.73
- addnode=82.165.69.124
- addnode=94.130.90.26
- addnode=5.54.137.202
- addnode=85.214.152.190
- addnode=185.42.129.8
- addnode=107.172.140.169
- addnode=80.211.72.17
