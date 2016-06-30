# $Id$
##############################################################################
#
#     42_TALKTOME.pm
#     Device for the TALKTOME device which runs the RiveScript Brain
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
use utf8;
use RiveScript qw(:standard);
use Encode qw(decode_utf8 from_to encode_utf8);

###################################
# Forward declarations
sub TALKTOME_Define($$);
sub TALKTOME_Undefine($$);
sub TALKTOME_IsConnected($);
sub TALKTOME_helpers_ReadingsVal(@);
sub TALKTOME_helpers_AttrVal(@);
sub TALKTOME_helpers_ReadingsTimestamp(@);
sub TALKTOME_helpers_fhem(@);
sub TALKTOME_Connect(@);
sub TALKTOME_Reload($);
sub TALKTOME_Set($@);
sub TALKTOME_Attr(@);
sub TALKTOME_Write($%);
sub TALKTOME_DispatchToInterpreter($$$);
###################################
# Run upon initialization of the file
sub TALKTOME_Initialize($) {
	my ($hash) = @_;
	Log3 $hash, 5, "TALKTOME_Initialize: Entering";
	
	# WriteFn: Is used by the logical device to write data to the pysical
	# device. The logical devices are connected to the physical one through
	# the IODev device
	$hash->{WriteFn} = "TALKTOME_Write";
	
	# Clients: List of the possible logical receivers. The data will be
	# provided to all these receivers.
	$hash->{Clients} = ":TALKTOUSER:";
	
	# MatchList: Assignment via regexp of messages to the logical module.
	my %matchList = ( "1:TALKTOUSER" => "^TALKTOUSER" );
	$hash->{MatchList} = \%matchList;
	
	#$hash->{ClearFn} = "TALKTOME_Clear";

	$hash->{SetFn} = "TALKTOME_Set";
	
	# AttrFn: Called on attr command
	$hash->{AttrFn}   = "TALKTOME_Attr";
	
	# DefFn: Called on Define or rename
	$hash->{DefFn} = "TALKTOME_Define";
	
	# NotifyFn: Reaction to Notify's of other devices
	#$hash->{NotifyFn} = "TALKTOME_Notify";
	
	# UndefFn: Called when deleting a device
	$hash->{UndefFn} = "TALKTOME_Undefine";
	
	$hash->{AttrList} = "disable:0,1 rsdebug:0,1 rsdebugfile rsbrainfile rspunctuation " .
						$readingFnAttributes;
}

# Run upon definition of the device
sub TALKTOME_Define($$) {
    my ( $hash, $def ) = @_;
    my $name = $hash->{NAME};

	Log3 $name, 5, "TALKTOME: called function TalkToMe_Define()";
	
	my @a = split("[ \t][ \t]*", $def);

	# Define should be only device name and Modulename, nothing else
	if(@a > 3) {
		my $msg = "wrong syntax: define <name> TALKTOME";
		Log3 $hash, 2, $msg;
		return $msg;
	}

    $hash->{TYPE} = "TALKTOME";
	# TODO: Check if multiple devices are possible or useful and build checks for that
	
	# set default settings on first define
    if ($init_done) {
		# Set disable as the rsbrainfile is probably not there yet.
		if ( ! -f $attr{$name}{rsbrainfile}) {
			$attr{$name}{disable}        = "1";
		}		
    }
	
	readingsSingleUpdate ($hash,  "state", "Defined", 1);
	
    return undef;
}

# Run upon deletion of the device
sub TALKTOME_Undefine($$) {
	my ( $hash, $arg ) = @_;
	
	my $name = $hash->{NAME};

	Log3 $name, 5, "TAKTOME: called function TALKTOME_Undefine()";
	
    return undef;
}

sub TALKTOME_IsConnected($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3 $name, 5, "TALKTOME: called function TALKTOME_IsConnected()";
	if(!exists($hash->{RSOBJECT})) {
		Log3 $name, 5, "TALKTOME: TALKTOME_IsConnected() will return 0";
		return 0;
	} else {
		Log3 $name, 5, "TALKTOME: TALKTOME_IsConnected() will return 1";
		return 1;
	}
}

# Wrapper function for ReadingsVal
sub TALKTOME_helpers_ReadingsVal(@) {
	# A sub always gets the bot as first argument - we'll just remove that
	shift(@_);
	# Now we'll figure the rest of the arguments
	my ($device, $reading, $default) = @_;
	# Get the reading and then give it back
	return ReadingsVal($device, $reading, $default);
}

