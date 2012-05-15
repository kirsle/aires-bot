package Net::IM 0.01;

use 5.14.0;
use strict;
use warnings;
use Carp;

=head1 NAME

Net::IM - Perl extension for Instant Messaging networks.

=head1 SYNOPSIS

  use Net::IM;

  my $im = Net::IM->new();

  # Add a connection to a network.
  $im->addConnection (
    network  => "YMSG",
    username => "yahoo_id",
    password => "bigsecret1",
  );

  # Add another
  $im->addConnection (
    network   => "MSNP",
    username  => 'myname@live.com',
    password  => "really_big_secret",
  );

  # Add common handlers.
  $im->addHandler (Connected => \&on_connected);
  $im->addHandler (Message   => \&on_message);

  # Sign in and run
  $im->login();
  $im->run();

=head1 DESCRIPTION

This module can be used to connect to and interact with various Instant
Messaging networks. The base C<Net::IM> class can be used as a single point for
connecting to multiple networks simultaneously, or its protocol-specific
classes can be used directly.

When using the base class, you attach connections to IM networks via the
C<addConnection()> method. All the connections are given unique ID's. You can
either give ID's manually, or the default ID will be the username concatenated
with the network name, for example C<YMSG-yahoo_id> - the username would always
be made lowercase and without spaces when the ID is automatically assigned.

=head1 METHODS

=head2 new (hash options)

Create a new Net::IM object. A single object can handle multiple connections to
multiple networks. Options supported for the constructor:

  bool debug:  Debug mode (this will propagate down and enable debugging for all
               connections, so beware)

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my %opts  = @_;

	my $self = {
		# Configurable options.
		debug    => delete $opts{debug} || 0,

		# Global handlers to be propagated to all sub-classes.
		handlers => {},

		# Individual listeners.
		listeners => {},
	};
	bless ($self,$class);

	$self->debug("$class initialized.");

	return $self;
}

sub debug {
	my ($self,$line) = @_;

	if (!$self->{debug}) {
		return;
	}

	say STDERR "[Net::IM] $line";
}

=head2 string addConnection (hash options)

Add a connection to your C<Net::IM> object. This represents one single
connection to a particular network (for example, one screen name). Options
include, but aren't limited to:

  string id:       A unique ID for this listener (optional)
  string network:  The name of the network (e.g. YMSG - required)
  string username: The username to sign in with (optional)
  string password: The password for the account (optional)

Any options given will be passed directly to the class for the network used. See
the documentation for the network for more details. If you don't pass in an C<id>,
then the C<username> will be a required field.

This method will return the unique ID for the newly created connection.

=cut

sub addConnection {
	my ($self,%opts) = @_;

	# Required fields.
	my $network = delete $opts{network} || croak "No network name given to addListener.";
	$network =~ s/[^A-Za-z0-9]+//g;

	# Get or make an ID.
	my $id = delete $opts{id};
	if (!defined $id) {
		my $username = $opts{username} || croak "A username is required when you don't pass in an ID.";
		$username = lc($username); $username =~ s/\s+//g;
		$id = join("-", $network, $username);
	}

	# Auto-load this listener if necessary.
	my $file = "Net/IM/$network.pm";
	my $ns   = "Net::IM::$network";
	require $file;

	# Create the listener.
	$self->debug("Creating listener with ID: $id");
	$self->{listeners}->{$id} = $ns->new (
		slave  => $self,
		id     => $id,
		%opts,
	);

	return $id;
}

=head2 object get (string id)

Retrieve the object for a particular connection, by ID. This may be handy if you
want to define a specific event handler for a specific connection, or to call
methods on that particular object. Example:

  my $yahoo = $im->addConnection(
    network => "YMSG", username => "soandso", password => "bigsecret",
  );
  $im->get($yahoo)->addHandler (Message => \&on_ymsg_message);

=cut

sub get {
	my ($self,$id) = @_;

	# Exists?
	if (exists $self->{listeners}->{$id}) {
		return $self->{listeners}->{$id};
	}
	else {
		croak "Couldn't find a connection with ID \"$id\"!";
	}
}

=head2 string[] listConnections ()

Retrieve a list of all managed connections. Returns an array reference
containing the ID's.

=cut

sub listConnections {
	return [ sort keys %{shift->{listeners}} ];
}

=head2 void addHandler (string name => code handler, ...)

Add one or more handlers to common events. Events that are common to all
networks include C<Connected>, C<Message> and C<Error>.

The handler name is case insensitive, so feel free to CamelCase them if it makes
your code more readable.

These handlers will be applied to all listeners, unless you apply a handler to
a specific network.

The alias C<addHandlers> can be used instead.

=cut

sub addHandler {
	my ($self, %handlers) = @_;

	foreach my $key (keys %handlers) {
		if (ref($handlers{$key}) ne "CODE") {
			croak "Handlers must be CODE references.";
		}

		$self->{handlers}->{ lc($key) } = $handlers{$key};
		$self->debug("Global handler '$key' registered.");
	}
}

sub addHandlers {
	return shift->addHandler(@_);
}

=head2 private multi event (string name, params)

Internal method to call an event handler.

=cut

sub event {
	my ($self,$name,@args) = @_;
	$name = lc($name);

	# Exists?
	if (exists $self->{handlers}->{$name}) {
		return $self->{handlers}->{$name}->(@args);
	}

	return;
}

=head2 bool login ()

Log in all of the listeners.

=cut

sub login {
	my $self = shift;

	# Login all listeners.
	foreach my $id (keys %{$self->{listeners}}) {
		if (!$self->{listeners}->{$id}->{connected}) {
			$self->{listeners}->{$id}->login();
		}
	}

	return 1;
}

=head2 void run ()

Start a loop of C<do_one_loop()>.

=cut

sub run {
	my $self = shift;
	while (1) {
		$self->do_one_loop();
	}
}

=head2 void do_one_loop ()

Run a loop on all listeners.

=cut

sub do_one_loop {
	my $self = shift;

	foreach my $id (keys %{$self->{listeners}}) {
		$self->{listeners}->{$id}->do_one_loop();
	}
}

=head1 SEE ALSO

=over 4

=item Included Network Support

L<Net::IM::YMSG> - Yahoo! Messenger

=item Other Classes

L<Net::IM::Network> - Base class for all networks.

=back

=head1 COPYRIGHT

Copyright 2011 Noah Petherbridge

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
