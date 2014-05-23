#!/usr/bin/perl

# reads parameter from config file into a hash and writes hash to disk
# usage: perl readConfig.pl config.cfg

use utf8;
use open ':utf8';
use Storable;
use strict;


my $num_args = $#ARGV + 1;
if ($num_args != 1) {
  print "\nUsage:  perl readConfig.pl path-to-config\n";
  exit;
}

my $confFile = $ARGV[0];
open CONFIG, "< $confFile" or die "Can't open $confFile : $!";

my %Parameters = ();

while (<CONFIG>) {
	#print $_;
	chomp;       # no newline
	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	next unless length;    # anything left?

	( my $var, my $value ) = split( /\s*=\s*/, $_, 2 );

	if($var ne 'GRAMMAR_DIR')
	{
		my $grammarPath = $Parameters{'GRAMMAR_DIR'} or die "GRAMMAR_DIR not specified in config!";
		$value =~ s/\$GRAMMAR_DIR/$grammarPath/g;

	}
	#print "$var=$value\n";
	$Parameters{$var} = $value;
}
close CONFIG;
store \%Parameters, 'parameters';