# Wrapper function for AttrVal
sub TALKTOME_helpers_AttrVal(@) {
	# A sub always gets the bot as first argument - we'll just remove that
	shift(@_);
	# Now we'll figure the rest of the arguments
	my ($device, $reading, $default) = @_;
	# Get the reading and then give it back
	return AttrVal($device, $reading, $default);
}

# Wrapper function for ReadingsTimestamp
sub TALKTOME_helpers_ReadingsTimestamp(@) {
	# A sub always gets the bot as first argument - we'll just remove that
	shift(@_);
	# Now we'll figure the rest of the arguments
	my ($device, $reading, $default) = @_;
	# Get the reading and then give it back
	return ReadingsTimestamp($device, $reading, $default);
}

# Wrapper function for ReadingsTimestamp
sub TALKTOME_helpers_fhem(@) {
	# A sub always gets the bot as first argument - we'll just remove that
	shift(@_);
	my $command = join(' ', @_);
	
	Log3 "TC_TALKTOME", 5, "TALKTOME: called function TALKTOME_helpers_fhem with command: $command";
	# Now we'll figure the rest of the arguments
	# Get the reading and then give it back
	return fhem($command);
}

# Initializes the rivescript-bot
# Can be called anytime. When already initialized, then this will be a no-op.
sub TALKTOME_Connect(@) {
	my ($hash, $force) = @_;
	my $name = $hash->{NAME};
	
	Log3 $name, 5, "TALKTOME: called function TALKTOME_Connect()";
	
	# Disable if "disable" is set
	return undef if( AttrVal($name, "disable", 0 ) == 1 );
	
	# Check if the bot is connected already
	my $botisconnected = TALKTOME_IsConnected($hash);
	Log3 $name, 5, "TALKTOME: TALKTOME_Connect called TALKTOME_IsConnected which returned $botisconnected";
	# Lets see if there is a force to perform a reconnect
	if($botisconnected == 1 && $force && $force eq 1) {
		# Well we really want this ;)
		$botisconnected = 0
	}
	# Just quit as we are already done at this point :)
	if($botisconnected == 1) {
		Log3 $name, 5, "TALKTOME: Bot is already connected - exiting at this point";
	} else {
		Log3 $name, 5, "TALKTOME: Bot is not yet connected - performing that now";
		
		# Determine if debugging should be enabled
		my $rsdebug = int(AttrVal($name, "rsdebug", 0));
		Log3 $name, 5, "TALKTOME: rsdebug is set to $rsdebug";
		
		# Determine the debug target file
		my $rsdebugfile = AttrVal($name, "rsdebugfile", "$attr{global}{modpath}/log/TALKTOME.log");
		Log3 $name, 5, "TALKTOME: rsdebugfile is set to $rsdebugfile";
		
		my $rspunctuation = AttrVal($name, "rspunctuation", ".,!?;:¡¿");
		
		# Some config for rivescript:
		my %rivescriptconfig = ('utf8'       => 1,
			debug => $rsdebug,
			verbose => 0,
			debugfile => $rsdebugfile,
			strict => 0,
			unicode_punctuation => qr/[$rspunctuation]/);
		
		# Do the Initialization
		Log3 $name, 5, "TALKTOME: Running init of Rivescript Bot";
		# Create a new RiveScript interpreter object.
		$hash->{RSOBJECT} = RiveScript->new(%rivescriptconfig);

		# Load a directory full of RiveScript documents.
		#$hash->{RSOBJECT}->loadDirectory("./replies");
		
		# Load another file.
		my $rsbrainfile = AttrVal($name, "rsbrainfile", "$attr{global}{modpath}/TALKTOME.rive");
		
		if ( ! -f $rsbrainfile) {
			Log3 $name, 3, "TALKTOME: rsbrainfile points to a file that does not exist, please copy template file or create one";
			readingsSingleUpdate ($hash,  "state", "ERROR: rsbrainfile points to a file that does not exist, please copy template file or create one", 1);
		} else {
			# Lets put up handler for warning messages in case the rsbrainfile is not properly written
			local $SIG{__WARN__} = sub {
				my $message = shift;
				# Put this into the state
				Log3 $name, 3, "TALKTOME: rsbrainfile has an error: $message";
				readingsSingleUpdate ($hash,  "state", "ERROR: $message", 1);
				# Exist this function, the rest won't have any effect anyway
				return
			};
			$hash->{RSOBJECT}->loadFile ($rsbrainfile);

			# Now add the ReadingsVal possibilities to the available functions
			$hash->{RSOBJECT}->setSubroutine("readingsval", \&TALKTOME_helpers_ReadingsVal);
			
			# Now add the ReadingsTimestamp possibilities to the available functions
			$hash->{RSOBJECT}->setSubroutine("readingstimestamp", \&TALKTOME_helpers_ReadingsTimestamp);
			
			# Now add the AttrVal possibilities to the available functions
			$hash->{RSOBJECT}->setSubroutine("attrval", \&TALKTOME_helpers_AttrVal);
			
			# Now add the fhem possibilities to the available functions
			$hash->{RSOBJECT}->setSubroutine("fhem", \&TALKTOME_helpers_fhem);
			
			# You must sort the replies before trying to fetch any!
			$hash->{RSOBJECT}->sortReplies();
		}
	}
	# Initialization finished
	Log3 $name, 5, "TALKTOME: finished function TALKTOME_Connect()";
	return undef;
}

