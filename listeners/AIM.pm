package Bot::AiRS::Listener::AIM 0.01;

use 5.14.0;
use strict;
use warnings;
use base "Bot::AiRS::Listener";
use Net::OSCAR qw(:standard);

=head1 NAME

Bot::AiRS::Listener::AIM - AOL Instant Messenger listener for AiRS.

=head1 USAGE

TODO

=head1 AUTHOR

Noah Petherbridge

Module uses L<Net::OSCAR>.

=cut

sub init {
	my $listener = shift;

	# Initialize Net::OSCAR.
	$listener->{aim} = Net::OSCAR->new (
		capabilities => [ qw(buddy_icons typing_status) ],
	);
	$listener->{aim}->{_airs} = $listener;
}

sub signon {
	my $listener = shift;
	$listener->{aim}->signon ($listener->{username}, $listener->{password});
}

sub signoff {
	my $listener = shift;
	$listener->{aim}->signoff();
}

sub handlers {
	my $listener = shift;

	# Define the handlers.
	my %h = (
		signon_done         => \&on_signon_done,
		buddylist_error     => \&on_buddylist_error,
		buddylist_ok        => \&on_buddylist_ok,
		im_in               => \&on_im_in,
		admin_error         => \&on_admin_error,
		admin_ok            => \&on_admin_ok,
		buddy_icon_uploaded => \&on_buddy_icon_uploaded,
		evil                => \&on_evil,
		rate_alert          => \&on_rate_alert,
	);
	foreach my $handler (keys %h) {
		my $name = "set_callback_$handler";
		$listener->{aim}->$name ($h{$handler});
	}
}

sub loop {
	my $listener = shift;
	$listener->{aim}->do_one_loop();
}

sub sendMessage {
	my ($listener,%opts) = @_;
	$listener->{aim}->send_im ($opts{to}, $opts{message});
}

################################################################################
# Utility                                                                      #
################################################################################

# Jazz up the reply with the proper font settings.
sub format {
	my ($listener, $font, $reply) = @_;

	my $prefix = "<html>";
	my $suffix = "</html>";

	if ($font->{bgcolor}) {
		$prefix .= "<body bgcolor=\"$font->{bgcolor}\">";
		$suffix  = "</body>" . $suffix;
	}

	if ($font->{family} || $font->{size} || $font->{color}) {
		$prefix .= "<font";
		if ($font->{family}) {
			$prefix .= " face=\"$font->{family}\"";
		}
		if ($font->{size}) {
			$prefix .= " size=\"$font->{size}\"";
		}
		if ($font->{color}) {
			$prefix .= " color=\"$font->{color}\"";
		}
		$prefix .= ">";
		$suffix = "</font>" . $suffix;
	}

	if ($font->{bold}) {
		$prefix .= "<b>";
		$suffix  = "</b>" . $suffix;
	}
	if ($font->{italic}) {
		$prefix .= "<i>";
		$suffix  = "</i>" . $suffix;
	}
	if ($font->{under}) {
		$prefix .= "<u>";
		$suffix  = "</u>" . $suffix;
	}
	if ($font->{strike}) {
		$prefix .= "<s>";
		$suffix  = "</s>" . $suffix;
	}

	return $prefix.$reply.$suffix;
}

################################################################################
# Handlers                                                                     #
################################################################################

# When sign-on is completed.
sub on_signon_done {
	my $aim = shift;
	my $listener = $aim->{_airs};

	$listener->print("{c:notice}[SIGNED ON] {c:bot}" . $listener->{id} . "{c:text} has signed on successfully.");

	# Get the bot's profile info.
	my $bot  = $listener->parent->getBot($listener->{bot});
	my $icon = $bot->{listeners}->{AIM}->{icon};
	my $html = $bot->{listeners}->{AIM}->{profile};

	# Set the buddy icon.
	if (-f $icon) {
		# Icon size can't be bigger than 4 KB.
		if (-s($icon) > (1024*4)) {
			$listener->print("{c:notice}ERROR: AIM buddy icons can't exceed 4 KB.");
		}
		else {
			local $/; # Slurp
			open (my $fh, "<", $icon);
			binmode($fh);
			my $bin = <$fh>;
			close ($fh);

			# Set the icon.
			$aim->set_icon($bin);
		}
	}

	# Set the buddy info.
	if (-f $html) {
		local $/; # Slurp
		open (my $fh, "<", $html);
		my $profile = <$fh>;
		close ($fh);
		$profile =~ s/[\x0D\x0A]//g;

		$aim->set_info ($profile);
	}

	# Commit changes.
	$aim->commit_buddylist();
}

sub on_buddylist_error {
	my ($aim,$error,$what) = @_;
	my $listener = $aim->{_airs};
	$listener->print("{c:error}AIM Buddy List Error for $listener->{id}: $error $what");
}

sub on_buddylist_ok {
	my ($aim) = @_;
	my $listener = $aim->{_airs};
	$listener->print("{c:notice}AIM Buddy List OK for $listener->{id}");
}

sub on_im_in {
	my ($aim,$from,$message,$away) = @_;
	my $listener = $aim->{_airs};
	my $bot = $listener->parent->getBot($listener->{bot});

	# Format this user's name.
	my $client = $listener->parent->formatUsername("AIM", $from);

	# Strip HTML.
	$message =~ s/<(.|\n)+?>//g;

	# Get a reply.
	my $reply = $listener->parent->getReply($listener->{id}, $client, $message);
	return unless defined $reply;

	# Format the response with HTML.
	$reply = $listener->format($bot->{listeners}->{AIM}->{font}, $reply);

	# Send typing status immediately.
	$aim->send_typing_status (TYPINGSTATUS_STARTED);

	# Enqueue the sending of the IM.
	$listener->parent->Queue->addQueue (
		agent   => $listener->{id},
		event   => "sendMessage",
		to      => $from,
		message => $reply,
		recover => 3,
	);
}

sub on_admin_error {
	my ($aim,$reqtype,$error,$url) = @_;
	my $listener = $aim->{_airs};

	$listener->print("{c:error}AIM Admin Error for $listener->{id}: $reqtype, $error, $url");
}

sub on_admin_ok {
	my ($aim,$reqtype) = @_;
	my $listener = $aim->{_airs};

	$listener->print("{c:notice}AIM Admin OK for $listener->{id}: $reqtype");
}

sub on_buddy_icon_uploaded {
	my ($aim) = @_;
	my $listener = $aim->{_airs};

	$listener->print("{c:notice}AIM Buddy Icon Uploaded for $listener->{id}");
}

sub on_evil {
	my ($aim, $level, $from) = @_;
	my $listener = $aim->{_airs};

	$listener->print("{c:error}AIM Warning (Evil) From " . (defined $from ? $from : "(Anonymous)") . "!");

	# Does AIM still do warnings? Permablock this user.
	if (defined $from) {
		my $client = $listener->parent->formatUsername("AIM", $from);
		$listener->parent->blockUser($client);
	}
}

sub on_rate_alert {
	my ($aim, $level, $clear, $window, $worrisome, $virtual) = @_;
	my $listener = $aim->{_airs};

	if ($level == RATE_ALERT || $level == RATE_LIMIT) {
		$listener->print("{c:error}AIM Rate Alert Warning for $listener->{id}");

		# Pause until we're clear.
		$listener->parent->Queue->wait($listener->{id}, ($clear*1000));
	}
}

1;
