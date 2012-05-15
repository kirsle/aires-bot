#!/usr/bin/perl

use 5.14.0;
use strict;
use warnings;

use lib "./optlib";
use lib "./src";

use Bot::AiRS;

my $bot = Bot::AiRS->new();

# Set the output handler.
$bot->setHandler (print => sub {
	my $line = shift;
	say $line;
});

# Run the bot.
$bot->init();
$bot->run();
