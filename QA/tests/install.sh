#!/usr/bin/bash -x

# LOG_LOCATION=./logs
# exec > >(tee -i $LOG_LOCATION/install.log)
# exec 2>&1

# if [[ ! -d ./logs || ! -d ./report ]]
# then
#   mkdir -p ./logs ./report
# fi

#rm  -rf  $LOG_LOCATION/* ./report/result.txt

ubuntu_conf(){
		sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
 		sudo apt install  python3-pip -y
		sudo apt install python3-ruamel.yaml -y
		echo "package download started"
		wget https://github.com/JanssenProject/jans/releases/download/v${VERSION}/jans_${VERSION}.${OS}.04_amd64.deb &>/dev/null
		wget https://github.com/GluuFederation/flex/releases/download/v${VERSION}/flex_${VERSION}.${OS}.04_amd64.deb &>/dev/null
		echo "package downloaded"
EOF
}
rhel_centos_conf(){
			
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
			sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
			sudo yum -y module enable mod_auth_openidc 
			sudo yum update -y
			sudo yum install  python3-pip -y
			sudo yum  install -y wget python3-certifi python3-ldap3 python3-prompt-toolkit python3-ruamel-yaml
			echo "downloading package"
			wget https://github.com/JanssenProject/jans/releases/download/v${VERSION}/jans-${VERSION}-el8.x86_64.rpm &>/dev/null
			wget https://github.com/GluuFederation/flex/releases/download/v${VERSION}/flex-${VERSION}-el8.x86_64.rpm &>/dev/null
			
			sudo reboot
			
			
EOF
}
suse_conf(){
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			echo "downloading package"
			wget https://github.com/JanssenProject/jans/releases/download/v${VERSION}/jans-${VERSION}-suse15.x86_64.rpm &>/dev/null
			wget https://github.com/GluuFederation/flex/releases/download/v${VERSION}/flex-${VERSION}-suse15.x86_64.rpm &>/dev/null
			#sudo zypper addrepo https://download.opensuse.org/repositories/home:frispete:python/15.4/home:frispete:python.repo
			sudo zypper --non-interactive --gpg-auto-import-keys refresh
			sudo zypper --non-interactive --gpg-auto-import-keys install python3-PyMySQL
			sudo wget https://rpmfind.net/linux/opensuse/distribution/leap/15.4/repo/oss/x86_64/python3-ruamel.yaml.clib-0.2.0-1.1.x86_64.rpm
			sudo wget https://rpmfind.net/linux/opensuse/distribution/leap/15.4/repo/oss/noarch/python3-ruamel.yaml-0.16.10-1.1.noarch.rpm
			sudo zypper install -y ./python3-ruamel.yaml.clib-0.2.0-1.1.x86_64.rpm
			sudo zypper install -y ./python3-ruamel.yaml-0.16.10-1.1.noarch.rpm
			echo "package Downloaded"
EOF
}
uninstall_jans() {

	echo "checking  jans server installed"
	sudo ssh -T -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
# sudo chmod -R 755 /opt/jans/ >/dev/null
#if [[ -f /opt/jans/jans-cli/config-cli.py ]]; then
# echo "jans server is already installed"


if [[ $OS == "ubuntu20" ]] || [[ $OS == "ubuntu22" ]]
then
	sudo apt remove -y jans
	sudo apt remove -y flex
	sudo python3 install.py -uninstall -y
	sudo apt-get remove --purge -y mysql*;sudo apt-get purge -y  mysql*;sudo apt-get -y autoremove;
	sudo apt-get -y autoclean;sudo apt-get remove -y dbconfig-mysql;sudo rm -r -f /var/lib/mysql
	sudo apt  remove  -y postgresql postgresql-doc postgresql-common
	sudo apt-get --purge remove -y postgresql postgresql-14 postgresql-client-common postgresql-common postgresql-contrib
	sudo mv -f /var/lib/pgsql /var/lib/pgsql_old_$$
	sudo apt remove -y opendj-server
	sudo /opt/opendj/uninstall -a --no-prompt
	sudo rm -rf  /opt/opendj/lib
	sudo rm -rf ~/jans-*
	sudo apt autoremove -y
	
elif [[ $OS == "suse" ]]
then
	sudo zypper remove -y jans
	sudo zypper remove -y flex
	sudo python3 install.py  -uninstall -y
	sudo zypper remove -y mysql mysql-server 
	sudo mv -f /var/lib/mysql /var/lib/mysql_old_$$
	sudo zypper remove -y postgresql postgresql-contrib postgresql-server
	sudo mv -f /var/lib/pgsql /var/lib/pgsql_old_$$
	sudo zypper remove -y opendj-server
	sudo /opt/opendj/uninstall -a --no-prompt
	sudo rm -rf  /opt/opendj/lib
	sudo rm -rf ~/jans-*.*

elif [[ $OS == "rhel" ]]
then
	sudo yum remove -y jans
	sudo yum remove -y flex
	sudo python3 install.py -uninstall -y
	sudo yum remove -y mysql mysql-server 
	sudo mv -f /var/lib/mysql /var/lib/mysql_old_$$
	sudo yum  remove -y  postgresql postgresql-doc postgresql-common  postgresql-contrib postgresql-server
	sudo mv -f /var/lib/pgsql /var/lib/pgsql_old_$$
	sudo yum remove -y opendj-server
	 sudo /opt/opendj/uninstall -a --no-prompt
	sudo rm -rf  /opt/opendj/lib
	sudo rm -rf ~/jans-*.*
fi
#else
#echo "jans server is not installed"
#fi
exit
EOF

}

