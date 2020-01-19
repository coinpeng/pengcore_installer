#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='peng.conf'
CONFIGFOLDER='/root/.peng'
COIN_DAEMON='pengd'
COIN_CLI='peng-cli'
COIN_PATH='/usr/local/bin/'
COIN_REPO='https://github.com/coinpeng'
COIN_TGZ='https://github.com/coinpeng/pengcore_installer/releases/download/PENG/peng-latest-ubuntu16-vps.zip'
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')
COIN_NAME='peng'
COIN_PORT=3182
RPC_PORT=3181

NODEIP=$(curl -s4 icanhazip.com)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function download_node() {
  echo -e "Prepare to download $COIN_NAME binaries"
  cd /usr/local/bin
  wget https://github.com/coinpeng/pengcore_installer/releases/download/PENG/peng-latest-ubuntu16-vps.zip > /dev/null 2>&1
  sleep 30 > /dev/null 2>&1
  unzip peng-latest-ubuntu16-vps.zip > /dev/null 2>&1
  chmod 777 pengd peng-tx peng-cli > /dev/null 2>&1
  rm -rf /usr/local/bin/peng-latest-ubuntu16-vps.zip
  cd ..
  echo -e "Done."
  clear
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target

[Service]
User=root
Group=root

Type=forking
#PIDFile=$CONFIGFOLDER/pengd.pid

ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
allowip=127.0.0.1
listen=1
server=1
daemon=1
port=$COIN_PORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}$COIN_NAME Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then
  $COIN_PATH$COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the Private Key${NC}"
    sleep 30
    COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  fi
  $COIN_PATH$COIN_CLI stop
fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
#bind=$NODEIP
masternode=1
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
addnode=149.28.12.158
addnode=212.237.10.171
addnode=80.240.31.108
addnode=45.32.33.152
addnode=159.69.250.59
addnode=213.225.2.119
addnode=188.163.18.250
addnode=173.249.32.90
addnode=89.217.221.31
addnode=80.211.173.51
addnode=213.149.62.216
addnode=118.108.150.127
addnode=176.118.50.97
addnode=80.211.92.210
addnode=45.77.17.167
addnode=108.61.201.235
addnode=167.179.79.12
addnode=202.182.103.214
addnode=188.42.33.124
addnode=178.210.146.93
addnode=212.237.24.234
addnode=92.99.223.134
addnode=80.211.70.73
addnode=82.165.69.124
addnode=94.130.90.26
addnode=5.54.137.202
addnode=85.214.152.190
addnode=185.42.129.8
addnode=107.172.140.169
addnode=80.211.72.17
EOF
}


function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT >/dev/null
  ufw allow ssh >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

