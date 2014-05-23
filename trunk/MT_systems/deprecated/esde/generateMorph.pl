#!/usr/bin/perl
						
use strict;

my $generator="flookup bla.fst";
if (@ARGV) {
	$generator=$ARGV[0];
	shift;
}
print STDERR "Morphology generator: $generator\n";

while(<>) {
	chomp;
	if (/\|/) {
		my ($pref,$verb) = split /\|/;
		print STDERR "Prefix: $pref ; verb: $verb\n";
		my $morph = `echo "$verb" | $generator `;
		if ($morph !~ /\+\?/) {
			my ($stts,$form) = split(/\t/,$morph);
			chomp($morph);
			print STDOUT $pref."|".$stts."\t".$pref.$form;
		}
		else {
			print STDOUT $pref."|".$morph;
		}
	}
	else {
		print STDERR "Stts string: $_ to generate\n";
		my $morph = `echo "$_" | $generator `;
		print STDOUT $morph;
	}
}