install_jans() {

	rm setup.properties install.py flex_setup.py
	ORG_NAME=test
	EMAIL=test@test.org
	CITY=pune
	STATE=MH
	COUNTRY=IN
	ADMIN_PASS="Admin@123"
	LDAP=True
	echo "*****   Writing properties!!   *****"
	echo "ip=${IPADDRESS}" | tee -a setup.properties >/dev/null
	echo "hostname=${HOSTNAME}" | tee -a setup.properties >/dev/null
	echo "orgName=${ORG_NAME}" | tee -a setup.properties >/dev/null
	echo "admin_email=${EMAIL}" | tee -a setup.properties >/dev/null
	echo "city=${CITY}" | tee -a setup.properties >/dev/null
	echo "state=${STATE}" | tee -a setup.properties >/dev/null
	echo "countryCode=${COUNTRY}" | tee -a setup.properties >/dev/null
	echo "ldapPass=${ADMIN_PASS}" | tee -a setup.properties >/dev/null
	echo "gluu-passwurd-cert=True" | tee -a setup.properties >/dev/null
	echo "install-admin-ui=True" | tee -a setup.properties >/dev/null
	echo "install-casa=True" | tee -a setup.properties >/dev/null
	echo "admin-ui-ssa=ssa.txt" | tee -a setup.properties >/dev/null

	if [[ $DB == opendj ]]; then
		echo "installLdap=${LDAP}" | tee -a setup.properties >/dev/null
	elif [[ $DB == mysql ]]; then
		echo "rdbm_install=${LDAP}" | tee -a setup.properties >/dev/null
		echo "rdbm_install_type=1" | tee -a setup.properties >/dev/null
	elif [[ $DB == pgsql ]]; then
		echo "rdbm_install=${LDAP}" | tee -a setup.properties >/dev/null
		echo "rdbm_install_type=1" | tee -a setup.properties >/dev/null
		echo "rdbm_type=pgsql" | tee -a setup.properties >/dev/null

	elif [[ $DB == couchbase ]]; then
		echo "rdbm_install=False" | tee -a setup.properties >/dev/null
		echo "rdbm_install_type=0" | tee -a setup.properties >/dev/null
		echo "rdbm_type=mysql" | tee -a setup.properties >/dev/null
		echo "cb_install=1" | tee -a setup.properties >/dev/null
		echo "cb_password=Admin@123" | tee -a setup.properties >/dev/null
		echo "persistence_type=couchbase" | tee -a setup.properties >/dev/null
	else
		echo "please select any DB"
	fi
	
		echo "$FLEX_OR_JANS installation started"
	if [[ "$OS" == "ubuntu22" ]] || [[ "$OS" == "ubuntu20" ]] &&  [[ "$FLEX_OR_JANS" == "jans" ]];
	then
	echo "$OS configuration started"
		ubuntu_conf
	elif [[ "$OS" == "rhel" ]] || [[ "$OS" == "centos" ]] && [[ "$FLEX_OR_JANS" == "jans" ]];
	then
	echo "$OS configuration started"
		rhel_centos_conf
	elif [[ "$OS" == "suse" ]] && [[ "$FLEX_OR_JANS" == "jans" ]];
	then
	echo "suse configuration started"
		suse_conf
	elif [[ "$OS" == "ubuntu22" ]] || [[ "$OS" == "ubuntu20" ]] && [[ "$FLEX_OR_JANS" == "flex" ]]; 
	then
		echo "ubuntu configuration started"
		ubuntu_conf
	elif [[ "$OS" == "rhel" ]] || [[ "$OS" == "centos" ]] && [[ "$FLEX_OR_JANS" == "flex" ]]; 
	then
	echo "ubuntu configuration started"
		rhel_centos_conf
	elif [[ "$OS" == "suse" ]] && [[ "$FLEX_OR_JANS" == "flex" ]]; 
	then
	echo "suse configuration started"
		suse_conf
	else
		echo "db not selected"
	fi
	# if [[ $OS == rhel ]] || [[ $OS == centos ]] || [[ $OS == ubuntu ]] || [[ $OS == suse ]] && [[ $DB == couchbase ]] ;
	# 	then
	#                         sudo mkdir -p /opt/dist/couchbase
	#                         cd /opt/dist/couchbase
	# 						echo "***********************************************************$PWD"
	# 			if [[ $OS == rhel ]] || [[ $OS == centos ]]
	# 			then
	#  			sudo wget https://packages.couchbase.com/releases/7.1.1/couchbase-server-enterprise-7.1.1-rhel8.x86_64.rpm
	# 			cd ~
	# 			elif [[ $OS == ubuntu22 ]]
	# 			then
	# 			echo "$PWD"
	# 			sudo wget https://packages.couchbase.com/releases/7.1.1/couchbase-server-enterprise_7.1.1-ubuntu20.04_amd64.deb
	# 			cd ~
	# 			elif [[ $OS == suse ]]
	# 			then
	# 			sudo wget https://packages.couchbase.com/releases/7.1.1/couchbase-server-enterprise-7.1.1-suse15.x86_64.rpm
	# 			else
	# 			echo " no couchbase DB rpm found "
	# 			fi
	# 	else
	# 			echo " OS not found"
	# fi
	sleep 150 &&
	SSA="eyJraWQiOiJzc2FfYzY5ZjQ0MjUtYWYwMS00OTA0LThiNmMtOGMyYjQwN2YxNzhmX3NpZ19yczI1NiIsInR5cCI6Imp3dCIsImFsZyI6IlJTMjU2In0.eyJzb2Z0d2FyZV9pZCI6InNhZmlud2FzaS10ZXN0LXNzYS1hbGwiLCJncmFudF90eXBlcyI6WyJjbGllbnRfY3JlZGVudGlhbHMiXSwib3JnX2lkIjoiZ2l0aHViOlNhZmluV2FzaSIsImlzcyI6Imh0dHBzOi8vYWNjb3VudC5nbHV1Lm9yZyIsInNvZnR3YXJlX3JvbGVzIjpbInBhc3N3dXJkIiwibGljZW5zZSIsInN1cGVyZ2x1dSJdLCJleHAiOjE3NjcyMzY5MjgsImlhdCI6MTY4MjAyNTcwOCwianRpIjoiNDU4ZWQ2YzMtMDdkMS00NWUyLTgzNTYtMWZiOTU5ZTZkODMwIn0.qOwhhFXUjwO03rZ48Ww2BKsSYAXyq4M1H04K79BO75YKCjtHb5CM8-ljm4OEM3j55MDsJftxf2qq3TJnBHOjDN82dHRT3sqZQXC7OdSJpgNaGXPlnewCgswSVrPZO5lXcrjR_liOHBJw1_-P6X0Rp6eQtO3CH2J6DVHU2qRJbZZr6gWeggAT6Xk4TIkyZnhEp2_97KrQRSFwlxSmNKEQBf4ZRwiq_DwFg_ZCGYGCQUv-SORAQ9brJfXKjxQwPdLCK2AEhJCHcLQAHhTQEQk9z9XJ9XYaHgIuHMTZkE7xNRPKaW91VuprSeAP0DYD_BTyZeE00suo0fKQKND1hKBvLQ"
	echo "$SSA" > ssa.txt
	curl https://raw.githubusercontent.com/JanssenProject/jans/v${VERSION}/jans-linux-setup/jans_setup/install.py >install.py
	curl https://raw.githubusercontent.com/GluuFederation/flex/v${VERSION}/flex-linux-setup/flex_linux_setup/flex_setup.py >flex_setup.py

	sudo scp -i  ${PRIVATE} ssa.txt setup.properties install.py flex_setup.py ${USERNAME}@${IPADDRESS}:~/
	
	rm setup.properties install.py flex_setup.py ssa.txt

	echo " installation started"
	if [[ "${PACKAGE_OR_ONLINE}" == "online" ]]  && [[ "$FLEX_OR_JANS" == "jans" ]]; then

	echo "install downloaded"
	sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
	sudo python3 install.py -y --args="-f setup.properties -c -n" 
	rm setup.properties install.py flex_setup.py ssa.txt *.rpm *.deb
	
EOF
		echo " installation ended"
	elif [[ ${PACKAGE_OR_ONLINE} == "package" ]]  && [[ "$FLEX_OR_JANS" == "jans" ]]; then
		echo "package installation started"
		if [[ ${OS} == "suse" ]]; then
			echo "${OS} package installation started"
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			sudo zypper --no-gpg-checks install -y ./jans-${VERSION}-suse15.x86_64.rpm
			sudo python3 /opt/jans/jans-setup/setup.py -f setup.properties -n -c
			rm setup.properties install.py flex_setup.py ssa.txt *.rpm 
EOF
		fi
		if [[ ${OS} == "rhel" ]]  && [[ "$FLEX_OR_JANS" == "jans" ]]; then
			echo "${OS} package installation started"
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			sudo yum install -y ./jans-${VERSION}-el8.x86_64.rpm
			echo "running setup "
			sudo python3 /opt/jans/jans-setup/setup.py -f setup.properties -n -c
			rm setup.properties install.py flex_setup.py ssa.txt *.rpm 
EOF
		fi
		if [[ ${OS} == "ubuntu20" ]] || [[ ${OS} == "ubuntu22" ]]  && [[ "$FLEX_OR_JANS" == "jans" ]]; then
			echo "${OS} package installation started"
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			sudo apt install -y ./jans_${VERSION}.${OS}.04_amd64.deb
			sudo python3 /opt/jans/jans-setup/setup.py -f setup.properties -n -c
			rm setup.properties install.py flex_setup.py ssa.txt  *.deb
EOF
		fi
	fi


	if [[ ${PACKAGE_OR_ONLINE} == "online" ]]  && [[ "$FLEX_OR_JANS" == "flex" ]]; then
		sudo ssh	 -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
		sed -i 's,ssa.txt,'"$HOME"'\/ssa.txt,' setup.properties
		sudo python3 flex_setup.py -y -f setup.properties --flex-non-interactive 
		rm setup.properties install.py flex_setup.py ssa.txt *.rpm *.deb
		cd /opt/jans/jetty/casa
		sudo touch .administrable
EOF
		echo " installation ended"
	elif [[ ${PACKAGE_OR_ONLINE} == "package" ]]  && [[ "$FLEX_OR_JANS" == "flex" ]]; then
		echo "package installation started"
		if [[ ${OS} == "suse" ]]; then
			echo "${OS} package installation started"
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			sudo zypper --no-gpg-checks install -y ./flex-${VERSION}-suse15.x86_64.rpm
			sed -i 's,ssa.txt,\/home\/ec2-user\/ssa.txt,' setup.properties
			sudo python3 /opt/jans/jans-setup/flex/flex-linux-setup/flex_setup.py  -f setup.properties -n -c --flex-non-interactive
			echo "installation completed"
			rm setup.properties install.py flex_setup.py ssa.txt *.rpm
			cd /opt/jans/jetty/casa
			sudo touch .administrable	
exit
EOF
		fi
		if [[ ${OS} == "rhel" ]]  && [[ "$FLEX_OR_JANS" == "flex" ]]; then
			echo "${OS} package installation started"
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			sudo yum install -y ./flex-${VERSION}-el8.x86_64.rpm
			sed -i 's,ssa.txt,\/home\/ec2-user\/ssa.txt,' setup.properties
			sudo python3 /opt/jans/jans-setup/flex/flex-linux-setup/flex_setup.py  -f setup.properties -n -c --flex-non-interactive
			echo "installation completed"
			rm setup.properties install.py flex_setup.py ssa.txt *.rpm
			cd /opt/jans/jetty/casa
			sudo touch .administrable
exit			
EOF
		fi
		if [[ ${OS} == "ubuntu20" ]] || [[ ${OS} == "ubuntu22" ]]  && [[ "$FLEX_OR_JANS" == "flex" ]]; then
			echo "${OS} package installation started"
			sudo ssh -i ${PRIVATE} ${USERNAME}@${IPADDRESS} <<EOF
			sudo apt install -y ./flex_${VERSION}.${OS}.04_amd64.deb
			sed -i 's,ssa.txt,\/root\/ssa.txt,' setup.properties
			sudo python3 /opt/jans/jans-setup/flex/flex-linux-setup/flex_setup.py  -f setup.properties -n -c --flex-non-interactive
			rm setup.properties install.py flex_setup.py ssa.txt *.deb
			cd /opt/jans/jetty/casa
			sudo touch .administrable
			echo "installation completed"
exit
EOF
		fi

	fi

}

