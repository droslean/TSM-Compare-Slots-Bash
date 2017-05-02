# Compare Slot Script

The purpose of this bash script is to compare the slots of a TSM server 
with the slots of the Physical library.

TSM libvolumes generated with TSM commands and the Physical Library Inventory 
is generated with tapeutil or itdt command.

# Requirements

TSM client 5.x, 6.x or 7.x is required because the script is using dsmadmc command to 
connect to TSM server. 
The TSM information in the tsmlist.conf file must exist in dsm.sys of the TSM client.

# Configuration File

Format:
TSMNAME;tsmuser;tsmpass;tsmHost_hostname;tsmHost_IP;tsmHost_username;tsmHost_password

Example:
tsm1;admin;adminpass;linuxhost1;192.168.1.100;user;passw0rd

1 - Name of the TSM server ( this must exist in dsm.sys file with all the STANZA information.)

2 - Username to connect to the TSM server.

3 - Password to connect to the TSM server.

4 - Hostname of the server that TSM is hosted.

5 - Username to login to the server that TSM is hosted.

6 - Password to login to the server that TSM is hosted.


# Arguments

Usage: ./slots_global.sh *[-t TSM Name] [-r ALL|KO] [-v volume name]

-t [required] TSM server name.

-r [optional] How results will be shown. ALL or only KO. Default is ALL.

-v [optional] Volume name, to check only a single tape.

# Example Output

Select Library :
1 : LIBRARY1
2 : LIBRARY2
3 : LIBRARY3
Enter Number: 1
Selected library is LIBRARY1
Getting library's device information.
Device is : /dev/smc1                                                        

| Slot Number | TSM Entry 	| Physical Entry 	| Result 	|

|-----------------------------------------------------------------------|

|	 1027 	    | VOL1LT4 	  | VOL1LT4 		    |  OK  		|

|	 1028 	    | VOL2LT4 	  | VOL2LT4 		    |  OK  		|

|	 1029 	    | VOL3LT4 	  | VOL3LT4 		    |  OK  		|

|	 1030 	    | VOL4LT4 	  | VOL4LT4 		    |  OK  		|

|	 1031 	    | VOL5LT4 	  | EMPTY   		    |  KO  		|

|	 1032 	    | VOL6LT4 	  | EMPTY    		   |  KO  		|

|	 1033 	    | VOL7LT4 	  | VOL7LT4 		    |  OK  		|

|	 1034 	    | VOL8LT4 	  | EMPTY   		    |  OK  		| -> MOUNTED

|	 1035 	    | VOL9LT4 	  | VOL9LT4 		    |  OK  		|



# Licence

 GNU GENERAL PUBLIC LICENSE
 Version 3, 29 June 2007


