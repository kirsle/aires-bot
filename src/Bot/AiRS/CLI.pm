package Bot::AiRS::CLI 0.01;

use 5.14.0;
use strict;
use warnings;
use Getopt::Long;

=head1 NAME

Bot::AiRS::CLI - Command line arguments for an AiRS bot.

=head1 OPTIONS

=over 4

=item --debug, -d

Enables debug mode.

=item --nocolor

Do not use ANSI color codes when printing output.

=back

=cut

sub process {
	my %opts = (
		debug => 0,
		color => 1,
	);

	GetOptions (
		'debug|d' => \$opts{debug},
		'color!'  => \$opts{color},
	);

	# If using colors on Win32, we need an extra module.
	if ($opts{color} && $^O eq "MSWin32") {
		require Win32::Console::ANSI;
	}

	return \%opts;
}

1;
