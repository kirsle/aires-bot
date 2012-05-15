package Net::IM::Network 0.01;

use 5.14.0;
use strict;
use warnings;
use Carp;
use Net::IM::Util qw(:all);

=head1 NAME

Net::IM::Network - Base class for an IM network.

=head1 SYNOPSIS

  package Net::IM::MyNetwork;
  use base "Net::IM::Network";

=head1 DESCRIPTION

This is a base class for a supported network for Net::IM.

=head1 METHODS

=head2 new (hash options)

An overrideable constructor method. Options recommended:

  string network:  The network's name.
  string username: A username to use with the IM network. You may also want to
                   add network-specific aliases to this, such as "screenname".
  string password: A password to use with the username.
  object slave:    If the base Net::IM class creates your object, C<slave> will be
                   a reference to the parent object.

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my %opts  = @_;

	my $self = {
		# Common base class options.
		debug    => delete $opts{debug} || 0,
		slave    => delete $opts{slave} || undef,
		hexdump  => delete $opts{hexdump} || 0,

		# Common state options.
		connected => 0,
		loggedin  => 0,
		%opts,
	};

	bless ($self,$class);
	return $self;
}

=head2 void debug (string line)

Print a line of debug output to STDERR. The line will be prefixed by the name
of the network.

=cut

sub debug {
	my ($self,$line) = @_;

	# If debug mode is off, check if we're a slave and the parent has debug on.
	if (!$self->{debug} && defined $self->{slave}) {
		# OK.
	}
	elsif (!$self->{debug}) {
		return;
	}

	say STDERR "[$self->{network}] $line";
}

=head2 void hexdump ([string label,] data)

Internal debugging method. Dumps a binary blob of data to STDOUT in a hexdump
format. Useful for binary protocols.

=cut

sub hexdump {
	my $self = shift;
	return unless $self->{hexdump};

	my ($label,$data);
	if (scalar(@_) == 2) {
		$label = shift;
	}
	$data = shift;

	# Show a label?
	if ($label) {
		say "$label:";
	}

	# Show 16 columns in a row.
	my @bytes = split(//, $data);
	my $col = 0;
	my $buffer = '';
	for (my $i = 0; $i < scalar(@bytes); $i++) {
		my $char    = sprintf("%02x", unpack("C", $bytes[$i]));
		my $escaped = unpack("C", $bytes[$i]);
		if ($escaped < 20 || $escaped > 126) {
			$escaped = ".";
		}
		else {
			$escaped = chr($escaped);
		}

		$buffer .= $escaped;
		print "$char ";
		$col++;

		if ($col == 8) {
			print "  ";
		}
		if ($col == 16) {
			$buffer .= " " until length $buffer == 16;
			print "  |$buffer|\n";
			$buffer = "";
			$col    = 0;
		}
	}
	while ($col < 16) {
		print "   ";
		$col++;
		if ($col == 8) {
			print "  ";
		}
		if ($col == 16) {
			$buffer .= " " until length $buffer == 16;
			print "  |$buffer|\n";
			$buffer = "";
		}
	}
	if (length $buffer) {
		print "|$buffer|\n";
	}
}

=head2 void addHandler (string name => code handler, ...)

Add one or more handlers to common events. Events that are common to all
networks include C<connected>, C<message> and C<error>.

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

		$self->debug("Handler '$key' registered.");
		$self->{handlers}->{ lc($key) } = $handlers{$key};
	}
}

sub addHandlers {
	return shift->addHandler(@_);
}

=head2 multi event (string name, params)

Call on an event handler. If running as a slave, and the object itself doesn't
have a handler, the parent object's handler will be tried.

If the handler needs to return something specific, this method will return what
the handler returns.

=cut

sub event {
	my ($self,$name,@args) = @_;
	$name = lc($name);

	# Do we have the event?
	if (exists $self->{handlers}->{$name}) {
		return $self->{handlers}->{$name}->($self, @args);
	}

	# No? Are we a slave?
	elsif (defined $self->{slave}) {
		# Try it then.
		return $self->{slave}->event($name, $self, @args);
	}

	# Nothing else to do.
	return;
}

=head2 string whoami ()

Return a string describing "who" the current object is. If you have a parent
C<Net::IM> class, this will return the C<id> for the listener. Otherwise it
will return the network name and the normalized screen name, for example
C<YMSG-yahoo_id>.

=cut

sub whoami {
	my $self = shift;

	# Slave?
	if (defined $self->{slave}) {
		return $self->{id};
	}
	else {
		my $class = caller();
		$class =~ s/^.*:://g;
		return join("-", $class, $self->{username});
	}
}

=head2 string network ()

Retrieve the network name, e.g. "YMSG".

=cut

sub network {
	return shift->{network};
}

=head2 string username ([string])

Get or set the current username. Setting the username isn't allowed if the
listener is currently signed in to the network.

=cut

sub username {
	my ($self,$username) = @_;

	# Setting the username?
	if (defined $username) {
		# Not if logged in!
		if ($self->{loggedin}) {
			carp "You can't change the username while logged in!";
			return $self->{username};
		}
		$self->{username} = normalize($username);
	}

	return $self->{username};
}

=head2 string password ([string])

Get or set the current password. Setting the password isn't allowed if the
listener is currently signed in to the network.

=cut

sub password {
	my ($self,$password) = @_;

	# Setting the password?
	if (defined $password) {
		# Not if logged in!
		if ($self->{loggedin}) {
			carp "You can't change the password while logged in!";
			return $self->{password};
		}
		$self->{password} = $password;
	}

	return $self->{password};
}

=head2 bool login ([string username, [string password]])

Connect and log in to the network. Returns undef on failure.

=cut

sub login {
	my ($self,$username,$password) = @_;

	# Given login-time credentials?
	if (defined $username && defined $password) {
		$self->{username} = $username;
		$self->{password} = $password;
	}

	return undef;
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

Perform a single loop on the server.

=cut

sub do_one_loop {}

1;
