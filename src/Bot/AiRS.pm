package Bot::AiRS 0.01;

use 5.14.0;
use strict;
use warnings;
use Carp;
use JSON;
use autodie;
use Bot::AiRS::CLI;
use Bot::AiRS::Queue;

# ANSI color codes.
my %ANSI = (
	black   => 30,  gray    => 90,
	maroon  => 31,  red     => 91,
	green   => 32,  lime    => 92,
	gold    => 33,  yellow  => 93,
	navy    => 34,  blue    => 94,
	purple  => 35,  magenta => 95,
	teal    => 36,  cyan    => 96,
	silver  => 37,  white   => 97,
	clear   => 0,
);

# Special colors (these are overridden by config settings).
my %COLOR = (
	notice => "lime",
	error  => "red",
	user   => "cyan",
	bot    => "yellow",
	text   => "white",
);

=head1 NAME

Bot::AiRS - Artificial Intelligence, RiveScript.

=head1 SYNOPSIS

  use AiRS;

=head1 DESCRIPTION

This is a chatterbot.

=head1 METHODS

=head2 AiRS new (hash options)

Create a new AiRS object. You should generally only need one of these, because
one AiRS object can maintain several different bots connected to several
different protocols.

Options include:

  bool debug:  Debug mode
  bool batch:  Batch mode (do not parse @ARGV automatically)

See L<Bot::AiRS::CLI> for a list of command line arguments that are
automatically parsed by this module when C<batch> isn't provided.

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto || "Bot::AiRS";
	my %opts  = @_;

	my $self = {
		debug => $opts{debug} ? 1 : 0,
		cli   => {}, # CLI options

		# Internal data.
		colors   => { %COLOR }, # Color preferences
		handlers => {},         # Global handlers
		json     => undef,      # JSON parser
		queue    => undef,      # Queue objects
		bots     => {},         # Bot configurations
		brains   => {},         # Brain instances for the bots
		mirrors  => {},         # Bot listening mirrors
	};
	bless ($self,$class);

	# Parse CLI?
	unless ($opts{batch}) {
		$self->{cli} = Bot::AiRS::CLI::process();
		$self->{debug} = $self->{cli}->{debug};
	}

	# Debug mode? If not, hide warnings.
	if (!$self->{debug}) {
		$SIG{__WARN__} = sub {};
	}

	# Initialize queues.
	$self->{queue} = Bot::AiRS::Queue->new (
		parent => $self,
	);

	# Initialize JSON parser.
	$self->{json} = JSON->new->utf8->pretty->relaxed();

	return $self;
}

=head2 void setHandler (string name, coderef)

Set a global handler. See L<"HANDLERS"> for a list of supported handlers.

=cut

sub setHandler {
	my ($self,$name,$code) = @_;

	# Assertions.
	if (ref($name)) {
		croak "Global handler names must be plain strings!";
	}
	if (ref($code) ne "CODE") {
		croak "Global handlers must be given a CODE reference!";
	}

	$self->{handlers}->{$name} = $code;
}

=head2 void init (bool reload)

Make the bot (re)initialize all its data. This loads configuration, loads the
individual bot settings, etc.

The bots don't attempt to sign on to IM networks until C<run()> or
C<loop()> is called for the first time.

=cut

