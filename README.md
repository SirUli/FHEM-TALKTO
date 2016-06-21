# TALKTO for FHEM
TALKTOME and TALKTOUSERS are fhem modules for interactive conversations with FHEM based on Rivescript

## How to install
The Perl module can be loaded directly into your FHEM installation. For this please copy the below command into the FHEM command line.

	update all https://raw.githubusercontent.com/SirUli/FHEM-TALKTO/master/controls_talkto.txt

### Rename Template

Rename the file FHEM/TALKTOME.rive.template to FHEM/TALKTOME.rive and edit if you like
	
### Create ONE device as master (this is the chatbot)
	
	define FHEMTALKTOME TALKTOME
	
### Create user devices for the individual users

	define TALKTOUSER_ULI TALKTOUSER
	
### Attributes #

## How to Update
The Perl module can be update directly with standard fhem update process. For this please copy the below command into the FHEM command line.

	update add https://raw.githubusercontent.com/SirUli/FHEM-TALKTO/master/controls_talkto.txt

To check if a new version is available execute follow command

	update check talkto

To update to a new version if available execute follow command

	update all

or

	update all talkto