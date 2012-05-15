package Bot::AiRS::Queue 0.01;

use 5.14.0;
use strict;
use warnings;

=head1 NAME

Bot::AiRS::Queue - Queueing events for AiRS listeners.

=head1 SYNOPSIS

  use Bot::AiRS::Queue;

=head1 DESCRIPTION

This module implements an event queue for listeners for AiRS. Its primary
purpose is to queue outgoing messages, as some listeners have rate limits on
sending messages.

If there are no queued messages, the first message that gets pushed to the
queue gets sent immediately. Then a "time out" period follows in which no
similar events will be sent.

=head1 METHODS

=head2 Queue new (hash options)

Create a new queue. Options include:

  AiRS parent: A reference to the parent object.

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto || "Bot::AiRS::Queue";
	my %opts  = @_;

	my $self = {
		parent => $opts{parent},
		queues => {},
	};
	bless ($self,$class);

	return $self;
}

=head2 void addQueue (hash options)

Add a new item to be queued. Options include:

  string agent:    The specific chatterbot username (e.g. AIM-mybot) to add to
                   the queue of.
  string event:    The name of the event to enqueue.
  string to:       The IM username of the recipient (no LISTENER- prefix)
  string message:  The message to send
  int    recover:  How many seconds to recover after performing this action

Valid events are:

  sendMessage

=cut

sub addQueue {
	my ($self,%opts) = @_;

	# Collect the options.
	my $agent = $opts{agent};
	my $rec   = $opts{recover} || 0;

	# Does this agent have a queue yet?
	if (!exists $self->{queues}->{$agent}) {
		$self->{queues}->{$agent} = {
			continue => 0,  # the time() until the next item can be performed
			queue    => [],
		};
	}

	# If there's no recovery time, do this event now.
	if ($rec == 0) {
		$self->doEvent(%opts);
		return;
	}

	# Add to the queue.
	push (@{$self->{queues}->{$agent}->{queue}}, \%opts);
}

=head2 void runQueues ()

Loop over all agents' queues and run pending events.

=cut

sub runQueues {
	my $self = shift;

	# Loop over the queues.
	foreach my $agent (sort keys %{$self->{queues}}) {
		# Are we waiting?
		if ($self->{queues}->{$agent}->{continue} > time()) {
			next;
		}

		# Run the next event.
		if (scalar @{$self->{queues}->{$agent}->{queue}} > 0) {
			my $next = shift @{$self->{queues}->{$agent}->{queue}};

			# Run this event.
			$self->doEvent(%{$next});

			# Recovery time?
			if (exists $next->{recover} && $next->{recover} > 0) {
				$self->{queues}->{$agent}->{continue} = time() + $next->{recover};
			}
		}
	}
}

=head2 void doEvent (hash options)

Execute a queue event B<now>. This takes the same options as C<addQueue>.

=cut

sub doEvent {
	my ($self,%opts) = @_;

	# Do this event.
	my $agent = $opts{agent};
	my $event = $opts{event};

	# Get this listener.
	my $listener = $self->{parent}->getListener($agent);

	# Dispatch the event.
	$listener->{listener}->$event (%opts);
}

=head2 void wait (string agent, int seconds)

Stop running all queue events and wait for this time. This overrides the queue's
current timeout period.

Note you can pass in 0 which will stop the current timeout period and run the
next queued item.

=cut

sub wait {
	my ($self,$agent,$wait) = @_;

	# Does this agent have a queue yet?
	if (!exists $self->{queues}->{$agent}) {
		$self->{queues}->{$agent} = {
			continue => 0,  # the time() until the next item can be performed
			queue    => [],
		};
	}

	# Override the continue time.
	$self->{queues}->{$agent}->{continue} = time() + $wait;
}

1;