sub init {
	my $self = shift;
	my $reloading = shift;

	$self->print("{c:notice}-== {c:error}AiRS - Artificial Intelligence/RiveScript {c:notice}==-", "");

	# Load configuration files.
	$self->print("{c:error}== {c:notice}Reading configuration files {c:error}==");
	my @config = qw(botmaster colors);
	foreach my $cfg (@config) {
		# File exists?
		if (-f "./conf/$cfg.json") {
			# In memory? Delete.
			$self->print("{c:error}:: {c:text}Reading: conf/$cfg.json");
			delete $self->{$cfg};
			$self->{$cfg} = $self->readConfig("./conf/$cfg.json");
		}
		else {
			$self->print("{c:error}:: Missing config file \"conf/$cfg.json\"; using defaults");
		}
	}

	# Load bot config files.
	$self->print("{c:error}== {c:notice}Reading chatterbot settings {c:error}==");
	opendir (my $bd, "./bots");
	foreach my $cfg (sort(grep(/\.json$/i, readdir($bd)))) {
		my $bot = $cfg;
		$bot    =~ s/\.json$//i;
		$self->print("{c:error}:: {c:text}Reading: bots/$cfg");

		# Already known?
		delete $self->{bots}->{$bot};
		$self->{bots}->{$bot} = $self->readConfig("./bots/$cfg");
	}
	closedir ($bd);

	# Initialize brains. Don't load the same module twice in one round.
	my %brain_inc = ();
	$self->print("{c:error}== {c:notice}Initializing chatterbot brains {c:error}==");
	foreach my $bot (sort keys %{$self->{bots}}) {
		my ($brain,@params) = @{$self->{bots}->{$bot}->{brain}};
		$self->print("{c:error}:: {c:text}Loading brain \"$brain\" for bot \"$bot\"");

		# Require the brain.
		my $ns   = "Bot::AiRS::Brain::$brain";
		if (!exists $brain_inc{$brain}) {
			my $file = "./brains/$brain.pm";
			if ($reloading) {
				$brain_inc{$brain} = do $file;
			}
			else {
				$brain_inc{$brain} = require $file;
			}
		}

		$self->{brains}->{$bot} = $ns->new ($self, @params);
	}

	# Initialize listeners. Don't load the same module twice in one round.
	my %listener_inc = ();
	$self->print("{c:error}== {c:notice}Initializing chatterbot listeners (mirrors) {c:error}==");
	foreach my $bot (sort keys %{$self->{bots}}) {
		foreach my $listener (sort keys %{$self->{bots}->{$bot}->{listeners}}) {
			$self->print("{c:error}:: {c:text}Loading listener \"$listener\" for bot \"$bot\"");

			# Require the listener.
			my $ns = "Bot::AiRS::Listener::$listener";
			if (!exists $listener_inc{$listener}) {
				my $file = "./listeners/$listener.pm";
				if (!-f $file) {
					$self->print("{c:error}   Listener \"$listener\" is not installed in this bot. Skipping!");
					next;
				}

				# First load, or reload?
				if ($reloading) {
					$listener_inc{$listener} = do $file;
				}
				else {
					$listener_inc{$listener} = require $file;
				}
			}

			# Initialize one listener per mirror.
			foreach my $mirror (@{$self->{bots}->{$bot}->{listeners}->{$listener}->{mirrors}}) {
				my $username = $self->formatUsername($listener,$mirror->{username});

				# Don't reinit mirrors that already exist.
				if (!exists $self->{mirrors}->{$username}) {
					$self->print("   {c:text}Creating mirror: $username");

					# Initialize the listener for this mirror.
					$self->{mirrors}->{$username} = {
						listener => $ns->new (
							id       => $username,
							online   => 0,
							bot      => $bot,
							parent   => $self,
							%{$mirror}, # username, password, etc.
						),
						bot      => $bot,
					};
				}

				# Define all the handlers.
				$self->{mirrors}->{$username}->{listener}->handlers();
			}
		}
	}
}

=head2 void run ()

Start the bot running autonomously. This starts a loop of C<do_one_loop()>.

=cut

sub run {
	my $self = shift;
	while (1) {
		$self->do_one_loop();
		select(undef,undef,undef,0.01);
	}
}

=head2 void do_one_loop ()

Perform one loop on the bot. If your program has its own event loop, you should
call this method in your loop instead of C<run()>.

=cut

sub do_one_loop {
	my $self = shift;

	# Make sure the bots are online.
	foreach my $mirror (keys %{$self->{mirrors}}) {
		if ($self->{mirrors}->{$mirror}->{listener}->{online} != 1) {
			# Sign it on.
			$self->{mirrors}->{$mirror}->{listener}->signon();
			$self->{mirrors}->{$mirror}->{listener}->{online} = 1;
		}
		else {
			# Loop.
			$self->{mirrors}->{$mirror}->{listener}->loop();
		}
	}

	# Handle queued events.
	$self->Queue->runQueues();

	return 1;
}

=head2 Queue ()

Returns the L<Bot::AiRS::Queue> object. This method is useful for listeners.

=cut

sub Queue {
	return shift->{queue};
}

=head1 PRIVATE METHODS

You usually have no reason to call these methods, but it doesn't hurt to do so.

=head2 print (string[] data)

Print data to the terminal. Data may have color codes in it. To set the color,
just include the tag C<{c:colorname}> for example C<{c:cyan}>. Supported color
names are:

  black   gray
  maroon  red
  green   lime
  gold    yellow
  purple  magenta
  navy    blue
  teal    cyan
  silver  white
  clear

You can also use a color by purpose (which is configurable):

  notice (default lime)
  error  (default red)
  user   (default cyan)
  bot    (default yellow)
  text   (default white)

If color codes are used, C<clear> will be assumed at the end of the line.

=cut

sub print {
	my ($self,@lines) = @_;

	my $colorful = 0;
	foreach my $line (@lines) {
		while ($line =~ /\{c:(\w+)\}/i) {
			$colorful = 1;

			# Only if ANSI colors are desired.
			if ($self->{cli}->{color}) {
				if (exists $self->{colors}->{$1}) {
					my $code = "\e[" . $ANSI{$self->{colors}->{$1}} . "m";
					$line =~ s/\{c:$1\}/$code/g;
				}
				elsif (exists $ANSI{$1}) {
					my $code = "\e[" . $ANSI{$1} . "m";
					$line =~ s/\{c:$1\}/$code/g;
				}
				else {
					$line =~ s/\{c:$1\}//g;
				}
			}
			else {
				$line =~ s/\{c:$1\}//g;
			}
		}

		# Implicit reset.
		if ($colorful && $self->{cli}->{color}) {
			$line .= "\e[0m";
		}

		# Invoke the print handler.
		$self->_invoke(print => $line);
	}
}

