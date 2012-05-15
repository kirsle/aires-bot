package Bot::AiRS::Brain 0.01;

use 5.14.0;
use strict;
use warnings;

=head1 NAME

Bot::AiRS::Brain - Base class for an AiRS brain.

=head1 SYNOPSIS

  package Bot::AiRS::Brain::MyBrain 1.00;
  use base "Bot::AiRS::Brain";

=head1 DESCRIPTION

This is the base class for all pluggable brains for the AiRS chatterbot. Brains
should override the methods in this class where applicable.

=head1 OVERRIDE METHODS

=cut

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = shift;

	my $self = {
		_parent => $parent,
	};
	bless ($self,$class);

	$self->init(@_);

	return $self;
}

=head2 void init (params)

This method is called when the brain is first initialized. C<params> are the
params given by the bot configuration file. For example, if your brain requires
a directory for reply files, the params will include this.

A brain is an object, so you have C<$self> to store arbitrary data in. Just
don't touch the C<_parent> key: this is a reference to the parent AiRS object.

=cut

sub init {}

=head2 string reply (string username, string message)

Get a reply for the user's message.

=cut

sub reply {}

=head1 INHERITED METHODS

These methods are here for convenience.

=head2 void print (string data)

A shortcut to the parent AiRS object's C<print()>.

=cut

sub print {
	return shift->{_parent}->print(@_);
}

=head2 AiRS parent()

Retrieve the parent AiRS object, to call other functions in it.

=cut

sub parent {
	return shift->{_parent};
}

1;
