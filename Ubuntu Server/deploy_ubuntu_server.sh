#!/bin/bash

logDir=$(echo "/var/log")$(echo $0 | cut -d. -f2)
logFile="$logDir/$(date +%Y%m%d).log"
wd=$(pwd)
codename=$(lsb_release -c | cut -f2)
dry_run=false
isVM=false
vboxguest_tools="virtualbox-guest-additions-iso"

declare -a full=(compile tools editors reverse misc_fun mpi gui xfce browsers databases)
declare -a manually=(atom hwinfo masscan)

declare -a editors=(vim atom)
declare -a gui=(xauth xorg openbox )
declare -a xfce=(xfwm4-themes xcfe4-session xfce4-terminal xfce4-goodies xfce4-power-manager ristretto thunar-volman gvfs policykit-1 )
declare -a compile=(build-essential gcc g++)
declare -a mpi=(openmpi-{bin,common,doc})
declare -a tools=(wget gddrescue htop hwinfo wpasupplicant wireless-tools p7zip brasero gparted git keepass2 john masscan nmap openvpn openssh-server youtube-dl)
declare -a misc_fun=(ascii ascii2binary figlet lolcat vlc)
declare -a reverser=(binwalk bless exif exifprobe exiftags exiv2 forensics-all)
declare -a browsers=(firefox chromium-browser)
declare -a databases=(mongodb sqlite3 sqlitebrowser mysql-server)

function check_conn(){
  ping -c 1 google.com >> /dev/null 2>&1
  if [[ ! "$(echo $?)" -eq 0 ]];then
    echo "Please check your internet connection and execute the script again"
    exit 2
  fi
}

function check_root(){
 if [[ $EUID -ne 0 ]]; then
   echo "This script needs root privilages"
   exit 1
  fi
}

function detectVM()
{
	(grep -q "^flags.* hypervisor " /proc/cpuinfo || return 1) && (echo "This machine is a VM" || return 0)
}

