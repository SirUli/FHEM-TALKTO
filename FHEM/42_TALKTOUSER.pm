# $Id$
##############################################################################
#
#     42_TALKTOUSER.pm
#     Device Family for the TALKTOME device which contains user-specific data
#
#     Author: Uli Wolf (UW)
#     E-Mail: fhem [at] wolf [-] u [dot] li
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
# Version History:
# 2015-11-10 - UW - Started Development
# 2016-06-21 - UW - Initial Version for FHEM Forum
#
##############################################################################

package main;
use strict;
use warnings;
use POSIX;
use utf8;
use msgSchema;

###################################
sub TALKTOUSER_Initialize($) {
    my ($hash) = @_;

    Log3 $hash, 5, "TALKTOUSER_Initialize: Entering";

	$hash->{Match}       = "^TALKTOUSER";
    $hash->{SetFn}       = "TALKTOUSER_Set";
    $hash->{DefFn}       = "TALKTOUSER_Define";
    $hash->{NotifyFn}    = "TALKTOUSER_Notify";
	$hash->{ParseFn}     = "TALKTOUSER_Parse";
    $hash->{UndefFn}     = "TALKTOUSER_Undefine";
	$hash->{AttrFn}      = "TALKTOUSER_Attr";
    $hash->{AttrList}    = "IODev disable:0,1 realname nomatch noreply " . $readingFnAttributes;
}

###################################
sub TALKTOUSER_Define($$) {
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );
    my $name = $hash->{NAME};

    Log3 $name, 5, "TALKTOUSER $name: called function TALKTOUSER_Define()";

    $hash->{TYPE} = "TALKTOUSER";

	# Define should be only device name and Modulename, nothing else
	if(@a > 3) {
		my $msg = "wrong syntax: define <name> TALKTOUSER";
		Log3 $hash, 2, $msg;
		return $msg;
	}
	
    readingsBeginUpdate($hash);

    # set default settings on first define
    if ($init_done) {
		my $username = $name;
        $attr{$name}{realname}			= $username;
		$attr{$name}{nomatch}			= "Ich konnte leider keine gute Antwort finden!";
		$attr{$name}{noreply}			= "Ich weiss leider nicht was ich darauf sagen soll!";
    }

    readingsEndUpdate( $hash, 1 );
	
	# AssignIoPort magically assigns the module to TALKTOME as TALKTOUSER is configured as a client
	AssignIoPort($hash);

	$modules{TALKTOUSER}{defptr}{$name} = $hash;
	
	readingsSingleUpdate ($hash,  "state", "Defined", 1);
	
    return undef;
}

###################################
sub TALKTOUSER_Attr(@)
{
	my ($cmd,$name,$aName,$aVal) = @_;
	my $hash = $modules{TALKTOUSER}{defptr}{$name};
  	# $cmd can be "del" or "set"
	# $name is device name
	# aName and aVal are Attribute name and value
	if ($cmd eq "set") {
		if ($aName eq "disable") {
			if ($aVal ne "0") {
				readingsSingleUpdate ($hash,  "state", "disabled", 1);
			} else {
				$attr{$name}{$aName} = 0;
				readingsSingleUpdate ($hash,  "state", "enabled", 1);
			}
		}
	}
	return undef;
}


###################################
sub TALKTOUSER_Undefine($$) {
    my ( $hash, $name ) = @_;
	
	Log3 $name, 5, "TALKTOUSER $name: called function TALKTOUSER_Undefine()";
	
    return undef;
}

###################################
sub TALKTOUSER_CheckIODev($) {
	my $hash = shift;
	my $name = $hash->{NAME};
	Log3 $name, 5, "TALKTOUSER $name: called function TALKTOUSER_CheckIODev()";
	return !defined($hash->{IODev});
}

