#!/usr/bin/env perl
use warnings;
use strict;
use 5.010;
use ShortIsGd;

sub handle {
	my %arg = @_;
	if ($arg{url}) {
		say "short URL: $arg{url}";
	}
	elsif ($arg{err_text}) {
		say "error: $arg{err_text}";
	}
	else {
		say "I didn't call the function properly! My bad!";
	}
}

$ShortIsGd::min_url_len = 20;
my %reply = ShortIsGd::shorten("http://www.google.com");
handle (%reply);

