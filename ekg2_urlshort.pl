# script for ekg2 that shortens long URLs
# https://github.com/Enlik/ShortIsGd

# by Enlik

use Ekg2;
use warnings;
use strict;
use ShortIsGd;

# installs command /cut
# /cut prints shortened version of last URL
# /cut NUMBER prints shortened version of NUMBER of last URLs
# /cut help for help

our $VERSION = "0.2";
our %EKG2 = (
	authors     => "Enlik",
	contact     => "poczta-sn*gazeta.pl",
	description => "URL shortener",
	license     => "MIT",
	changed     => "2012-02-01"
);

# remember 9 last URLs per sender
our %nickurl = ();

sub add_url {
	# $nick is sender's "proto:id" string (can be irc:channel) or a nick
	# $url is a long URL
	my ($nick, $url) = @_;
	my @urls = ();
	@urls = @{$nickurl{$nick}} if defined $nickurl{$nick};
	push @urls, $url;
	if (@urls > 9) {
		splice @urls, 0, 1;
	}
	$nickurl{$nick} = [ @urls ];
}

sub print_url_for_window {
	my ($w, $max) = @_;
	# my $ul = Ekg2::Window::userlist ($w); --> no luck
	my $ul = Ekg2::Session::userlist ($w->{session});
	my $user = Ekg2::Userlist::find ($ul, $w->{target});
	my $USER = defined $user ? $user->{nickname} : $w->{target};
	my %reply;
	my $base_url = "";

	if ($nickurl{$USER} and @{$nickurl{$USER}}) {
		my @urls = @{$nickurl{$USER}};
		# in order
		my $begin = @urls - $max;
		$begin = 0 if $begin < 0;
		for my $url (@urls[$begin .. $#urls]) { # argh I tend to write a comma
			$base_url = "[$1]" if $url =~ m!^https?://([^/]+)!;
			%reply = ShortIsGd::shorten($url);
			if ($reply{url}) {
				Ekg2::echo ($base_url . " => " . $reply{url});
			}
			elsif ($reply{err_text}) {
				Ekg2::echo ($base_url . " -> error: " . $reply{err_text});
			}
			else {
				Ekg2::echo ($base_url . " -> full URL: [$url]: something " .
					"wrong has occured. Please file a bug providing this message.");
			}
		}
	}
	else {
		Ekg2::echo ("No URLs here.")
	}
}

sub msg_handler {
	my ($session, $sender, $rcpt, $text) = @_;
	return 1 if ($$session eq $$sender);
	# \x{1b} is Esc control char. Hello IRC plugin!
	my $R = qr{(?:^| )((?:https?://)[\w\d:#@%/,;$()~_\?\+-=\.&\|-]+)(?= |\x{1b}|$)}m;
	my $url;
	my $USER;

	while ($$text =~ /$R/g) {
		$url = $1;
		# find $USER when needed, and only once
		if (!defined $USER) {
			my $ses = Ekg2::session_find($$session);
			my $ul = Ekg2::Session::userlist($ses);
			my $user = Ekg2::Userlist::find($ul, $$sender);
			$USER = defined $user ? $user->{nickname} : $$sender;
		}
		add_url ($USER, $url);
	}

	1;
}

sub cmd_handler {
	my ($cmd, $args) = @_;
	$args = "" unless defined $args; # maybe always defined, but it won't hurt
	return unless $cmd and $cmd eq "cut";
	if ($args eq "help") {
		Ekg2::echo ("/cut displays the last URL shortened.");
		Ekg2::echo ("/cut <number> displays the last <number> URLs shortened " .
			"(maximum 9)");
	}
	elsif ($args =~ /^\d$/) {
		my $w = Ekg2::window_current();
		print_url_for_window ($w, $args);
	}
	elsif ($args eq "") {
		my $w = Ekg2::window_current();
		print_url_for_window ($w, 1);
	}
	else {
		Ekg2::echo ("try /cut help");
	}
}

Ekg2::handler_bind('protocol-message', 'msg_handler');
Ekg2::command_bind('cut', 'cmd_handler');
return 1;