###################################
sub TALKTOUSER_Notify($$) {	
    my ( $hash, $dev ) = @_;
    my $devName  = $dev->{NAME};
    my $name = $hash->{NAME};
	
	Log3 $name, 5, "TALKTOUSER $name: called function TALKTOUSER_Notify()";
	
	# Disable if "disable" is set
	return undef if( AttrVal($name, "disable", 0 ) == 1 );
	
	Log3 $name, 5, "TALKTOUSER $name: $devName is having an update";
	
	# Return if the own device (=me!) is causing the notify
	return if $devName eq $name;
	
	Log3 $name, 5, "TALKTOUSER $name: So it was not me to have the update - continuing";
	
	# Return if we don't know what could have changed
	return if(!$dev->{CHANGED});
	
	Log3 $name, 5, "TALKTOUSER $name: We have a clue what has changed in $devName";
	
	# Return if there is nothing monitored on this device
	# Check if the attribute is empty (which means that nothing is configured)
	my $monitorReading = AttrVal($devName, "talktouserMonitorReading", "###ERROR###" );
	Log3 $name, 5, "TALKTOUSER $name: $devName has the attribute talktouserMonitorReading set to $monitorReading";
	return undef if( $monitorReading eq "###ERROR###" );
	
	# Get the optional attribute which can modify the 
	my $modSourceDev = AttrVal($devName, "talktouserModSourceDev", "%DEVICE%" );
	
	Log3 $name, 5, "TALKTOUSER $name: $devName has the attribute talktouserModSourceDev set to $modSourceDev";
	
	$modSourceDev =~ s/%DEVICE%/$devName/g;
	
	Log3 $name, 5, "TALKTOUSER $name: $devName has the attribute talktouserModSourceDev now is $modSourceDev";
	
	# Split the string to have only the matches
	my @modSourceDevMatches = ($modSourceDev =~ /%%(.*?)%%/sg);
	my $modSourceDevMatchesNr = int(@modSourceDevMatches);
	
	# Lets see how many changes have been done
	my $nrOfFieldChanges = int(@{$dev->{CHANGED}});
	
	# Iterate over the changes and process each one. If we find the monitored reading
	# it is still required to get the other updated values.
	my $monitorReadingFound = 0;
	my $monitorReadingValue = "";
	my $key;
	my $value;
	for (my $i = 0; $i < $nrOfFieldChanges; $i++) {
		my @keyValue = split(":", $dev->{CHANGED}[$i]);
		my $change = $dev->{CHANGED}[$i];
		# We need to find out a key and a value for each field update.

		my $position = index($change, ':');
		if ($position == -1) {
			# For state updates, we have not field, which is why we simply
			# put it to "state".
			$key = "state";
			$value = $keyValue[0];
		} else {
			# For all other updates the notify value is delimited by ":",
			# which we use to find out the value and the key.
			$key = substr($change, 0, $position);
			$value = substr($change, $position + 2, length($change));
		}

		Log3 $name, 5, "TALKTOUSER $name: Update: $key was set to $value in $devName";

		# Check if the reading is the one which should be monitored
		if($monitorReading eq $key) {
			$monitorReadingFound = 1;
			# Now this device matches what we want ;)
			$monitorReadingValue = $value;
		} else {
			# Iterate over the @modSourceDevMatches to see if that matches anything in this string then
			for (my $i = 0; $i < $modSourceDevMatchesNr; $i++) {
				my $modSourceDevMatchesIteration = $modSourceDevMatches[$i];
				if($key eq $modSourceDevMatchesIteration) {
					Log3 $name, 5, "TALKTOUSER $name: modSourceDev before: $modSourceDev";
					$modSourceDev =~ s/%%$modSourceDevMatchesIteration%%/$value/g;
					Log3 $name, 5, "TALKTOUSER $name: modSourceDev after: $modSourceDev";
				}
			}
		}
	}
	if ($monitorReadingFound == 1) {
		Log3 $name, 5, "TALKTOUSER $name: Passing Update to IOWrite";
		#$monitorReadingValue = $monitorReadingValue . "###" . $modSourceDev;
		Log3 $name, 5, "TALKTOUSER $name: Update Content: $monitorReadingValue";
		TALKTOUSER_IOWrite($hash, $dev, $modSourceDev, $monitorReadingValue);
	}
	Log3 $name, 5, "TALKTOUSER $name: called function TALKTOUSER_Notify()";
	return undef;
}