=head2 data getBot (string botname)

Get the bot's configuration data from memory.

=cut

sub getBot {
	my ($self,$bot) = @_;

	return exists $self->{bots}->{$bot} ? $self->{bots}->{$bot} : undef;
}

=head2 data getListener (string agent)

Given an agent (a bot in LISTENER-screenname format), return the listener data
structure for it.

=cut

sub getListener {
	my ($self,$agent) = @_;

	return exists $self->{mirrors}->{$agent} ? $self->{mirrors}->{$agent} : undef;
}

=head2 string getReply (string agent, string client, string message)

Get a reply from a listener. The C<agent> should be the C<id> given to a
listener, e.g. for an AIM bot, "C<AIM-botname>". C<username> should be the
formatted username, e.g. for an AIM user, "C<AIM-username>".

This method may return undef, indicating that no reply is to be given to the
user (for example, blocked users).

=cut

sub getReply {
	my ($self,$agent,$client,$msg) = @_;
	my $reply = undef;

	# Resolve this bot's identity.
	my $bot = $self->{mirrors}->{$agent}->{bot};

	# Is this user blocked?
	my $blocked = $self->isBlocked($client);

	# Is this user an admin?
	my $admin   = $self->isBotmaster($client);

	# Admin commands.
	if ($admin) {
		$reply = $self->adminCommands($agent,$client,$msg);
	}

	# Get a reply.
	if (!$blocked && !defined $reply) {
		$reply = $self->{brains}->{$bot}->reply($client, $msg);
	}

	# Log the transaction.
	$self->logTransaction($client, $msg, $agent, $reply);

	return $reply;
}

=head2 void logTransaction (string client, string message, string agent, string reply)

