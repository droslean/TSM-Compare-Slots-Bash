#!/bin/bash

#####################################################################################
#																					#
# Author Nikolaos Moraitis < droslean@gmail.com > 									#
# This script has been written to easily compare slots between 						#
# TSM assigned volume and the true element location in the Physical library. 		#
#																					#
#####################################################################################

set -o nounset


#####################################################################################
#																					#
# This is a menu that list all libraries found in the TSM server. 					#
# The user has to choose one of those. Then all the libvolumes will be listed 		#
# and the script will compare them with the physical element information. 			#
# 																					#
# Arguments 																		#
#			1 -  Libraries list array. 												#
#																					#
#####################################################################################
function menu() {
  declare -a libraries=("$@")
  local -i counter=0;
  echo "Select Library :" >&2;
  for i in "${libraries[@]}"
  do
    counter+=1;
    echo "$counter : $i" >&2;
  done
}



#################################################################################
#																				#
# Get library from user input selection, through a menu of library list. 		#
#																				#
# Arguments 																	#
#			1 - TSM server 														#
#			2 - TSM username													#
#			3 - TSM password 													#
#																				#
# Returns the library name 														#
#																				#
#################################################################################
function selectLibrary(){
  local tsmCmd="dsmadmc -se=$1 -id=$2 -pa=$3";

  # Get libraries available on TSM server.
  local libraries=$($tsmCmd -dataonly=yes "select LIBRARY_NAME from libraries");

  # Create libraries as array
  declare -a libs;
  while read -r line; do
    libs+=("$line")
  done <<< "$libraries"

  	local correctInput=false
	while  [ "$correctInput" = false ]; do
		# Show the menu
  		menu "${libs[@]}"
  		read -p "Enter Number: " userSelection

    	if ! [[ $userSelection =~ ^[0-9]+$ ]] ; then
   		 	echo -e "\nThis is NOT a number" >&2;
   		elif [ $userSelection -gt ${#libs[@]} ] || [ $userSelection -eq 0 ]; then
			echo -e "\nTry again....." >&2;
    	else
    		correctInput=true;
    	fi
	done

  	echo "${libs[$userSelection-1]}";
}



 ############################################################
 # Generate the library's inventory from the remote host. 	#
 #															#
 # Arguments 												#
 #				1 - IP 										#
 #				2 - username								#
 #				3 - password 								#
 #				4 - Device 									#
 #				5 - Output log 								#
 #															#
 ############################################################
function getLibraryInventory() {
 local cmd="sshpass -p $3 ssh -q $2@$1";

 $cmd "tapeutil -f $4 inventory" > $5;
 local sshRC=$?
 if [[ $sshRC -eq 1 || $sshRC -eq 127 ]]; then
	echo "Tapeutil command failed, I will try again with itdt instead...";
	$cmd "itdt -f $4 inventory" > $5;

	if [[ $? -eq 1 || $sshRC -eq 127 ]]; then
		echo "Failed again..Maybe commands are not exist or there is a permission issue."
		echo -e "\e[39m";
        	return 4;
	else
		echo "itdt command worked. Continue...";
		return 0;
	fi

 elif [ $sshRC -eq 5 ] || [ $sshRC -eq 255 ]; then
 	echo "Can't login. Exiting...";
 	echo -e "\e[39m";
 	return 5;
 fi
}



#####################################################
# Generate the output with the Results 				#
#													#
# Arguments 										#
#			1 - Physical Library Inventory file 	#
#			2 - TSM libvolumes list file 			#
#			3 - Mounted volumes 					#
#													#
#####################################################
function compareAllTapes(){
	local LibraryInventory=$1;
	local LibvolumesFile=$2;
	local mountedVolumes=$3;

	# Get all slots from Physical Library
	local slots=$(cat $LibraryInventory | grep 'Slot Address'|awk '{print $3}');

	# Check for errors :
	if [[ "$slots" == "" ]]; then
		echo -e "\nError while accessing the Library:\n";
		echo $(cat $LibraryInventory);
		echo -e "\n\e[39m";
		exit 11;

	# In some libraries the output of Inventory is different
	# Examples :
	# 1) Slot Address ................... 1046
	# 2) Slot Address 1046
	elif [[ "$slots" == *"...."* ]]; then
		local slots=$(cat $LibraryInventory | grep 'Slot Address'|awk '{print $4}');
	fi

	# Print Titles of the table
	echo -e "\n| Slot Number 	| TSM Entry 	| Physical Entry 	| Result 	|";
	echo "|-----------------------------------------------------------------------|";

 	# For each slot, compare the volumes with TSM and the Physical Library.
  	for element in $(echo $slots)
  	do
    	local tsmVolume=$(cat $LibvolumesFile | grep -w $element | awk '{print $1}');
    	local volumeInLibrarySlot=$(cat $LibraryInventory |	sed -n '/Slot Address.* '$element'/,/Volume Tag/p' |tail -1 | awk '{print $4}');

    	if [[ -z $tsmVolume]]; then
    		tsmVolume="EMPTY";
    	fi

    	if [[ -z $volumeInLibrarySlot ]]; then
    		volumeInLibrarySlot="EMPTY";
    	fi


   		if [[ "$tsmVolume" == "$volumeInLibrarySlot" ]]; then
			result=" \e[92mOK\e[97m ";
			if [[ "$onlyKO" != true ]]; then
				echo -e "|	 $element 	| $tsmVolume 	| $volumeInLibrarySlot 		| $result 		|";
			fi

		elif [[ "$tsmVolume" == "$(echo $mountedVolumes | grep -o $tsmVolume )" ]]; then
			result=" \e[92mOK\e[97m ";
			if [[ "$onlyKO" != true ]]; then
				echo -e "|	 $element 	| $tsmVolume 	| $volumeInLibrarySlot 		| $result 		| -> \e[44mMOUNTED\e[49m";
			fi
		else
			result=" \e[41mKO\e[49m ";
			echo -e "|	 $element 	| $tsmVolume 	| $volumeInLibrarySlot 		| $result 		|";
		fi
    done
}


#########################################################################
# Compare TSM library with the Physical Library for a single tape.		#
#																		#
# Arguments 															#
#			1 - Tape 													#
#			2 - TSM libvolumes file 									#
#			3 - Physical library Inventory file 						#
#			4 - Mounted volumes 										#
#																		#
#########################################################################
function compareTape(){
	local tape=$1;
	local LibvolumesFile=$2;
	local LibraryInventory=$3;
	local mountedVolumes=$4;

	local tsmElement=$(cat $LibvolumesFile | grep $tape | awk '{print $2}');
	if [[ -z $tsmElement ]]; then
		tsmElement="EMPTY";
	fi

	local elementInLibrarySlot=$(tac $LibraryInventory |\
	 	sed -n '/'$tape'/{p; :loop n; p; /Slot Address.*/q; b loop}' |\
	  	tail -1 | awk '{print $3}');

	if [[ "$elementInLibrarySlot" == "" ]]; then
		elementInLibrarySlot="EMPTY";
	fi

	echo "Getting details for volume $tape";
	echo "Slot in TSM Server : $tsmElement";
	echo "Slot in Physical library : $elementInLibrarySlot"

	if [[ "$tsmElement" == "$elementInLibrarySlot" ]]; then
		result=" \e[92mOK\e[97m "
	else
		if [[ "$tape" == "$(echo $mountedVolumes | grep -o $tape )" ]]; then
			result=" \e[92mOK\e[97m \e[44mMOUNTED\e[49m";
		else
			result=" \e[41mKO\e[49m";
		fi
	fi

	echo -e "Result : $result";
}


function usage() {
	echo "Usage: $0 *[-t TSM Name] [-r ALL|KO] [-v Volume Name]" 1>&2;
	echo "-t [required] TSM server name." 1>&2;
	echo "-r [optional] How results will be shown. ALL or only KO. Default is ALL." 1>&2;
	echo "-v [optional] Volume name, to check only a single tape." 1>&2;

	exit 1;
}

#################################################
#												#
#	Main Part of the script 					#
#												#
#################################################

# Set white color.
echo -e "\e[97m";

# Declare variables
workDir=$(dirname $0);
LibraryInventory="$workDir/LibraryInventory";
LibvolumesFile="$workDir/LibvolumesFile";
showResult="ALL";
onlyKO=false;
isTsm=false;
singleTape=false


while getopts :t:r:v: option
do
        case "${option}" in
                t)
					tsmName=${OPTARG};
					isTsm=true;
				;;

                r)
					showResult=${OPTARG};
					if [[ $(echo ${OPTARG} | awk '{print toupper($0)}') == "ALL" ]] \
						|| [[ $(echo ${OPTARG} | awk '{print toupper($0)}') == "KO" ]]; then
						showResult=$(echo ${OPTARG} | awk '{print toupper($0)}');
						else
						usage;
					fi
				;;

				v)
					volumeName=${OPTARG};
					singleTape=true;
				;;

				*)
					usage;
				;;
        esac