###################################
# This is the possibility for users to quere from the UI
sub TALKTOUSER_Set($@) {
	my ($hash, @a)= @_;
	# Shift once to remove the name of the device
	shift @a;
	my $numArgs = int(@a);
	# Getting the name from the hash seems more reliable to me
	my $name = $hash->{NAME};
	
	Log3 $name, 5, "TALKTOUSER $name: called function TALKTOUSER_Set()";
	
	# Directly jump out of this if the IODev has an issue
	return "$name: Invalid IODev" if(TALKTOUSER_CheckIODev($hash));
	
    # Lets see if we have any arguments.
	return "$name: set requires arguments" if($numArgs < 1);

	# List the valid command separated by space
	my $validCmds='query querytotarget';
	
	# Lets check for the command that we got
	my $cmd=shift(@a);
	
	# See if anything matches
	if(lc($cmd) eq "query") {
		# We got an query from a user - lets have a check if we also got a question with this parameter
		return "'set $name query' requires a query to answer to, e.g.: set $name query What is the question?" if($numArgs < 2);
		
		my $query=join(' ', @a);
		
		readingsSingleUpdate ($hash,  "lastquery", "$query", 1);
		
		# Lets shoot this out there
		TALKTOUSER_IOWrite($hash, $hash, $name, $query);
		# Quit the sub here
		return undef;
	} elsif(lc($cmd) eq "querytotarget") {
		return "'set $name querytotarget' requires a device and a query to answer to, e.g.: set $name querytotarget MYSUPERDEVICE What is the question?" if($numArgs < 3);
		
		my $targetDevice = shift(@a);
	
		return "set $name querytotarget requires a correct target device" if(!defined($defs{$targetDevice}));
	
		my $query=join(' ', @a);
		readingsSingleUpdate ($hash,  "lastquery", "$query", 1);
		TALKTOUSER_IOWrite($hash, $defs{$targetDevice}, $targetDevice, $query);
		# Quit the sub here
		return undef;		
	} elsif(lc($cmd) eq "?") {
		# Show the possible commands and determine these for the webinterface
		return $validCmds;
	}
	
	return "$name: Unknown argument $cmd for set, valid is $validCmds";
}

sub TALKTOUSER_IOWrite($$$$) {
	my ($hash, $sourceDevice, $modSourceDeviceName, $query)= @_;
	my $sourceDeviceName  = $sourceDevice->{NAME};
	my $sourceDeviceType  = $sourceDevice->{TYPE};
	my $name=$hash->{NAME};
	Log3 $name, 4, "TALKTOUSER $name: called function TALKTOUSER_IOWrite()";
	
	# Disable if "disable" is set
	return undef if( AttrVal($name, "disable", 0 ) == 1 );
	
	my $currenttime=gettimeofday();
	
	# Lets record this in our readings as the last query.
	# TODO: Extend this later by a history of maybe five commands or so.
	readingsBeginUpdate($hash);
	# Update the reading
	readingsBulkUpdate($hash, "lastprocessedquery", $query);
	readingsBulkUpdate($hash, "state", 'Query sent');
	# Now close the update and do trigger
	readingsEndUpdate($hash, 1);
	
	# Build the data that will be passed to the IOdev
	# device is the name of the TALKTOUSER device so that the message can be routed back
	# query is the message
	my %data = (device => $name, sourceDeviceName => $sourceDeviceName, sourceDeviceType => $sourceDeviceType, modSourceDeviceName => $modSourceDeviceName, query => $query);
	
	# We'll shoot this to the TALKTOME Device and hope for the best
	Log3 $name, 4, "TALKTOUSER_IOWrite $name: Calling IOWrite, lets see what happens";
	IOWrite($hash, \%data);
	Log3 $name, 4, "TALKTOUSER_IOWrite $name: Calling IOWrite done";
	return undef;
}

