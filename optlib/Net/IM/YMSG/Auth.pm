package Net::IM::YMSG::Auth 0.01;

use 5.14.0;
use strict;
use warnings;
use LWP::UserAgent; # For HTTP requests
use HTTP::Request;
use Digest::MD5;    # For auth hash generating
use Crypt::SSLeay;  # Auth requires HTTPS, so we need this module.

sub authenticate {
	my ($self,$param) = @_;

	# To authenticate we need to respond to the challenge.
	my $challenge = $param->{94};

	# Go get the auth response.
	my $url = $self->{authserver}; # Authentication URL
	my $ua  = LWP::UserAgent->new();
	my $req = HTTP::Request->new (
		POST => $url,
	);
	$req->content(join("&",
		"src=ymsgr",
		"ts=",
		"login=$self->{username}",
		"passwd=$self->{password}",
		"chal=$challenge",
	));
	my $resp = $ua->request($req);

	# Success?
	if ($resp->is_success) {
		my $reply = $resp->content;
		$self->debug("Got auth reply: $reply");

		# Send this to stage 2.
		return stage2auth ($self,$param,$ua,$reply);
	}
	else {
		die "Couldn't get auth url ($url)! " . $resp->status_line; # TODO don't die
	}
}

sub stage2auth {
	my ($self,$param,$ua,$reply) = @_;

	# Parse stuff out of it.
	my @lines = split(/\x0D\x0A/, $reply);
	my $result = shift(@lines);

	# OK?
	if ($result != 0) {
		die "Auth failed with error code: $result"; # TODO don't die
	}

	# Get the token.
	my $token = shift(@lines);
	if ($token =~ /^ymsgr=(.+?)$/i) {
		$token = $1;
		$self->debug("We got the auth token: $token");

		# Now with the token, we need to get the crumb.
		my $req = HTTP::Request->new (
			POST => $self->{loginserver},
		);
		$req->content("src=ymsgr&ts=&token=$token");
		my $resp = $ua->request($req);

		if ($resp->is_success) {
			$reply = $resp->content;
			$self->debug("Token reply: $reply");
			#$self->hexdump("Token reply",$reply);

			# Now parse the lines out of this response.
			@lines = split(/\x0D\x0A/, $reply);
			$result = shift(@lines);
			if ($result != 0) {
				die "Token auth failed with error code: $result"; # TODO don't die
			}

			# Get the crumb.
			my $crumb = shift(@lines);
			if ($crumb =~ /^crumb=(.+?)$/i) {
				$crumb = $1;
			}

			# Get the cookies.
			my $yv = shift(@lines);
			my $tz = shift(@lines);
			if ($yv =~ /^Y=(.+?)$/) {
				$self->{yv} = $1;
			}
			if ($tz =~ /^T=(.+?)$/) {
				$self->{tz} = $1;
			}

			$self->debug("We have:\n"
				. "Challenge: $param->{94}\n"
				. "Token: $token\n"
				. "Crumb: $crumb\n"
				. "Yv: $self->{yv}\n"
				. "Tz: $self->{tz}");

			# Get an auth string using the challenge and the crumb.
			my $authstr = auth16 ($crumb, $param->{94});
			$self->debug("Authstr: $authstr");
			return $authstr;
		}
		else {
			die "Failed to get the token reply!"; # TODO
		}
	}
	else {
		die "Couldn't get the token!"; # TODO
	}

	return undef;
}

# Get an auth string
sub auth16 {
	my ($crumb,$challenge) = @_;

	# Crypt.
	my $crypt = $crumb . $challenge;
	my $md5_ctx = Digest::MD5->new();
	$md5_ctx->add($crypt);
	my $md5_digest = $md5_ctx->digest();

	# Y64 encode it.
	return y64_encode($md5_digest);
}

sub y64_encode {
	my $source_str = shift;
	my @source = split(//, $source_str);
	my @yahoo64 = split(//, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._");
	my $limit = length($source_str) - (length($source_str) % 3);
	my $dest = "";
	my $i;
	for ($i = 0; $i < $limit; $i += 3) {
		$dest .= $yahoo64[ ord($source[$i]) >> 2];
		$dest .= $yahoo64[ ((ord($source[$i]) << 4) & 0x30) | (ord($source[$i + 1]) >> 4) ];
		$dest .= $yahoo64[ ((ord($source[$i + 1]) << 2) & 0x3C) | (ord($source[$i + 2]) >> 6)];
		$dest .= $yahoo64[ ord($source[$i + 2]) & 0x3F ];
	}

	my $switch = length($source_str) - $limit;
	if ($switch == 1) {
		$dest .= $yahoo64[ ord($source[$i]) >> 2];
		$dest .= $yahoo64[ (ord($source[$i]) << 4) & 0x30 ];
		$dest .= '--';
	}
	elsif ($switch == 2) {
		$dest .= $yahoo64[ ord($source[$i]) >> 2];
		$dest .= $yahoo64[ ((ord($source[$i]) << 4) & 0x30) | (ord($source[$i + 1]) >> 4)];
		$dest .= $yahoo64[ ((ord($source[$i + 1]) << 2) & 0x3C) ];
		$dest .= '-';
	}

	return $dest;
}

1;