sub TALKTOME_Reload($) {
	my ($hash) = @_;
	if (defined $hash) {
		my $name = $hash->{NAME};
		
		# Disable if "disable" is set
		return undef if( AttrVal($name, "disable", 0 ) == 1 );
		return undef if( AttrVal($name, "disable", 0 ) == 1 );
		
		Log3 $name, 5, "TALKTOME: called function TALKTOME_Reload()";
		TALKTOME_Connect($hash, 1);
		readingsSingleUpdate ($hash,  "state", "Reloaded", 1);
		Log3 $name, 5, "TALKTOME: finished function TALKTOME_Reload()";
	}
}

###################################
sub TALKTOME_Set($@) {
	my ($hash, @a)= @_;
	# Shift once to remove the name of the device
	shift @a;
	my $numArgs = int(@a);
	# Getting the name from the hash seems more reliable to me
	my $name = $hash->{NAME};
	
	# Disable if "disable" is set
	return undef if( AttrVal($name, "disable", 0 ) == 1 );
	
    # Lets see if we have any arguments.
	return "$name: set requires arguments" if($numArgs < 1);

	# List the valid command separated by space
	my $validCmds='reload:noArg';
	
	# Lets check for the command that we got
	my $cmd= shift(@a);
	
	# See if anything matches
	if(lc($cmd) eq "reload") {
		# Just run a disconnect as it will connect on the next command anyway
		TALKTOME_Reload($hash);
		return undef;
	} elsif(lc($cmd) eq "?") {
		# Show the possible commands and determine these for the webinterface
		return $validCmds;
	}
	
	return "$cmd not valid, only one of: $validCmds";
}

###################################
sub TALKTOME_Attr(@) {
	my ($cmd,$name,$aName,$aVal) = @_;
	my $hash = $defs{$name};
  	# $cmd can be "del" or "set"
	# $name is device name
	# aName and aVal are Attribute name and value
	if ($aName eq "disable") {
		if ($aVal ne "0" && $cmd eq "set") {
			readingsSingleUpdate ($hash, "state", "disabled", 1);
		} else {
			readingsSingleUpdate ($hash, "state", "enabled", 1);
		}
	} elsif ($aName eq "rsdebug" || $aName eq "rspunctuation") {
		# Afterwards Rivescript should be reloaded - whatever is being done (set or del):
		TALKTOME_Reload($hash);
	}
	return undef;
}