done

# Check for required arguments.
if ! $isTsm; then
	usage
	exit 1;
fi


# Checking if KO specified in -r argument.
if [[ "$showResult" == "KO" ]] ; then
	onlyKO=true;
fi

if [[ ! -f tsmlist.conf ]]; then
	echo -e "Configuration file NOT found!\n";
	exit 1;
fi

# Get all TSM info from the configuration file.
# TSM name, TSM username and password,
# TSM host IP,username and password.
if [[ $(cat tsmlist.conf | cut -d\; -f1 | grep -w $tsmName) = "" ]]; then
	echo -e "TSM server not found in the configuration file.\n"
	exit 1;
else
	allInfo=$(cat tsmlist.conf | grep -w $tsmName);
	tsmUser=$(echo $allInfo | cut -d\; -f2);
	tsmPass=$(echo $allInfo | cut -d\; -f3);
	tsmHostIP=$(echo $allInfo | cut -d\; -f5);
	tsmHostUser=$(echo $allInfo | cut -d\; -f6);
	tsmHostPass=$(echo $allInfo | cut -d\; -f7);
fi

tsmCmd="dsmadmc -se=$tsmName -id=$tsmUser -pa=$tsmPass";

if $singleTape; then

	selectedLibrary=$($tsmCmd -dataonly=yes "select library_name from libvolumes where volume_name='$volumeName'");
	if [[ $selectedLibrary == "ANR2034E"* ]]; then
		echo -e "Volume not found on TSM.\n";
		exit 1;
	fi

	echo "Volume has been found in library $selectedLibrary";
	libVolumes=$($tsmCmd -outfile=$LibvolumesFile -tab -dataonly=yes "select VOLUME_NAME,HOME_ELEMENT from libvolumes where library_name='$selectedLibrary' ORDER BY 2");
	echo "Getting library's device information."
	device=$($tsmCmd -dataonly=yes "select device from paths where DESTINATION_TYPE='LIBRARY' and DESTINATION_NAME='$selectedLibrary'");
	echo "Device is : $device";
	# Get Mounted volumes
	mountedVolumes=$($tsmCmd -dataonly=yes -tab "select volume_name from drives where DRIVE_STATE='LOADED' and LIBRARY_NAME='$selectedLibrary' ");

	# Try to get Inventory of the Physical library.
	getLibraryInventory "$tsmHostIP" "$tsmHostUser" "$tsmHostPass" "$device" "$LibraryInventory"
	if [[ $? -eq 0 ]]; then
		# Finally compare the slots.
		compareTape "$volumeName" "$LibvolumesFile" "$LibraryInventory" "$mountedVolumes";
	fi