function create_log()
{
	echo "Logs at: $logDir"
	if [ ! -d "$logDir" ];then
		mkdir "$logDir"
		chown $USER:$SUDO_USER "$logDir"
		chmod 750 "$logDir"
	fi
	if [ ! -e $logFile ];then
    		touch "$logFile"
		chown root:$SUDO_USER "$logFile"
		chmod 640 "$logFile"
    	fi
		ls -la "$logDir"
		ls -la "$logFile"
}
app_in_manually()
{
	if [ "$(echo ${manually[@]} | grep -oi $1 | wc -w)" -eq 1 ]; then
		return 0;
	else
		return 1;
	fi
}
install_manually()
{
	which "$1"
	xstat=$?
	if [ $xstat -eq 0 ];then #already installed
		return 1
	fi
	case "$1" in
	masscan)
		#echo -e "\ndeb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-5.0 main\ndeb-src http://apt.llvm.org/trusty/ llvm-toolchain-trusty-5.0 main\n" > /etc/apt/sources.list.d/llvm_toolchain.list

		#chmod 644 /etc/apt/sources.list.d/llvm_toolchain.list
		#wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
		#apt-key update
		#apt update
		apt install -y git gcc make libpcap-dev
		git clone https://github.com/robertdavidgraham/masscan
		cd masscan
		sed -i "s/CC = .*/CC = gcc/" Makefile
		cat Makefile | grep -i "cc ="
		make -j 2
		make install
		stat=$?
		cd ..
		rm -r masscan
		if [ $stat -eq 0 ];then
			printf "[+] Package: $1 [OK]\n\t" >> "$logFile" && masscan -V >> "$logFile" && rm -r masscan && return 0
		else
			echo -e "[-] Error Occured while installing $1\n" >> "$logFile"
			return 1
		fi
		;;
	atom)
		add-apt-repository -y  ppa:webupd8team/atom  #Atom text editor
		apt update
		apt install -y atom
		which atom
		stat=$?
		cd ..
		rm -r atom
		if [ $stat -eq 0 ];then
			printf "[+] Package: $1 [OK]\n\t" >> "$logFile" && atom --version >> "$logFile" && rm -r atom && return 0
		else
			echo -e "[-] Error Occured while installing $1\n" >> "$logFile"
			return 1
		fi
		;;
	*)
		return 1
	esac
}
## Arguments "category_name" [--dry]
function install_categ()
{
  # filter the categories from the parameters given to the script
  categs_str=$(echo "$@" | tr [A-Z] [a-z] | tr ' ' '\n' | grep -oF "$( echo ${full[@]} | tr ' ' '\n')" - )

  # Convert categories String to Array
  for i in $(seq 1 $(echo $categs_str | wc -w));do
        categs_lst+=("$(echo $categs_str | cut -d\  -f$i)")
  done
  if [ ${#categs_lst} -eq 0 ] && [ ! "$(echo $@ | grep -o "full")" == "full" ];then echo "[+] No Categories Given! Exiting...";exit;fi

  # Check for dry run mode
  if [ "$(echo $1 | grep -io "^\-\-dry$")" == "--dry" ];then
    dry="echo Package: \$app"
    dry_run=true
  else
    dry="apt-get install -y \$app"
  fi
  # Create packages list from categories given in the input
  if [ "$(echo $@ | grep -o "full")" == "full" ];then
    for categ in ${full[@]};do
       categ="$categ[@]"
  	   apps+=("${!categ}")
    done
  else
    for categ in ${categs_lst[@]};do
      categ="$categ[@]"
      apps+=("${!categ}")
    done
  fi
  echo -e "Packages From Categories Given:\n${apps[@]}" >> "$logFile"

  ## Remove installed packages
  ## and packages that can't be installed via apt's ubuntu repositories
  ## from the 'apt to-install' list
	for app in ${apps[@]};do
		app_in_manually $app
		xstat=$?
    ## Remove packeges from 'to-install' list that do not exist in ubuntu's repositories
		if [ $xstat -eq 0 ];then
			if [ $(which $app | wc -w ) -gt 0 ];then
				apps=("${apps[@]/$app}")
			fi
		else
    ## Remove already installed packages from 'to-install' list
			pack=$(dpkg-query -f '${binary:Package}\n' -W | grep -io "^$app$" | head -n 1)
			apps=("${apps[@]/$pack}")
		fi
	done
  if $dry_run;then echo "[+] To install: ";fi
  if [ $(echo "${apps[@]}" | wc -w) -eq 0 ];then echo "[+] All selected categories are already installed!";exit;fi
  ## Install or show(dry run) installable packages
	for app in ${apps[@]};do
		app_in_manually $app
		xstat=$?
		if [ $xstat -eq 0 ];then
			if ! $dry_run ;then
				install_manually $app
				#xstat=$?
			else
				echo "Package: $app"
			fi
		else
			eval "$dry" #apt-get install -y $app"
			xstat=$?
			if ! $dry_run;then
				if [ "$xstat" -eq 0 ];then
					printf "[+] Package: $app [OK]\n\t" >> "$logFile"
					# Log version
					apt-cache policy $app | grep -i "installed:" | awk -F"Installed:" '{print $2}' >>  "$logFile"
				else
					echo -e "[-] Error Occured while installing $app \nFor more information check \"/var/log/apt/{term.log,history.log}\"" >> "$logFile"
				fi
			fi
		fi
	done
}
function list_pkgs()
{
  categs=$(echo "$@" | tr ' ' '\n' | grep -iF "$( echo ${full[@]} | tr ' ' '\n')" - | tr [A-Z] [a-z] )
  if [ "$(echo $1 | grep -io "^\-\-list$" )" == "--list" ];then
    echo "Running in list mode"
    if [ -z "$categs" ];then
		    echo "No category chosen! Listing all.."
        for categ in "${full[@]}";do
          echo -e "[+] $(echo ${categ:0:1} | tr [a-z] [A-Z])""${categ:1:15}"
          categ_lst="$categ[@]"
          echo -e "\t${!categ_lst}\n"
        done
    else
      for categ in "${categs[@]}";do
        echo -e "[+] $(echo ${categ:0:1} | tr [a-z] [A-Z])""${categ:1:15}"
        categ_lst="$categ[@]"
        echo -e "\t${!categ_lst}\n"
      done
    fi
    exit
  fi

}

if [ "$#" -lt 1 ];then
  echo "No parameters given"
  exit
fi
## if list mode is given the script exists
list_pkgs "$@"

check_conn
check_root

apt-get update
apt-get upgrade -y

## Start the logging process at "$logFile"
create_log

## Check if the deplying machine is Virtual
## and if sto install virtualbox guest additions
isVM=detectVM
if $isVM
then
	apt install -y $vboxguest_tools
fi
## Do the installation or list installable packages (dry run mode)
install_categ "$@"

#configure xfce
xfce_cf="$wd/xfce4_conf.tar"

if [ -e "$xfce_cf" ];then
	cd ~/
	tar -xf "$xfce_cf"
	cd "$wd"
else
	echo -e "[-] Warning: xfce4 configuration file not found in: $wd \nIf exists rename it to $xfce_cf"
fi
