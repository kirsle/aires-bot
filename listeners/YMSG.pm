package Bot::AiRS::Listener::YMSG 0.01;

use 5.14.0;
use strict;
use warnings;
use base "Bot::AiRS::Listener";
use Net::IM::YMSG;

=head1 NAME

Bot::AiRS::Listener::YMSG - Yahoo Messenger listener for AiRS.

=head1 USAGE

TODO

=head1 AUTHOR

Noah Petherbridge

Module uses L<Net::IM::YMSG>.

=cut

sub init {
	my $listener = shift;

	# Initialize Net::OSCAR.
	$listener->{ymsg} = Net::IM::YMSG->new (
		yahoo_id => $listener->{username},
		password => $listener->{password},
	);
	$listener->{ymsg}->{_airs} = $listener;
}

sub signon {
	my $listener = shift;
	$listener->{ymsg}->login();
}

sub signoff {
	my $listener = shift;
	$listener->{ymsg}->logout();
}

sub handlers {
	my $listener = shift;

	# Define the handlers.
	$listener->{ymsg}->addHandler (
		Connected    => \&on_connected,
		Disconnected => \&on_disconnected,
		Notification => \&on_notify,
		BuddyList    => \&on_buddylist,
		AddRequest   => \&on_add_request,
		Attention    => \&on_buzz,
		Message      => \&on_message,
		Typing       => \&on_typing,
		BuddyStatus  => \&on_buddy_status,
		BuddyRemoved => \&on_buddy_removed,
		BuddyOnline  => \&on_buddy_online,
		BuddyOffline => \&on_buddy_offline,
		BuddyIconUploaded => \&on_buddy_icon_uploaded,
	);
}

sub loop {
	my $listener = shift;
	$listener->{ymsg}->do_one_loop();
}

sub sendMessage {
	my ($listener,%opts) = @_;
	$listener->{ymsg}->sendMessage ($opts{to}, $opts{message});
}

################################################################################
# Utility                                                                      #
################################################################################

# Jazz up the reply with the proper font settings.
sub format {
	my ($listener, $font, $reply) = @_;

	my $prefix = "";
	my $suffix = "";

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
sub on_connected {
	my $ymsg = shift;
	my $listener = $ymsg->{_airs};

	$listener->print("{c:notice}[SIGNED ON] {c:bot}" . $listener->{id} . "{c:text} has signed on successfully.");

	# Get the bot's profile info.
	my $bot  = $listener->parent->getBot($listener->{bot});
	my $icon = $bot->{listeners}->{YMSG}->{picture};

	# Set the buddy icon.
	if (-f $icon) {
		local $/; # Slurp
		open (my $fh, "<", $icon);
		binmode($fh);
		my $bin = <$fh>;
		close ($fh);

		# Set the icon.
		$ymsg->setIcon($bin);
	}
}

# Disconnected :(
sub on_disconnected {
	my $ymsg = shift;
	my $listener = $ymsg->{_airs};

	$listener->print("{c:error}DISCONNECTED {c:bot}" . $listener->{id});
}

sub on_message {
	my ($ymsg,$from,$message) = @_;
	my $listener = $ymsg->{_airs};
	my $bot = $listener->parent->getBot($listener->{bot});

	# Format this user's name.
	my $client = $listener->parent->formatUsername("YMSG", $from);

	# Strip HTML and pseudo-ANSI color codes.
	$message =~ s/<(.|\n)+?>//g;
	$message =~ s/\e.+?m//g;

	# Get a reply.
	my $reply = $listener->parent->getReply($listener->{id}, $client, $message);
	return unless defined $reply;

	# Format the response with HTML.
	$reply = $listener->format($bot->{listeners}->{YMSG}->{font}, $reply);

	# Send typing status immediately.
	$ymsg->sendTyping($from, 1);

	# Enqueue the sending of the IM.
	$listener->parent->Queue->addQueue (
		agent   => $listener->{id},
		event   => "sendMessage",
		to      => $from,
		message => $reply,
		recover => 3,
	);
}

# Server notifications
sub on_notify {
	my ($ymsg, $from, $to, $message) = @_;
	my $listener = $ymsg->{_airs};

	$listener->print("{c:notice}YMSG Notification for $listener->{id}: from=$from, to=$to, msg=$message");
}

# Add request
sub on_add_request {
	my ($ymsg, $from) = @_;
	my $listener = $ymsg->{_airs};

	$listener->print("{c:notice}Add request for $listener->{id} from: $from");
	$ymsg->acceptAddRequest($from);
}

# Buzzed.
sub on_buzz {
	my ($ymsg, $from) = @_;

	# No response.
}

# User is typing.
sub on_typing {
	my ($ymsg, $from, $typing) = @_;

	# No response.
}

# Buddy status change.
sub on_buddy_status {
	my ($ymsg, $from, $status, $custom) = @_;
}

# Got the buddylist
sub on_buddylist {
	my ($self, $list) = @_;
}

# Buddy online/offline.
sub on_buddy_online {
	my ($self, $from) = @_;
}
sub on_buddy_offline {
	my ($self, $from) = @_;
}

# Icon uploaded
sub on_icon_uploaded {
	my $ymsg = shift;
	my $listener = $ymsg->{_airs};

	$listener->print("{c:notice}Buddy icon for $listener->{id} uploaded successfully!");
}

1;
