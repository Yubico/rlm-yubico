# Copyright (c) 2013 Yubico AB
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the following
#     disclaimer in the documentation and/or other materials provided
#     with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package YKmap;

use strict;

my $mapping_data = {};
my $file = undef;

# Initialize: Read the file.
sub initialize {
	my $options = shift;

	$mapping_data = {};
	$file = $options->{file} // '/etc/yubico/rlm/ykmapping';

	if(open(MAP_FILE, $file)) {
		while(my $line = <MAP_FILE>) {
			chomp($line);
			next if $line =~ /^(#|$)/;

			my ($username, $keystring) = split(/:/, $line, 2);
			my @keys = split(/,/, $keystring);
			$mapping_data->{$username} = \@keys;
		}
		close(MAP_FILE);
	}
}

# Check if a particular username requires an OTP to log in.
sub requires_otp {
	my($username) = @_;
	return exists($mapping_data->{$username});
}

# Checks if the given public id comes from a YubiKey belonging to the 
# given user.
sub key_belongs_to {
	my($public_id, $username) = @_;
	foreach my $x (@{$mapping_data->{$username}}) {
		if($x eq $public_id) {
			return 1;
		}
	}
	return 0;
}

# Returns the username for the given YubiKey public ID.
sub lookup_username {
	my($public_id) = @_;

	foreach my $user (keys $mapping_data) {
		if(key_belongs_to($public_id, $user)) {
			return $user;
		}
	}

	return undef;
}

# Can we auto-provision the given YubiKey for the user?
sub can_provision {
	my($public_id, $username) = @_;

	#TODO: Check if key is provisioned to someone else?
	return not exists($mapping_data->{$username});
}

# Provision the given YubiKey to the given user.
sub provision {
	my($public_id, $username) = @_;

	if(open(MAP_FILE,">>$file")) {
		print MAP_FILE "$username:$public_id\n"; 
		close(MAP_FILE);
	} else {
		warn("Unable to provision YubiKey: $public_id to $username!");
	}
}

1;