# WriteFn: Is used by the logical device to write data to the pysical
# device. The logical devices are connected to the physical one through
# the IODev device. Therefore the function receives the data from the logical
# device, e.g. the $hash as the logical device calls IOWrite($hash, %data)
# This will only work if the device as run AssignIoPort before which assigns
# the variable $hash->{IODev}.
sub TALKTOME_Write($%) {
	# $hash contains this device not the source.
	my ($hash,$dataref) = @_;
	my $name = $hash->{NAME};
	
	# Disable if "disable" is set
	return undef if( AttrVal($name, "disable", 0 ) == 1 );
	
	# Dereference the hash
	my %data = %{$dataref};
	
	# Lets split the data
	# We need to know where the message is coming from
	my $device = $data{'device'};
	Log3 $hash, 5, "TALKTOME_Write: Variable device - $device";
	# This is the device where the message is originally from
	my $sourceDeviceName = $data{'sourceDeviceName'};
	Log3 $hash, 5, "TALKTOME_Write: Variable sourceDeviceName - $sourceDeviceName";
	my $sourceDeviceType = $data{'sourceDeviceType'};
	Log3 $hash, 5, "TALKTOME_Write: Variable sourceDeviceType - $sourceDeviceType";
	my $modSourceDeviceName = $data{'modSourceDeviceName'};
	Log3 $hash, 5, "TALKTOME_Write: Variable modSourceDeviceName - $modSourceDeviceName";
	
	# Update the state
	readingsSingleUpdate ($hash,  "state", "Query from $device", 1);
	
	# And the original query
	my $query = $data {'query'};
	
	# Fix the utf8 issue
	if(utf8::is_utf8($query) ne 1) {
		Log3 $hash, 5, "TALKTOME_Write: Variable query - $query (UTF8: " . utf8::is_utf8($query) . ")";
		$query = decode_utf8( $query );
	}
	Log3 $hash, 5, "TALKTOME_Write: Variable query - $query (UTF8: " . utf8::is_utf8($query) . ")";
	
	# Holds the returned message from the rivescript-bot
	my $answer = undef;
	# Holds the type of the returned message from the rivescript-bot
	my $answertype = undef;
	
	# Always check if the interpreter is initialized
	# It will be a no-op if already done
	TALKTOME_Connect($hash);
	
	# Now dispatch the message to the interpreter (Rivescript brain).
	# The Message always has a reply so ensure to dispatch afterwards.
	$answer = TALKTOME_DispatchToInterpreter($hash, $device, $query);
	Log3 $hash, 5, "TALKTOME_Write: Variable answer - $answer (UTF8: " . utf8::is_utf8($answer) . " / Valid: " . utf8::valid($answer) . ")";
	
	if (!$answer) {
		# Seems like we did not receive anything. That should not be happening
		# as rivescript always sends back at least a "i didn't get it".
		$answertype = 'ERROR';
		$answer = 'TALKTOME: No Answer received - that should not be happening. Check with your admin';
	} else {
		# All went fine, so this is a reply ;) Reply is set through the
		# dispatch return value.
		$answertype = 'REPLY';
	}
	
	# Known FHEM thing - need to encode the reply
	$answer = encode_utf8($answer);
	
	# Build the reply
	my %returndata = (device => $name, sourceDeviceName => $sourceDeviceName, modSourceDeviceName => $modSourceDeviceName, answertype => $answertype, answer => $answer);
		
	# Dispatch to the TALKTOUSER Module. Searches for a matching logical module
	# (by checking $hash->{Clients} or $hash->{MatchList} in this device, and
	# $hash->{Match} in all matching devices), and calls the ParseFn of the
	# target devices. At this point we'll not check if the $hash really
	# exists - we guess that the hash that wrote us will receive that again.
	
	Dispatch($hash, "TALKTOUSER###$device###$answertype###$sourceDeviceName###$sourceDeviceType###$modSourceDeviceName###$answer", \%returndata);
	
	# Update the state
	readingsSingleUpdate ($hash,  "state", "Reply sent to $device", 1);
	
	return undef;
}

# Here the interpreter (rivescript) is being questioned.
sub TALKTOME_DispatchToInterpreter($$$) {
	my ($hash, $sourceDeviceName, $query) = @_;
	my $name = $hash->{NAME};
	
	# Disable if "disable" is set
	return undef if( AttrVal($name, "disable", 0 ) == 1 );
	
	Log3 $hash, 5, "TALKTOME_DispatchToInterpreter: Variable sourceDeviceName: $sourceDeviceName / query - $query";
	# Always check if the interpreter is initialized
	# It will be a no-op if already done
	TALKTOME_Connect($hash);
	my $reply = RS_ERR_REPLY;
	
	my $realname = AttrVal($sourceDeviceName,"realname",$sourceDeviceName);
	
	$reply = $hash->{RSOBJECT}->reply($realname, $query);
	
	Log3 $hash, 5, "TALKTOME_DispatchToInterpreter: reply is: $reply";
	
	if ($reply eq RS_ERR_MATCH) {
		$reply = AttrVal($sourceDeviceName, "nomatch", "Found no match. To customize this message please set attribute 'nomatch' on $sourceDeviceName");
	} elsif ($reply eq RS_ERR_REPLY) {
		$reply = AttrVal($sourceDeviceName, "noreply", "Found no reply. To customize this message please set attribute 'noreply' on $sourceDeviceName");
	}
	
	return "$reply";
}

