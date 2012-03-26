# script for weechat that shortens long URLs
# https://github.com/Enlik/ShortIsGd

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# ----

# by Enlik

use warnings;
use strict;
use ShortIsGd;

# installs command /cut
# /cut prints shortened version of last URL
# /cut NUMBER prints shortened version of NUMBER of last URLs
# /cut help for help

weechat::register("urlshort", "Enlik", "0.1.1", "MIT",
	"Shortens long URLs on demand", "", "");
weechat::hook_print ("", "", "://", 1, "print_cb", "");
weechat::hook_command ("cut", "/cut displays the last URL shortened. " .
	"/cut <num> displays the last <number> URLs shortened (maximum 9).",
	 "", "", "", "cmd_cb", "");

# remember 9 last URLs per sender (buffer)
our %nickurl = ();

sub add_url {
	# $id: buffer name
	# $url is a long URL
	my ($id, $url) = @_;
	my @urls = ();
	@urls = @{$nickurl{$id}} if defined $nickurl{$id};
	push @urls, $url;
	if (@urls > 9) {
		splice @urls, 0, 1;
	}
	$nickurl{$id} = [ @urls ];
}

sub print_url_for_window {
	my ($w, $max) = @_;
	my $id = weechat::buffer_get_string($w, "name");
	my %reply;
	my $base_url = "";

	my $bold  = weechat::color ("bold");
	my $green = weechat::color ("green");
	my $deflt = weechat::color ("chat");
	my $red   = weechat::color ("red");

	if ($nickurl{$id} and @{$nickurl{$id}}) {
		my @urls = @{$nickurl{$id}};
		# in order
		my $begin = @urls - $max;
		$begin = 0 if $begin < 0;
		for my $url (@urls[$begin .. $#urls]) { # argh I tend to write a comma
			$base_url = $1 if $url =~ m!^https?://([^/]+)!;
			%reply = ShortIsGd::shorten($url);
			if ($reply{url}) {
				weechat::print ($w, "${bold}[$base_url] ${deflt}=> ${green}" .
					$reply{url});
			}
			elsif ($reply{err_text}) {
				weechat::print ($w, "${bold}[$base_url] ${deflt}-> ${red}error: " .
					$reply{err_text});
			}
			else {
				weechat::print ($w, "${red}-> full URL: [$url]: something wrong " .
					"has occured. Please file a bug providing this message.");
			}
		}
	}
	else {
		my $bold  = weechat::color ("bold");
		weechat::print ($w, "${bold}No URLs here.");
	}
}

sub print_cb {
	my ($data, $buffer, $date, $tags, $displayed, $highlight, $prefix, $message)
		= @_;
	my %tags = map { $_ => 1 } split /,/, $tags;
	return weechat::WEECHAT_RC_OK
		unless ($tags{notify_message} or $tags{notify_private});
	# just a note: $message contains nick
	my $R = qr{(?:^| )((?:https?://)[\w\d:#@%/,;$()!~_\?\+-=\.&\|-]+)(?= |$)}m;

	while ($message =~ /$R/g) {
		add_url (weechat::buffer_get_string($buffer, "name"), $1);
	}

	weechat::WEECHAT_RC_OK;
}

sub cmd_cb {
	my ($data, $buffer, $args) = @_;
	$args = "" unless defined $args; # maybe always defined, but it won't hurt

	if ($args =~ /^[0-9]?$/) {
		$args = 1 if $args eq "";
		print_url_for_window ($buffer, $args);
	}
	else {
		weechat::print ($buffer, "try help /cut");
	}
}
