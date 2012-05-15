package Net::IM::Util 0.01;

use 5.14.0;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
	const
	normalize
);

our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
);

# void const name => value
#   Create an exportable constant at run-time.
use subs "const";
sub const {
	my ($name,$value) = @_;

	no strict "refs";
	my $caller = caller(1);
	*{$caller.'::'.$name} = sub () { $value };
}

# string normalize (string)
#   Lowercase and remove spaces from a username.
sub normalize {
	my $string = shift;
	$string = lc($string);
	$string =~ s/\s+//g;
	return $string;
}

1;
