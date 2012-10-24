Aires Bot
=========

A multiprotocol Perl chatbot for AIM, Yahoo, XMPP and others. It supports
connections to multiple networks ("listeners") and can run multiple bots with
distinct brains and personalities, including RiveScript and Eliza.

Listeners and brains are pluggable, and new ones can be added simply by dropping
a module in the appropriate folder (or writing one if one doesn't exist).

Note About Third Party Modules
==============================

This chatbot is intended to be ready-to-go as soon as it's downloaded. As such,
it includes a handful of third party Perl modules that it needs to run well.
These include some protocol modules (for AIM and Yahoo, etc.) and some chatbot
brains.

All the third party modules are included in the "optlib" directory. These
modules may become outdated as time goes on though, so I'd recommend you
remove this directory and install the third party modules yourself. If you
don't care and just want to run a chatbot, it's probably OK to leave it as
it is.

Setting Up
==========

You will require Perl version 5.14 or later to run Aires.

Windows Users:

	You can get Perl 5.14 via ActivePerl (recommended)
	www.activeperl.com

	Alternatively, you can get it via Strawberry Perl,
	www.strawberryperl.com

Everyone Else:

	If your operating system doesn't ship with Perl 5.14, you will have to
	install it yourself. For the lazy, you can try ActivePerl for Linux and
	use that. For everyone else, install `perlbrew` to set up 5.14:

	http://search.cpan.org/perldoc?perlbrew

Configuring Your Bots
=====================

In the "bots" directory you will find "Sample.json" - open this in a text editor
to configure your bot. The config file is well documented.

To set up the list of botmasters (privileged users who are allowed to give admin
commands to the bots), edit the file "botmaster.json" in the "conf" directory.

Running The Bots
================

In a command prompt or terminal window, navigate to where you installed Aires
to and run the following command:

	perl cli.pl

If all goes well, your bots should sign on!

For Windows users, the file "win32-cli.bat" may simply be double-clicked on to
run the bot.

Caveats
=======

The AIM listener included in this repo uses `Net::OSCAR` and is pretty stable
and featureful. The YMSG listener however uses a beta quality module that I
helped write, `Net::IM::YMSG`.

Known issues with `Net::IM::YMSG` is that when the bot receives an add request,
the bot won't appear online for the new user until the bot is restarted.
Sending and receiving messages and typing notifications, however, works just
fine. If the add contact bug is a problem for you, I recommend using the
XMPP listener instead, in conjunction with an XMPP server such as Openfire
(http://www.igniterealtime.org/projects/openfire/) and Gateways to sign your
bot on to Yahoo via your XMPP server.

License
=======

This application is licensed under the GNU General Public License version 2
(see License.txt). This basically means, this application is open source, if you
make any modifications to it and want to release your custom version of the
code, you must make YOUR version of the code open source as well. Oh, and don't
go and delete all mention of the original author either, that's just not a nice
thing to do. :)

This code is copyright (C) 2012 Noah Petherbridge.
http://www.kirsle.net