helpFunction() {
	echo "Usage: ./install.sh -i IPADDRESS -h HOSTNAME -u USERNAME -k PRIVATE -d DB -o OS  -b VERSION -p PACKAGE_OR_ONLINE -f FLEX_OR_JANS"
	echo -e "EX: ./install.sh  3.10.10.22  manojs1978-pleasing-goldfish.gluu.info  ec2-user  /home/manoj/private_suse_aws.pem   ldap  ubuntu22 OR suse OR rhel OR ubuntu20  1.0.12 OR 1.0.13.nightly  package jans"
	exit 1 # Exit script after printing help
}

unset IPADDRESS HOSTNAME USERNAME DB OS PACKAGE_OR_ONLINE FLEX_OR_JANS
while getopts i:h:u:k:d:o:b:p:f: option; do
	case "${option}" in
	i) IPADDRESS=${OPTARG} ;;
	h) HOSTNAME=${OPTARG} ;;
	u) USERNAME=${OPTARG} ;;
	k) PRIVATE=${OPTARG} ;;
	d) DB=${OPTARG} ;;
	o) OS=${OPTARG} ;;
	b) VERSION=${VERSION} ;;
	p) PACKAGE_OR_ONLINE=${PACKAGE_OR_ONLINE} ;;
	f) FLEX_OR_JANS=${FLEX_OR_JANS}
	esac
done

IPADDRESS=$1
HOSTNAME=$2
USERNAME=$3
PRIVATE=$4
DB=$5
OS=$6
VERSION=$7
PACKAGE_OR_ONLINE=$8
FLEX_OR_JANS=$9

# echo "Begin script in case all parameters are correct"
# echo "your ip address is: ${IPADDRESS}"
# echo "your hostname is:  ${HOSTNAME}"
# echo "your username is: ${USERNAME}"
# echo "your DB is: ${DB}"
# echo "your  OS is:  ${OS}"
# echo "your VERSION is: ${VERSION}"
# echo "installation type is: ${PACKAGE_OR_ONLINE}"
# echo "your are installing server : ${FLEX_OR_JANS}"

if [ -z ${IPADDRESS} ] && [ -z ${HOSTNAME} ] && [ -z ${USERNAME} ] && [ -z ${PRIVATE} ] && [ -z ${DB} ] && [ -z ${OS} ] && [ -z ${VERSION} ] && [ -z ${PACKAGE_OR_ONLINE} ] && [ -z ${FLEX_OR_JANS} ]; then
	echo " some parameter are empty please check below instructions"
	helpFunction
else
	uninstall_jans
	install_jans
fi