###################################
sub TALKTOUSER_Parse($$$) {
	# $hash contains the name of the originating device of the type TALKTOME, not a TALKTOUSER device!
	my ($hash,$msg) = @_;
	my $name = $hash->{NAME};
	# "TALKTOUSER###$device###$answertype###$sourceDeviceName###$sourceDeviceType###$answer"
	my ($TALKTOUSER,$device,$answertype,$sourceDeviceName,$sourceDeviceType,$modSourceDeviceName,$answer) = split("###",$msg);
	
	Log3 $hash, 4, "TALKTOUSER_Parse $name: Variable TALKTOUSER: $TALKTOUSER / device: $device / answertype: $answertype / sourceDeviceName: $sourceDeviceName / sourceDeviceType: $sourceDeviceType / modSourceDeviceName: $modSourceDeviceName / answer: $answer";
	
	# Lets check if we have that device (that should not be happening ever..)
	if(!exists($modules{TALKTOUSER}{defptr}{$device})) {
		Log3 $name, 2, "TALKTOUSER_Parse $name: Got message for undefined device $device - ignoring";
		return undef;
	} else {
		# The device is there so lets map it.
		my $devHash = $modules{TALKTOUSER}{defptr}{$device};
		# Now determine if the dispatched message came from the TALKTOUSER Device UI
		# (and should be given back there) or if it came through notify (and should
		# go back to the origin)
		Log3 $hash, 5, "TALKTOUSER_Parse $name: Variable answer - $answer (UTF8: " . utf8::is_utf8($answer) . ")";
		
		if ($device eq $sourceDeviceName) {
			# So this is really a TALKTOUSER device
			Log3 $name, 4, "TALKTOUSER_Parse $name: Updating $device with the reply";
			
			readingsBeginUpdate($devHash);
			# Update the reading
			readingsBulkUpdate($devHash, "reply", $answer);
			readingsBulkUpdate($devHash, "state", 'Reply received');
			# Now close the update and do trigger
			readingsEndUpdate($devHash, 1);
			Log3 $name, 4, "TALKTOUSER_Parse $name: Updated $device with the reply";
		} else {
			# Well this came from somewhere else, lets find that device
			Log3 $name, 4, "TALKTOUSER_Parse $name: Updating $sourceDeviceName with the reply";
			
			# Lets check if the msg command is in use as we want to answer via the device
			my @msgConfig = devspec2array("TYPE=msgConfig");
			if(!@msgConfig) {
				Log3 $name, 2, "TALKTOUSER_Parse $name: I have not found a msgConfig Device for the reply.";
				Log3 $name, 2, "TALKTOUSER_Parse $name: Additionally you could define the corresponding userattr msgCmd* for your device, e.g. for yowsup: attr <device> userattr msgCmdPush; attr <device> msgCmdPush set %DEVICE% send %TITLE% %MSG%";
			}
			
			# Lets build the command
			# msg [<type>] [<@device|e-mail address>] [<priority>] [|<title>|] <message>
			my $msgTitle = "| |";
			my $device = "\@" . $modSourceDeviceName;
			my $msgPriority = 0;
			# Escape the newlines to ensure that this is properly transmitted
			$answer =~ s/\n/\\n/gi;
			my $msgMessage = $answer;
			
			# Dump it to fhem (lets hope for the best ;) )
			Log3 $name, 5, "msg $device $msgPriority $msgTitle $msgMessage";
			fhem("msg $device $msgPriority $msgTitle $msgMessage");
			
			# This contains the commands to respond to a message			
			# my $msgCmdPush = AttrVal($sourceDeviceName,"msgCmdPush","");
			
			# Log3 $name, 4, "TALKTOUSER_Parse $name: msgCmdPush: $msgCmdPush";
			
			# if($msgCmdPush eq "") {
				# Log3 $name, 2, "TALKTOUSER_Parse $name: Help! I have no clue how to send my message. Define the userattr 'msgCmdPush' on the device (maybe already done for the msg device), e.g. for yowsup devices: attr <device> userattr msgCmdPush; attr <device> msgCmdPush set %DEVICE% send %TITLE% %MSG%";
			# } else {
				# # For yowsup devices there is a bug with the newlines. Edit yowsup/layers/protocol_messages/protocolentities/message_text.py und find:
				# #                   def setBody(self, body):
				# #                       self.body = body
				# # Replace by:
				# #                   def setBody(self, body):
				# #                       self.body = body.replace("!-!","\n")
				# # To also run the correct answers to yowsup now, the module replaces newlines by the string "!-!":
				# if ($sourceDeviceType eq "yowsup") {
					# $answer =~ s/\n/!-!/gi;
				# }
				# # Replace the sourceDeviceName in the message command
				# $msgCmdPush =~ s/%DEVICE%/$sourceDeviceName/gi;
				# # Replace the title in the message command
				# $msgCmdPush =~ s/%TITLE%//gi;
				# # Put the answer in
				# $msgCmdPush =~ s/%MSG%/$answer/gi;
				# Log3 $name, 4, "TALKTOUSER_Parse $name: Running: $msgCmdPush";
				# # Dump it to fhem (lets hope for the best ;) )
				# fhem($msgCmdPush);
				# Log3 $name, 4, "TALKTOUSER_Parse $name: Updated $sourceDeviceName with the reply";
			# }
		}
		return $devHash->{NAME};
	}
}


1;

=pod