else

	selectedLibrary=$(selectLibrary $tsmName $tsmUser $tsmPass | tail -1);
	echo "Selected library is $selectedLibrary";

	# Get all volumes and slots assigned in the selected Library
	libVolumes=$($tsmCmd -outfile=$LibvolumesFile -tab -dataonly=yes "select VOLUME_NAME,HOME_ELEMENT from libvolumes where library_name='$selectedLibrary' ORDER BY 2");


	echo "Getting library's device information."
	# Get selected Library's device.
	device=$($tsmCmd -dataonly=yes "select device from paths where DESTINATION_TYPE='LIBRARY' and DESTINATION_NAME='$selectedLibrary'");
	echo "Device is : $device";

	# Get Mounted volumes
	mountedVolumes=$($tsmCmd -dataonly=yes -tab "select volume_name from drives where DRIVE_STATE='LOADED' and LIBRARY_NAME='$selectedLibrary' ");

	# Try to get Inventory of the Physical library.
	getLibraryInventory "$tsmHostIP" "$tsmHostUser" "$tsmHostPass" "$device" "$LibraryInventory"
		if [[ $? -eq 0 ]]; then
			# Finally compare the slots.
			compareAllTapes "$LibraryInventory" "$LibvolumesFile" "$mountedVolumes"
		fi
fi

# Clear the colors
echo -e "\n\e[39m";

# Just in case
exit 0;