function get_ip() {
  declare -a NODE_peng
  for peng in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_peng+=($(curl --interface $peng --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_peng[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_peng[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_peng[$choose_ip]}
  else
    NODEIP=${NODE_peng[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
}

function prepare_system() {
echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} master node."
echo -e "It may take some time to finish. Currently executing package update."
apt-get update >/dev/null 2>&1
echo -e "Installing required packages, part I."
apt-get install -y build-essential libtool autotools-dev autoconf pkg-config libssl-dev >/dev/null 2>&1
apt-get install -y make automake git wget curl ufw bsdmainutils unzip >/dev/null 2>&1
apt-get install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, part II.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y libdb4.8-dev libdb4.8++-dev >/dev/null 2>&1
apt-get install -y libboost-all-dev >/dev/null 2>&1
apt-get install -y libminiupnpc-dev >/dev/null 2>&1
apt-get install -y libevent-dev >/dev/null 2>&1
apt-get install -y libgmp3-dev libzmq5 >/dev/null 2>&1
apt-get install -y libdb5.3++-dev >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
	echo "apt-get upgrade"
	echo "apt-get install -y build-essential libtool autotools-dev autoconf pkg-config libssl-dev"
    echo "apt-get install -y make automake git wget curl ufw bsdmainutils"
	echo "apt-get install -y software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt-get install -y libdb4.8-dev libdb4.8++-dev"
	echo "apt-get install -y libboost-all-dev"
	echo "apt-get install -y libminiupnpc-dev"
	echo "apt-get install -y libevent-dev"
	echo "apt-get install -y libgmp3-dev libzmq5"
	echo "apt-get install -y libdb5.3++-dev"
 exit 1
fi

clear
}

function create_swap() {
 echo -e "Checking if swap space is needed."
 PHYMEM=$(free -m|awk '/^Mem:/{print $2}')
 SWAP=$(free -m|awk '/^Swap:/{print $2}')
 if [ "$PHYMEM" -lt "1000" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 1G of RAM without SWAP, creating 2G swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
 else
  echo -e "${GREEN}Server running with at least 1G of RAM, no swap needed.${NC}"
 fi
 clear
}


function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "$COIN_NAME Masternode is up and running listening on port ${RED}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $COIN_NAME.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $COIN_NAME.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$COINKEY${NC}"
 echo -e "Please check ${RED}$COIN_NAME${NC} is running with the following command: ${RED}systemctl status $COIN_NAME.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  configure_systemd
}


function user_input() {
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
clear
echo && echo
echo -e "${GREEN}██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗"
echo -e "${GREEN}██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝"
echo -e "${GREEN}██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗  "
echo -e "${GREEN}██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝  "
echo -e "${GREEN}╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗"
echo -e "${GREEN} ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝"
echo -e "${NC}                                                                  "
echo && echo && echo
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"` #blue
    NUMBER=`echo "\033[31m"` #red
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[32m"` #green

    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}****Welcome to the PENG Masternode setup*****${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER} 1)${MENU} Install New Masternode               **${NORMAL}"
    echo -e "${MENU}**${NUMBER} 2)${MENU} Bootstrap Masternode                 **${NORMAL}"
    echo -e "${MENU}**${NUMBER} 3)${MENU} Exit                                 **${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Enter option and press enter. ${NORMAL}"
    read opt </dev/tty
    menu_loop

}

function menu_loop() {

while [ opt != '' ]
    do
        case $opt in
        1)newInstall;
        ;;
		2)bootstrap
        ;;
        3)echo -e "Exiting...";sleep 1;exit 0;
        ;;
        \n)exit 0;
        ;;
        *)clear;
        "Pick an option from the menu";
        user_input;
        ;;
    esac
done
}

function newInstall() {
clear
checks
prepare_system
create_swap
download_node
setup_node
exit 1
}

function bootstrap() {
# Make sure unzip is installed
clear
apt-get -qq update
apt -qqy install unzip

clear
echo "This script will refresh your masternode."
read -rp "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

if [ -e /etc/systemd/system/peng.service ]; then
  systemctl stop peng.service
else
  su -c "peng-cli stop" "root"
fi

echo "Refreshing node, please wait."

sleep 5

rm -rf "/root/.peng/blocks"
rm -rf "/root/.peng/chainstate"
rm -rf "/root/.peng/sporks"
rm -rf "/root/.peng/zerocoin"
rm -rf "/root/.peng/peers.dat"

echo "Installing bootstrap file..."

cd /root/.peng && wget https://github.com/coinpeng/pengcore_installer/releases/download/PENG/bootstrap.zip && unzip bootstrap.zip && rm bootstrap.zip

if [ -e /etc/systemd/system/peng.service ]; then
  sudo systemctl start peng.service
else
  su -c "pengd -daemon" "root"
fi

echo "Starting peng, will check status in 60 seconds..."
sleep 60

clear

if ! systemctl status peng.service | grep -q "active (running)"; then
  echo "ERROR: Failed to start peng. Please re-install using install script."
  exit
fi

echo "Waiting for wallet to load..."
until su -c "peng-cli getinfo 2>/dev/null | grep -q \"version\"" "$USER"; do
  sleep 1;
done

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can a few minutes. Do not close this window."
echo ""

until [ -n "$(peng-cli getconnectioncount 2>/dev/null)"  ]; do
  sleep 1
done

until su -c "peng-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\": true' > /dev/null" "$USER"; do 
  echo -ne "Current block: $(su -c "peng-cli getblockcount" "$USER")\\r"
  sleep 1
done

clear

cat << EOL

Now, you need to start your masternode. If you haven't already, please add this
node to your masternode.conf now, restart and unlock your desktop wallet, go to
the Masternodes tab, select your new node and click "Start Alias."

EOL

read -rp "Press Enter to continue after you've done that. " -n1 -s

clear

sleep 1
su -c "/usr/local/bin/peng-cli startmasternode local false" "$USER"
sleep 1
clear
su -c "/usr/local/bin/peng-cli masternode status" "$USER"
sleep 5

echo "" && echo "Masternode refresh completed." && echo ""
}

##### Main #####
clear
user_input
