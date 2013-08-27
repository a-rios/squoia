#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;


my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage:  perl readInSemanticDix.pl path-to-verb-lexicon (Ancora xml) path-to-noun-lexicon (lemma:tag)\n";
  exit;
}

my $nounLex = $ARGV[1];

open NOUNS, "< $nounLex" or die "Can't open $nounLex : $!";

my %nounLex = ();

while(<NOUNS>)
{
	s/#.*//;     # no comments
	(my $lemma, my $semTag) = split(/:/,$_);
	$nounLex{$lemma} = $semTag;
}

store \%nounLex, 'NounLex';

my $verbLex = $ARGV[0];

open LEXICON, "< $verbLex" or die "Can't open $verbLex : $!";

my $dom    = XML::LibXML->load_xml( IO => *LEXICON );

my @lexEntriesList = $dom->getElementsByTagName('lexentry');

my %lexEntriesWithFrames = ();


# get all lexentries
#foreach my $node ( $dom->getElementsByTagName('*'))
foreach my $lexentry (@lexEntriesList)
{
	my $lemma = $lexentry->getAttribute('lemma');
	my @frames = $lexentry->findnodes('descendant::frame');
	my @types = ();
	#my @lss = ();
	#my @uniqueframes =();
	
	foreach my $frame (@frames)
	{
		#get old_type (subcategorization classes of frames)
		my $lss = $frame->getAttribute('lss');
		my $type = $frame->getAttribute('type');
		my $thematicRoleOfSubj = $frame->findvalue('child::argument[@function="suj"]/@thematicrole');

		

		# save frame as combination of lss (lexical semantic structure) & type (diathesis)
		my $lsstype = "$lss#$type##$thematicRoleOfSubj";

		#find transitive/intransitive ambigous forms		
#		if(scalar(@lss)== 0)
#		{
#			push(@lss, $lsstype);
#		}
#		elsif (scalar(@lss)>0 && $lsstype=~ /^[BCD]/ && $lsstype !~ /anticausative|passive|impersonal|resultative/  && grep {$_ =~ /^A/} @lss)
#		{
#			#print "$lem\n";
#			push(@lss, $lsstype);
#			push(@uniqueframes,$lsstype);
#		}
#		else
#		{
#			push(@lss, $lsstype);
#		}
#		
		
		# if type is not yet in array of types for this entry, add it 
		# (unless type is resultative -> those are ingnored)
		# passive is also ignored, as FL does not analyze those as relative clauses
		if (!grep {$_ eq $lsstype} @types && $type ne 'resultative')
		{
				push(@types,$lsstype);
 			
		}

	}
#	if(@uniqueframes && scalar(@types)>1)
#	{
#		if(grep {$_ =~ /##(exp|src|ins|loc|pat|tem)/} @uniqueframes)
#		{
#			print "$lemma: @uniqueframes\n";
#	}}
	#push(@{$lexEntriesWithFrames{$lemma}}, $type);
	$lexEntriesWithFrames{$lemma} = \@types;
	#print STDERR "$lemma\n";
	
}

store \%lexEntriesWithFrames, 'VerbLex';


#
# foreach my $key (sort keys %lexEntriesWithFrames)
# {
# 	#print "$key: ";
# 	foreach my $frame (@{ $lexEntriesWithFrames{$key} })
# 	{
# 		if($frame =~ /A32/)
# 		{print "$key: $frame \n";}
# 	}
# 	#print @{ $lexEntriesWithFrames{$key} }[0];
# 	#print "\n";
# }
