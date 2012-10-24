package Bot::AiRS::Listener::XMPP 0.01;

use 5.14.0;
use strict;
use warnings;
use base "Bot::AiRS::Listener";

# Requires AnyEvent >= 7.02

use AnyEvent::Loop; # Use the pure Perl one
use AnyEvent;
use AnyEvent::XMPP;
use AnyEvent::XMPP::Client;

=head1 NAME

Bot::AiRS::Listener::XMPP - Jabber listener for AiRS. Depends on AnyEvent 7.02 or higher.

=head1 USAGE

TODO

=head1 AUTHOR

Noah Petherbridge

Module uses L<AnyEvent::XMPP>.

=cut

# AnyEvent::Loop hangs until some event happens. This is normally fine for running
# multiple AnyEvent::XMPP bots, but if mixing them with other bots you'll end up
# hanging the other bots. Furthermore, the message queueing system and other
# "background" tasks of AiRS will be halted waiting on XMPP events too. Create a
# singleton AnyEvent timer to keep things moving along.
my $timer;

sub init {
	my $listener = shift;

	if (!defined $timer) {
		$timer = AnyEvent->timer(
			after    => 0,
			interval => 0.01,
			cb       => sub {}
		);
	}

	$listener->{cl} = AnyEvent::XMPP::Client->new(debug => 1);
	$listener->{cl}->{_airs} = $listener;
}

sub signon {
	my $listener = shift;

	# Get the name/domain parts.
	my ($name, $domain) = split(/\@/, $listener->{username}, 2);

	$listener->{cl}->set_presence(undef, "I'm a robot!", 1);
	$listener->{cl}->add_account($listener->{username}, $listener->{password});
}

sub signoff {
	my $listener = shift;
}

sub handlers {
	my $listener = shift;

	$listener->{cl}->reg_cb(
		session_ready             => \&on_session_ready,
		session_error             => \&on_session_error,
		message                   => \&on_message,
		message_error             => \&on_error,
		contact_request_subscribe => \&on_subscribed,
		contact_did_unsubscribe   => \&on_unsubscribed,
		error                     => \&on_error,
		disconnect                => \&on_disconnect,
	);
}

sub loop {
	my $listener = shift;

	$listener->{cl}->start;

	# Do ONE loop so we can all get on with our lives!
	AnyEvent::Loop::one_event();
}

sub sendMessage {
	my ($listener,%opts) = @_;

	my $msg = $opts{msgobj};
	my $reply = $msg->make_reply;
	$reply->add_body($opts{message});
	$reply->send;
}

################################################################################
# Utility                                                                      #
################################################################################

################################################################################
# Handlers                                                                     #
################################################################################

sub on_session_ready {
	my ($cl, $acc) = @_;
	my $listener = $cl->{_airs};
	$listener->print("{c:notice}XMPP $listener->{username}:{c:clear} XMPP Session Ready!");
}

sub on_session_error {
	my ($cl, $err) = @_;
	my $listener = $cl->{_airs};
	$listener->print("{c:error}XMPP $listener->{username}:{c:clear} XMPP Session Error: $err");
}

sub on_message {
	my ($cl, $acc, $msg) = @_;
	my $listener = $cl->{_airs};
	my $bot = $listener->parent->getBot($listener->{bot});

	next unless $msg->type eq "chat"; # TODO: groupchat later!

	# Get the user's name.
	my $from       = $msg->from;
	my ($username) = split(/\//, $from);
	my $client     = $listener->parent->formatUsername("XMPP", $username);

	# Get a reply.
	my $message = $msg->any_body;
	next unless length $message; # Ignore empty ones!
	my $reply = $listener->parent->getReply($listener->{id}, $client, $message);
	return unless defined $reply;

	# Enqueue the sending of the IM.
	$listener->parent->Queue->addQueue(
		agent   => $listener->{id},
		event   => "sendMessage",
		to      => $from,
		message => $reply,
		recover => 3,
		msgobj  => $msg,
	);
}

sub on_subscribed {
	my ($cl, $acc, $roster, $contact) = @_;
	my $listener = $cl->{_airs};
	$contact->send_subscribed;

	$listener->print("{c:notice}XMPP $listener->{username}:{c:clear} Subscribed to " . $contact->jid);
}

sub on_unsubscribed {
	my ($cl, $acc, $roster, $contact) = @_;
	my $listener = $cl->{_airs};
	$contact->send_unsubscribed;

	$listener->print("{c:notice}XMPP $listener->{username}:{c:clear} Unsubscribed from " . $contact->jid);
}

sub on_error {
	my ($cl, $acc, $error) = @_;
	print "Error: " . $error->string . "\n";
}

sub on_disconnect {
	print "XMPP disconnected: @_\n";
}

1;
