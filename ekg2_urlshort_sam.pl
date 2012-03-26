# script for ekg2 that shortens long URLs
# https://github.com/Enlik/ShortIsGd

# by Enlik

{
# this module with documentation can be found at: https://github.com/Enlik/ShortIsGd
# Modified a bit to use package scope variables, because otherwise if script is
# loaded in (current) ekg2 via autorun, warnings are printed, like this one below.
# Variable "$startlocktime" will not stay shared at (eval 2) line 39

package ShortIsGd;
use warnings;
use strict;
use LWP::UserAgent;
use URI::Escape;

our $min_url_len = 30;
our $CACHE_MAX = 100;

our $ua;
our @cache = ();
our $startlocktime;
our $lock_time_s = 30;

sub shorten {
	my $url = shift or return;

	return unless $url =~ m!^https?://!;
	# just some sane values
	if (length($url) < $min_url_len or length($url) > 900) {
		return err_text => "URL length is too short or too long"
	}

	my %lut = @cache;
	if ($lut{$url}) {
		# be smart, move it to the end, so it's not removed too soon
		push @cache, $url, $lut{$url};
		splice @cache, 0, 2;
		return url => $lut{$url}
	}

	if ($startlocktime and time() - $startlocktime < $lock_time_s) {
		return err_text => "still waiting to release the lock"
	}

	unless ($ua) {
		$ua = LWP::UserAgent->new(
			env_proxy => 1,
			timeout => 10,
			max_size => 10240,
		);
	}
	my $req_beg = "http://is.gd/create.php?format=simple&url=";
	my $resp = $ua->get($req_beg . uri_escape($url));

	if ($resp->is_success) {
		my $content = $resp->content;
		unless ($content =~ m!^http://!) {
			return err_text => "server returned incorrect reply"
		}

		push @cache, $url, $content;
		if (@cache/2 > $CACHE_MAX) {
			splice @cache, 0, 2;
		}
		return url => $content
	}

	# something went wrong; inspect all error codes that apply
	my $code = $resp->code;
	if ($code == 400) {
		return err_text => "problem with original URL"
	} elsif ($code == 502) {
		$startlocktime = time();
		return err_text =>
			"rate limit exceeded, will stop shortening not cached URLs " .
			"for $lock_time_s seconds";
	} elsif ($code == 503) {
		return err_text => "unknown error returned by server"
	} else {
		return err_text => "unexpected error: " . $resp->status_line
	}
}

1;
} # end of ShortIsGd

use Ekg2;
use warnings;
use strict;

# installs command /cut
# /cut prints shortened version of last URL
# /cut NUMBER prints shortened version of NUMBER of last URLs
# /cut help for help

our $VERSION = "0.4";
our %EKG2 = (
	authors     => "Enlik",
	contact     => "poczta-sn*gazeta.pl",
	description => "URL shortener",
	license     => "MIT",
	changed     => "2012-02-18"
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
			$base_url = $1 if $url =~ m!^https?://([^/]+)!;
			%reply = ShortIsGd::shorten($url);
			if ($reply{url}) {
				Ekg2::Window::print_format ($w, "urlshort_print_url",
					$base_url, $reply{url});
			}
			elsif ($reply{err_text}) {
				Ekg2::Window::print_format ($w, "generic2",
					"[$base_url] -> error: " . $reply{err_text});
			}
			else {
				Ekg2::Window::print_format ($w, "generic_error",
					$base_url . " -> full URL: [$url]: something wrong has " .
					"occured. Please file a bug providing this message.");
			}
		}
	}
	else {
		Ekg2::Window::print_format ($w, "generic2", "No URLs here.");
	}
}

sub msg_handler {
	my ($session, $sender, $rcpt, $text) = @_;
	return 1 if ($$session eq $$sender);
	# \x{1b} is Esc control char. Hello IRC plugin!
	my $R = qr{(?:^| )((?:https?://)[\w\d:#@%/,;$()!~_\?\+-=\.&\|-]+)(?= |\x{1b}|$)}m;
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
	my $w = Ekg2::window_current();

	if ($args eq "help") {
		Ekg2::Window::print ($w, "/cut displays the last URL shortened.");
		Ekg2::Window::print ($w, "/cut <number> displays the last <number> " .
			"URLs shortened (maximum 9)");
	}
	elsif ($args =~ /^[0-9]?$/) {
		$args = 1 if $args eq "";
		print_url_for_window ($w, $args);
	}
	else {
		Ekg2::Window::print ($w, "try /cut help");
	}
}

Ekg2::format_add("urlshort_print_url", "%> %T[%1]%n => %G%2%n");
Ekg2::handler_bind('protocol-message', 'msg_handler');
Ekg2::command_bind('cut', 'cmd_handler');
return 1;
