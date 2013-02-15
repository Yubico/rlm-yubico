use strict;
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);

use constant    RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
use constant	RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
use constant	RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
use constant	RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
use constant	RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
use constant	RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
use constant	RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
use constant	RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
use constant	RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
use constant	RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */

my $id_len = 12;
my $otp_len = 32 + $id_len;

# Make sure the user has a valid YubiKey OTP
sub authorize {
	# Extract OTP, if available
	my $otp = '';

	if($RAD_REQUEST{'YubiKey-OTP'} =~ /^[cbdefghijklnrtuv]{$otp_len}$/) {
		$otp = $RAD_REQUEST{'YubiKey-OTP'};
	} elsif($RAD_REQUEST{'User-Name'} =~ /[cbdefghijklnrtuv]{$otp_len}$/) {
		my $username_len = length($RAD_REQUEST{'User-Name'}) - $otp_len;
		$otp = substr $RAD_REQUEST{'User-Name'}, $username_len;
		$RAD_REQUEST{'User-Name'} = substr $RAD_REQUEST{'User-Name'}, 0, $username_len;
	} elsif($RAD_REQUEST{'User-Password'} =~ /[cbdefghijklnrtuv]{$otp_len}$/) {
		my $password_len = length($RAD_REQUEST{'User-Password'}) - $otp_len;
		$otp = substr $RAD_REQUEST{'User-Password'}, $password_len;
		$RAD_REQUEST{'User-Password'} = substr $RAD_REQUEST{'User-Password'}, 0, $password_len;
	}

	my $username = $RAD_REQUEST{'User-Name'};

	# Handle OTP
	if($otp eq '') {
		#No OTP, what to do?
		if(requires_otp($username)) {
			&radiusd::radlog(1, "Reject $username without OTP");
			$RAD_REPLY{'Reply-Message'} = "Missing OTP!";
			return RLM_MODULE_REJECT;
		} else {
			# Allow login without OTP
			&radiusd::radlog(1, "$username allowed with no OTP");
			return RLM_MODULE_NOOP;
		}
	} elsif(validate_otp($otp)) {
		my $publicId = substr($otp, 0, $id_len);

		if(otp_belongs_to($publicId, $username)) {
			&radiusd::radlog(1, "$username has valid OTP: $otp");
			return RLM_MODULE_OK;
		} elsif(can_provision($publicId, $username)) {
			&radiusd::radlog(1, "Attempt to provision $publicId for $username post authentication");
			$RAD_CHECK{'YubiKey-Provision'} = $publicId;
			return RLM_MODULE_UPDATED;
		} else {
			&radiusd::radlog(1, "Reject: $username using valid OTP from foreign YubiKey: $publicId");
			$RAD_REPLY{'Reply-Message'} = "Invalid OTP!";
			return RLM_MODULE_REJECT;
		}
	} else {
		#Invalid OTP
		&radiusd::radlog(1, "Reject: $username with invalid OTP: $otp");
		$RAD_REPLY{'Reply-Message'} = "Invalid OTP!";
		return RLM_MODULE_REJECT;
	}
}

# Do auto-provisioning, if needed, after authentication.
sub post_auth {
	my $publicId = $RAD_CHECK{'YubiKey-Provision'};
	my $username = $RAD_REQUEST{'User-Name'};

	if($publicId =~ /^[cbdefghijklnrtuv]{$id_len}$/) {
		provision($publicId, $username);
	}

	return RLM_MODULE_OK;
}


# Check if a particular username requires an OTP to log in.
sub requires_otp {
	my($username) = @_;

	#TODO: Check if the given user requires a valid OTP to authenticate.
	return 1;
}

# Validates a YubiKey OTP.
sub validate_otp {
	my($otp) = @_;

	#TODO: Validate the given OTP with the configured validation server
	if($otp =~ /c$/) {
		return 1;
	}

	return 0;
}

# Checks if the given OTP comes from a YubiKey belonging to the 
# given user.
sub otp_belongs_to {
	my($publicId, $username) = @_;

	#TODO: Check if a YubiKey has been provisioned to the given user
	if($publicId =~ /^dndndndndndn$/) {
		return 1;
	}

	return 0;
}

# Can we auto-provision the given YubiKey for the user?
sub can_provision {
	my($publicId, $username) = @_;

	#TODO: Insert logic for determining if a YubiKey can be provisioned here
	return 1;
}

# Provision the given YubiKey to the given user.
sub provision {
	my($publicId, $username) = @_;
	
	#TODO: Insert provisioning logic here
	&radiusd::radlog(1,"Provisioned $publicId to $username");
}

