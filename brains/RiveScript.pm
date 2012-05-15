package Bot::AiRS::Brain::RiveScript 0.01;

use 5.14.0;
use strict;
use warnings;
use base "Bot::AiRS::Brain";
use RiveScript;

=head1 NAME

Bot::AiRS::Brain::RiveScript - A RiveScript brain for AiRS.

=head1 USAGE

In your chatterbot config file, use:

  "brain" : [ "RiveScript", "/path/to/rs/files" ]

=head1 AUTHOR

Casey Kirsle

=cut

sub init {
	my ($self, $base) = @_;

	# Initialize RiveScript.
	$self->{rs} = RiveScript->new();
	$self->{rs}->loadDirectory($base);
	$self->{rs}->sortReplies();
}

sub reply {
	my ($self, $username, $message) = @_;

	# Get the user's profile back.
	my $profile = $self->parent->readConfig("users/$username.json") || {};

	# Is a botmaster?
	if ($self->parent->isBotmaster($username)) {
		$profile->{botmaster} = "true";
	}
	else {
		$profile->{botmaster} = "false";
	}

	# Set the vars.
	$self->{rs}->setUservar ($username, %{$profile});

	# Get a reply.
	my $reply = $self->{rs}->reply ($username, $message);

	# Save changes to profile.
	my $vars = $self->{rs}->getUservars($username);
	$self->parent->writeConfig("users/$username.json", $vars);

	return $reply;
}

1;
