=head1 NAME

ShortIsGd - A simple interface to is.gd URL shortener

=head1 SYNOPSIS

  use ShortIsGd;
  my %reply = ShortIsGd::shorten("http://www.google.com");
  print "$reply{url}",\n if $reply{url};

=head1 DESCRIPTION

It is a simple interface to is.gd URL shortener without unnecessary dependencies.

It caches results. Also it stops making requests for some time if the server
demands so.

=over 4

=item shorten ( $url )

Argument $url is the URL to be shortened.

The function seturns an undefined value if no argument is provided or the argument
doesn't start with http:// or https://. Otherwise returns a hash. If
the server returns a shortened URL (no error occured), the hash key is B<url>
and the value contains shortened URL. Otherwise a hash with one key, B<error_text>
is returned. The value contains a human readable error description that can be
displayed as is.

=item $min_url_len

Minimal URL length to be shortened. If the specified URL is shorter than this or longer
than 900 characters, an error is reported. Default: 30. It can be changed using
C<$ShortIsGd::min_url_len>.

=item $CACHE_MAX

Results are cached, so for example if one requests to shorten an URL twice, a HTTP
request is needed to be done only once (provided CACHE_MAX is more than
zero). C<$CACHE_MAX_URL> is the number or URLs to be cached (100 by default). It
can be changed using C<$ShortIsGd::CACHE_MAX>.

=back

=head1 COPYRIGHT

Copyright (C) 2012 by Enlik. Contact: poczta-sn at gazeta.pl.

This program is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut

package ShortIsGd;
use warnings;
use strict;
use LWP::UserAgent;
use URI::Escape;

our $min_url_len = 30;
our $CACHE_MAX = 100;

my $ua;
my @cache = ();
my $startlocktime;
my $lock_time_s = 30;

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
