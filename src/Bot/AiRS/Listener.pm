package Bot::AiRS::Listener 0.01;

use 5.14.0;
use strict;
use warnings;

=head1 NAME

Bot::AiRS::Listener - Base class for an AiRS listener.

=head1 SYNOPSIS

  package Bot::AiRS::Listener::MyListener 1.00;
  use base "Bot::AiRS::Listener";

=head1 DESCRIPTION

This is the base class for all pluggable listeners for the AiRS chatterbot.

=head1 OVERRIDE METHODS

=cut

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my %opts   = @_;

	my $self = {
		id       => delete $opts{id},
		online   => 0,
		bot      => delete $opts{bot},
		_parent  => delete $opts{parent},
		%opts,
	};
	bless ($self,$class);

	$self->init(@_);

	return $self;
}

=head2 void init (params)

This method is called when the listener is first initialized. This method should
be used to initialize the object for the listener and nothing more.

A listener is an object, so you have C<$self> to store arbitrary data in. Just
don't touch the C<_parent> key: this is a reference to the parent AiRS object.

The keys C<username>, C<password> and C<bot> are also reserved.

=cut

sub init {}

=head2 void handlers ()

This method should be used to (re)define handler bindings for your listener.
This will be called during initialization, and also during a live reload of the
bot. This method should define handlers and nothing more.

=cut

sub handlers {}

=head2 void signon ()

Do whatever needs to be done to sign the bot on.

=cut

sub signon {}

=head2 void signoff ()

Do whatever needs to be done to sign the bot off.

=cut

sub signoff {}

=head2 void loop ()

This method should be used to call your listener's looping mechanism. This is
usually called C<do_one_loop> or similar.

=cut

sub loop {}

=head2 void sendMessage (hash options)

If your listener supports sending a message using the Message Queue, it must
respond to this method. Given options are:

  string to:      The recipient (in IM network format)
  string message: The message to send

=cut

sub sendMessage {}

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

AUTOLOAD {
	say "AUTOLOAD called in Listener: @_";
}

1;