1;


=pod

=begin html

    <p>
      <a name="TALKTOME" id="TALKTOME"></a>
    </p>
    <h3>
      TALKTOME
    </h3>
    <div style="margin-left: 2em">
      <a name="TALKTOMEdefine" id="TALKTOMEdefine"></a> <b>Define</b>
      <div style="margin-left: 2em">
        <code>define &lt;name&gt; TALKTOME</code><br>
        <br>
        This module uses <a href="http://www.rivescript.com">rivescript</a> to build a kind of chatbot.
		Defining an TALKTOME device will bring up a rivescript brain which is not usable without the
		TALKTOUSER module which provides the interaction with individual users.<br>
        <br>
        Example:<br>
        <div style="margin-left: 2em">
          <code>define TalkToMe TALKTOME</code>
      </div><br>
      <br>
      <a name="TALKTOMEset" id="TALKTOMEset"></a> <b>Set</b>
      <div style="margin-left: 2em">
        <code>set &lt;name&gt; &lt;command&gt; [&lt;parameter&gt;]</code><br>
        <ul>
          <li><b>reload</b> &nbsp;&nbsp;-&nbsp;&nbsp; reloads the rivescript brain.</li>
        </ul>
      </div><br>
      <br>
      <a name="TALKTOMEget" id="TALKTOMEget"></a> <b>Get</b>
      <div style="margin-left: 2em">
        <code>get &lt;name&gt; &lt;what&gt;</code><br>
        <br>
        Currently no commands are defined
      </div><br>
      <br>
	  <a name="TALKTOMEattr" id="TALKTOMEattr"></a> <b>Attributes</b>
      <div style="margin-left: 2em">
        <code>attr &lt;name&gt; &lt;attribute&gt; [&lt;parameter&gt;]</code><br>
        <ul>
          <li><b>rsbrainfile</b> &nbsp;&nbsp;-&nbsp;&nbsp; Path to the Brainfile for rivescript. The default is being set upon Module definition and is in $attr{global}{modpath}/FHEM/TALKTOME.rive</li>
		  <li><b>rsdebug</b> &nbsp;&nbsp;-&nbsp;&nbsp; Enables (1) or disables (0) the debug mode of rivescript. Attention: Can lead to a massive logfile which is defined in rsdebugfile</li>
		  <li><b>rsdebugfile</b> &nbsp;&nbsp;-&nbsp;&nbsp; Path to the Debuglogfile for rivescript. The default is being set upon Module definition and is in $attr{global}{modpath}/log/TALKTOME.log</li>
		  <li><b>rspunctuation</b> &nbsp;&nbsp;-&nbsp;&nbsp; This sets the characters which are seen as punctuation. This defaults to ".,!?;:¡¿". Example: You want to enable /Temperatures in Telegram. For this you would set ".,!?;:¡¿/" in this parameter so that Rivescript processes "Temperatures"
        </ul>
      </div><br>
      <br>
      <a name="TALKTOMEreadings" id="TALKTOMEreadings"></a> <b>Readings</b>
      <div style="margin-left: 2em">
        <ul>
		  <li><b>state</b> &nbsp;&nbsp;-&nbsp;&nbsp; Contains the status of a query from any TALKTOUSER device</li>
        </ul>
      </div>
    </div>

=end html

=begin html_DE

    <p>
      <a name="TALKTOME" id="TALKTOME"></a>
    </p>
    <h3>
      TALKTOME
    </h3>
    <div style="margin-left: 2em">
      Eine deutsche Version der Dokumentation ist derzeit nicht vorhanden. Die englische Version ist hier zu finden:
    </div>
    <div style="margin-left: 2em">
      <a href='commandref.html#TALKTOME'>TALKTOME</a>
    </div>

=end html_DE

=cut
