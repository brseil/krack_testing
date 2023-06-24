#! /bin/sh

red='\033[0;31m'

green='\033[0;32m'

blue='\033[0;34m'

# before the reboot - setup
before_reboot(){
	#get right environment
	echo "${red}Installing the prerequisited packages..."
	sudo apt update
	sudo apt install libnl-3-dev libnl-genl-3-dev pkg-config libssl-dev net-tools git sysfsutils virtualenv

	#copy KRACK github repo locally
	path=$(pwd)
	echo "${red}Cloning KRACK repository..."
	git clone https://github.com/vanhoefm/krackattacks-scripts.git

	#setup the python environment
	echo "${red}Installing the Python environment..."
	cd krackattacks-scripts/krackattack
	./build.sh
	./pysetup.sh

	#disable hardware encryption as it will prevent us reading the frames
	echo "${red}Disabling Hardware encryption (needed for the tests)..." 
	sudo ./disable-hwcrypto.sh
	echo "${blue}Note that you can reenable it later on with ./reenable-hwcrypto.sh)"

	## note that you can reenable it later on with sudo ./reenable-hwcrypto.sh
	#prepare for reboot with cron job
	sudo systemctl enable cron.service && sudo systemctl restart cron.service
	line="@reboot sleep 15 ${path}/launch_KRACK.sh"
	(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -
	sudo touch /home/kali/krack__was_installed_dummy
	#reboot
	sudo reboot
}

# after the reboot - launch of tests
after_reboot(){
	#search for the krackattack-scripts directory
	d=$(sudo find / -type d -name "krackattacks-scripts" -print -quit 2>&1 | grep -v "Permission denied")
	echo "${green}Found krackattacks-scripts directory at ${d} - preparing for tests"
	cd $d
	cd ./krackattack
	#disable wifi in network manager & activate virtual python environment
	sudo rfkill unblock wifi
	sudo su << EOF
	source venv/bin/activate
	#get user's wifi interface
	read -p "Enter your WiFi interface name: " wnic
	#modify ./hostapd/hostapd.conf
	echo "${green}Configuring test hostapd with ${wnic}"
	echo "we're here $(pwd)"
	sudo sed -i "s/interface=.*/interface=$wnic/" ./hostapd.conf
	echo "${blue}#!# Note that the tested client needs to request its IP using DHCP !"
	echo "${green}Launching tests..."
	echo "${green}Test 1: krack-test-client.py"
	sudo python ./krack-test-client.py
EOF
}

# Starting point - checks if the script already rebooted
if [ -f /home/kali/krack_was_installed_dummy ]; then
	# removes previous cronjob reboot line
	echo "${green}Preparing for testing..."
	echo "${blue}#!# Deletion of reboot cronjob"
	crontab -l | grep "@reboot sleep 15" | crontab -

	after_reboot
else
	echo "${red}
	__________Welcome to the automated KRACK testing!___________
	--------* KRACK scripts made public by M.Vanhoef at --------
	......https://github.com/vanhoefm/krackattacks-scripts/....."
	before_reboot
fi
