package Bot::AiRS::Brain::Eliza 0.01;

use 5.14.0;
use strict;
use warnings;
use base "Bot::AiRS::Brain";
use Chatbot::Eliza;

=head1 NAME

Bot::AiRS::Brain::Eliza - The classic Eliza personality for AiRS.

=head1 USAGE

In your chatterbot config file, use:

  "brain" : [ "Eliza" ]

=head1 AUTHOR

Noah Petherbridge

=cut

sub init {
	my ($self, $base) = @_;

	# We'll need an Eliza for each user.
	$self->{eliza} = {};
}

sub reply {
	my ($self, $username, $message) = @_;

	# New user?
	if (!exists $self->{eliza}->{$username}) {
		$self->{eliza}->{$username} = Chatbot::Eliza->new();
	}

	my $reply = $self->{eliza}->{$username}->transform($message);

	return $reply;
}

1;