Log a transaction (a user's message and how the bot responded). This prints it
to the terminal and will add it to log files on disk.

=cut

sub logTransaction {
	my ($self, $client, $msg, $agent, $reply) = @_;

	# Get one time stamp here so it's consistent everywhere.
	my $time = scalar(localtime(time()));

	# Print it to the terminal first.
	$self->print (
		"{c:notice}$time",
		"{c:user}[$client] {c:text}$msg",
		"{c:bot}[$agent] {c:text}$reply",
		""
	);

	# Log it. Make sure all the relevant folders exist.
	if (!-d "./logs") {
		mkdir("./logs");
	}
	if (!-d "./logs/$agent") {
		mkdir("./logs/$agent");
	}

	# Log in two places: a global log and a per-agent-per-user log.
	my @logs = (
		"./logs/chat.html",
		"./logs/$agent/$client.html",
	);
	foreach my $log (@logs) {
		# If not exists, create the initial template.
		if (!-f $log) {
			open (my $tmpl, ">", $log);
			print {$tmpl} q{<!DOCTYPE html>
<html>
<head>
<title>AiRS Chat Transcript</title>
<style>
body {
 background-color: #FFFFFF;
 font-family: Verdana,Arial,sans-serif;
 font-size: small;
 color: #000000
}
div.transaction {
 display: block;
 margin-bottom: 32px;
}
span.time {
 font-weight: bold;
}
span.human {
 font-weight: bold;
 color: #FF0000;
}
span.agent {
 font-weight: bold;
 color: #0000FF;
}
</style>
<body>};
			close ($tmpl);
		}

		# Append the transaction.
		open (my $append, ">>", $log);
		print {$append} "\n\n"
			. "<div class=\"transaction\">\n"
			. "<span class=\"time\">$time</span><br>\n"
			. "<span class=\"human\">[$client]</span> $msg<br>\n"
			. "<span class=\"agent\">[$agent]</span> $reply\n"
			. "</div>";
		close ($append);
	}
}

=head2 bool isBlocked (string client)

See if the user is blocked.

=cut

sub isBlocked {
	my ($self,$client) = @_;

	# Get the block list.
	my $list = $self->readConfig("./conf/blocked.json");
	if (exists $list->{$client}) {
		# Has their block expired though?
		if ($list->{$client} > 0 && time() > $list->{$client}) {
			delete $list->{$client};
			$self->writeConfig("./conf/blocked.json", $list);
			return 0;
		}
		return 1;
	}

	return 0;
}

=head2 bool isBotmaster (string username)

See if the user is a botmaster.

=cut

sub isBotmaster {
	my ($self,$client) = @_;

	foreach my $id (@{$self->{botmaster}}) {
		return 1 if $id eq $client;
	}

	return 0;
}

=head2 string adminCommands (string agent, string client, string message)

Process admin commands for the user (this method doesn't check if C<client> is
a botmaster; this was taken care of in C<getReply()>).

=cut

sub adminCommands {
	my ($self,$agent,$client,$msg) = @_;

	# Do admin commands.
	if ($msg =~ /^!reload/i) {
		# Reload the bot.
		$self->reload();
		return "AiRS has been completely reloaded.";
	}
	elsif ($msg =~ /^!shutdown/i) {
		# Shutdown the bot.
		exit(0);
	}
	elsif ($msg =~ /^!block (.+?)$/i) {
		my $user = $1;
		if ($user !~ /^[A-Z]+\-[a-z0-9\@\+\-\.\_]+$/) {
			return "Improperly formatted username ($user). The format should be: "
				. "LISTENER-username, where LISTENER is in all caps, and "
				. "username is lowercase, with no spaces.\n\n"
				. "Example: AIM-screenname, MSN-name\@live.com";
		}
		$self->blockUser ($user);
		return "The user $user has been blocked indefinitely.";
	}
	elsif ($msg =~ /^!unblock (.+?)$/i) {
		my $user = $1;
		if ($user !~ /^[A-Z]+\-[a-z0-9\@\+\-\.\_]+$/) {
			return "Improperly formatted username. The format should be: "
				. "LISTENER-username, where LISTENER is in all caps, and "
				. "username is lowercase, with no spaces.\n\n"
				. "Example: AIM-screenname, MSN-name\@live.com";
		}
		$self->unblockUser ($user);
		return "The user $user has been unblocked.";
	}
	elsif ($msg =~ /^!(help|menu)/i) {
		# Menu.
		return qq{-== Admin Menu ==-

!reload - Completely reload the bot
!shutdown - Shut down the bot
!block [client] - Block a user, for example !block AIM-username
!unblock [client] - Unblock a user
!help - Show this menu};
	}

	return undef;
}

=head2 void reload ()

Reload the bot "live". This will attempt to hot-swap all the code for the bot
while the bots are running.

=cut

sub reload {
	my $self = shift;

	# Reload the core modules first.
	my @core = (
		"Bot/AiRS.pm",
		"Bot/AiRS/Brain.pm",
		"Bot/AiRS/CLI.pm",
		"Bot/AiRS/Listener.pm",
		"Bot/AiRS/Queue.pm",
	);
	foreach my $c (@core) {
		$self->print("{c:error}:: {c:notice}Reloading core module $c");
		do "./src/$c";
	}

	# Redo the init.
	$self->init(1);
}

=head2 void blockUser (string client[, int expires])

Block a user. Given C<expires>, the block will expire after this length of time.
Otherwise the block is permanent.

=cut

sub blockUser {
	my ($self,$client,$expires) = @_;
	$expires //= 0; #/

	# Get the block list.
	my $list = $self->readConfig("./conf/blocked.json") || {};

	# Add.
	$list->{$client} = $expires > 0 ? time() + $expires : 0;

	# Write.
	$self->writeConfig("./conf/blocked.json", $list);
}

=head2 void unblockUser (string client)

Unblock a user.

=cut

sub unblockUser {
	my ($self,$client) = @_;

	# Get the block list.
	my $list = $self->readConfig("./conf/blocked.json") || {};
	delete $list->{$client};
	$self->writeConfig("./conf/blocked.json", $list);
}

=head2 string formatUsername (string listener, string username)

Format a username into C<LISTENER-username> format.

=cut

sub formatUsername {
	my ($self,$listener,$username) = @_;

	$listener = uc($listener);
	$username = lc($username);
	$username =~ s/\s+//g;

	return join("-", $listener, $username);
}

=head2 data readConfig (string file)

Read data from a JSON file.

=cut

sub readConfig {
	my ($self,$file) = @_;

	if (!-f $file) {
		return undef;
	}

	local $/; # Slurp
	open (my $fh, "<", $file);
	my $json = <$fh>;
	close ($fh);

	# Parse.
	return $self->{json}->decode($json);
}

=head2 void writeConfig (string file, data)

Write a config file.

=cut

sub writeConfig {
	my ($self,$file,$data) = @_;

	open (my $fh, ">", $file);
	print {$fh} $self->{json}->encode($data);
	close ($fh);
}

# private void _invoke (string name, [params])
# Invoke a global handler.
sub _invoke {
	my ($self,$name,@params) = @_;

	# Exists?
	if (exists $self->{handlers}->{$name}) {
		return $self->{handlers}->{$name}->(@params);
	}

	return undef;
}

=head1 HANDLERS

=head2 void print (string line)

This handler catches all output given by AiRS. For a command-line only interface,
for example, this handler should simply print the line to standard output.

=cut

1;
