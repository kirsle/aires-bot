#!/usr/bin/perl

use 5.14.0;
use strict;
use warnings;
use File::Copy;
use lib "./optlib";
use lib "./src";

use Bot::AiRS;
my $version = $Bot::AiRS::VERSION;

print "This script is used to bundle AiRS for distribution.\n"
	. "Are you sure you wanted to run this? [yN] ";
chomp(my $ans = <STDIN>);
exit(0) unless $ans eq "y";

# Required commands.
print "Testing for required commands...\n";
foreach my $cmd (qw(cp rm tar)) {
	system("which $cmd");
	if ($?) {
		die "The command $cmd wasn't found. This script can't work!";
	}
}

my $root = "AiRS-$version";
if (-d $root) {
	die "The `dist` folder already exists... this isn't right!";
}

# Make the distribution copy.
print "Creating distribution root $root\n";
mkdir($root);

# Copy everything to it.
my @files = qw(
	brains
	doc
	listeners
	replies
	res
	src
	bundler.pl
	cli.pl
	License.txt
	README.txt
);
foreach my $f (@files) {
	if (-d $f) {
		say "Copy: cp -r $f $root/";
		system("cp", "-r", $f, "$root/");
	}
	else {
		say "Copy: cp $f $root/";
		system("cp", $f, "$root/");
	}
}

# Create user directories.
mkdir("$root/bots");
mkdir("$root/conf");
mkdir("$root/users");
open (my $dummy, ">", "$root/users/delete.me");
close ($dummy);

# Copy default configs.
print "Copying default configs...\n";
copy("./doc/Sample.json", "./$root/bots/Sample.json");
copy("./doc/botmaster.json", "./$root/conf/botmaster.json");
copy("./doc/colors.json", "./$root/conf/colors.json");

# Build the command for tar.
print "Building 'lite' distribution...\n";
sleep 1;
my @command = (
	"tar", "-czvf", "$root.tar.gz", "$root"
);
system(@command);

# Add the 'heavy' lib.
say "Copy: cp -r optlib $root/";
print "Building 'full' distribution...\n";
sleep 1;
system("cp", "-r", "optlib", "$root/");
$command[2] = "$root-full.tar.gz";
system(@command);

# Remove build root.
say "Removing build root.";
system("rm", "-rf", $root);

say "Done!";
