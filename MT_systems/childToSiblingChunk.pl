#!/usr/bin/perl

# Configuration: ChildToSiblingFile
# 	child chunks become siblings of head (parent) chunks (to be reordered independently among other chunks)
# Format:
#	1				2
#	childChunkCondition		targetChunkAttrVal
# Example:
# 	subjectOfRelativeClause		comment="oblique relative clause",flat=true
#
#

use strict;

use utf8;
use Storable; # to retrieve hash from disk
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/util.pl";

my %hash;
# retrieve hash with config parameters from disk, get path to file with semantic information
eval
{
	%hash = %{ retrieve("parameters") }; 
} or die "No parameters defined. Run readConfig.pl first!";

my $childSiblingFile= $hash{"ChildToSiblingFile"} or die "ChildToSiblingFile not specified in config!";
open childSiblingFile, "< $childSiblingFile" or die "Can't open $childSiblingFile : $!";

my %targetAttributes;

# read the chunk conditions from file into a hash (childChunkCond, targetChunkAttrVal )
while(<childSiblingFile>)
{
 	chomp;
 	s/#.*//;     # no comments
	s/^\s+//;    # no leading white
	s/\s+$//;    # no trailing white
	next if /^$/;	# skip if empty line
	my ($childChunkCond, $targetChunkAttrVal ) = split( /\s*\t+\s*/, $_, 2 );
	$targetAttributes{$childChunkCond} = $targetChunkAttrVal;

}

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

foreach my $chunk ( $dom->findnodes('//CHUNK/CHUNK/CHUNK') ) {	# the candidates child chunks must have a grandparent chunk to become sibling of their parent chunk
	my $grandparent = $chunk->parentNode->parentNode;
	foreach my $chunkCond (keys %targetAttributes) {
		#check chunk conditions
		my @chunkConditions = &splitConditionsIntoArray($chunkCond);
		my $result = &evalConditions(\@chunkConditions,$chunk);
		if ($result) {
			# "move" the CHUNK node to the grandparent CHUNK to become a sibling of the parent CHUNK
			$chunk->unbindNode();
			$grandparent->appendChild($chunk);
			my @attributes = split(",",$targetAttributes{$chunkCond});
			foreach my $attrVal (@attributes) {
				my ($newChunkAttr,$newChunkVal) = split("=", $attrVal);
				$newChunkVal =~ s/["]//g;
				print STDERR "setting attribute $newChunkAttr to $newChunkVal\n";
				$chunk->setAttribute($newChunkAttr,$newChunkVal);
			}
		}
	}
}

# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;