=begin html

    <p>
      <a name="TALKTOUSER" id="TALKTOUSER"></a>
    </p>
    <h3>
      TALKTOUSER
    </h3>
    <div style="margin-left: 2em">
      <a name="TALKTOUSERdefine" id="TALKTOUSERdefine"></a> <b>Define</b>
      <div style="margin-left: 2em">
        <code>define &lt;name&gt; TALKTOUSER</code><br>
        <br>
        This module uses <a href="http://www.rivescript.com">rivescript</a> to build a kind of chatbot. Defining an TALKTOUSER device provides the interaction with individual users. Any input is forwarded to a TALKTOUSER device where the rivescript brain is available.<br>
        <br>
        Example:<br>
        <div style="margin-left: 2em">
          <code>define TALKTOUSER_ULI TALKTOUSER</code><br />
		  Defines a device for the user "ULI".
        </div>
      </div><br>
      <br>
      <a name="TALKTOUSERset" id="TALKTOUSERset"></a> <b>Set</b>
      <div style="margin-left: 2em">
        <code>set &lt;name&gt; &lt;command&gt; [&lt;parameter&gt;]</code><br>
        <ul>
          <li><b>query</b> &nbsp;&nbsp;-&nbsp;&nbsp; Sends a query to the TALKETOME device which is being answered in the reading "reply". The current state of the .</li>
		  <li><b>querytotarget</b> &nbsp;&nbsp;-&nbsp;&nbsp; Sends a query to the TALKETOME device on behalf of another device.<br />Example: "set $name querytotarget MYSUPERDEVICE
		  What is the question?" would be seen by the module as if MYSUPERDEVICE has asked the question. This allows to for example send notifications to users and to be able to e.g.
		  disable devices based on the answer of the user (e.g. Battery Monitoring). Take care to include the complete device string, e.g.  MYTELEGRAMBOT:@99999999 if you use that
		  with certain device types</li>
        </ul>
      </div><br>
      <br>
      <a name="TALKTOUSERget" id="TALKTOUSERget"></a> <b>Get</b>
      <div style="margin-left: 2em">
        <code>get &lt;name&gt; &lt;what&gt;</code><br>
        <br>
        Currently no commands are defined
      </div><br>
      <br>
	  <a name="TALKTOUSERattr" id="TALKTOUSERattr"></a> <b>Attributes</b>
      <div style="margin-left: 2em">
        <code>attr &lt;name&gt; &lt;attribute&gt; [&lt;parameter&gt;]</code><br>
        <ul>
          <li><b>nomatch</b> &nbsp;&nbsp;-&nbsp;&nbsp; Defines the reply which is given when no match was found</li>
		  <li><b>noreply</b> &nbsp;&nbsp;-&nbsp;&nbsp; Defines the reply which is given when no replay was found</li>
		  <li><b>realname</b> &nbsp;&nbsp;-&nbsp;&nbsp; Rivescript can react to the user with a personalized answer. The configured value is taken as the username for such replies and can be used using <code>&lt;id&gt;</code> in the Rivescript brain file (<a href="https://www.rivescript.com/docs/tutorial#tags">See Rivescript Tutorial</a>)</li>
        </ul>
      </div><br>
      <br>
	  <a name="TALKTOUSERreadings" id="TALKTOUSERreadings"></a> <b>Readings</b>
      <div style="margin-left: 2em">
        <ul>
          <li><b>lastprocessedquery</b> &nbsp;&nbsp;-&nbsp;&nbsp; Contains the last processed query from any device (e.g. via notify) to the current TALKTOUSER device</li>
		  <li><b>lastquery</b> &nbsp;&nbsp;-&nbsp;&nbsp; Contains the last processed query on the current TALKTOUSER device (e.g. through <code>set &lt;name&gt; query Foo</code>)</li>
		  <li><b>reply</b> &nbsp;&nbsp;-&nbsp;&nbsp; Contains the last reply to a query on the current TALKTOUSER device (e.g. from the <code>set &lt;name&gt; query Foo</code> query)</li>
		  <li><b>state</b> &nbsp;&nbsp;-&nbsp;&nbsp; Contains the status of a query from any device (e.g. via notify) to the current TALKTOUSER device</li>
        </ul>
      </div>
    </div>

=end html

=begin html_DE

    <p>
      <a name="TALKTOUSER" id="TALKTOUSER"></a>
    </p>
    <h3>
      TALKTOUSER
    </h3>
    <div style="margin-left: 2em">
      Eine deutsche Version der Dokumentation ist derzeit nicht vorhanden. Die englische Version ist hier zu finden:
    </div>
    <div style="margin-left: 2em">
      <a href='commandref.html#TALKTOUSER'>TALKTOUSER</a>
    </div>

=end html_DE

=cut