#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/util.pl";


my %mapMorphsToClasses = (
	'perfect'			=> 2,
	'passive'			=> 2,
	'obligative'		=> 3,
	'agentive'			=> 4,
	'SS'	=> 6,
	'DS'		=> 6,
	'switch'		=> 6,
	'main'		=> 7,
	'ambiguous'		=> -1,
	
);


#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

my @sentenceList = $dom->getElementsByTagName('SENTENCE');

print STDOUT "head_verb_es,subord_verb_es,linker,form\n";

foreach my $sentence (@sentenceList)
{
	# get all verb chunks and check if they have an overt subject, 
	# if they don't have an overt subject and precede the main clause -> look for subject in preceding sentence
	# if they don't have an overt subject and follow the main clause, and the main clause has an overt subject, this is the subject of the subordinated chunk
	#print STDERR "Looking for verb pairs in sentence:";
	#print STDERR $sentence->getAttribute('ord')."\n";
	
 	
 	# consider linear sequence in sentence; in xml the verb of the main clause comes always first, but in this case the subject of a preceding subordinated clause is probably coreferent with the subject of the preceding clause
 	my @verbChunks = $sentence->findnodes('descendant::CHUNK[@type="grup-verb"]');

 	#print STDERR "$nbrOfVerbChunks\n";
 	
 	foreach my $verbChunk (@verbChunks)
 	{
	   if($verbChunk->findvalue('child::CHUNK[@type="grup-verb" or @type="coor-v"]/@verbform') ne 'ambiguous' && $verbChunk->findvalue('child::CHUNK[@type="grup-verb" or @type="coor-v"]/@verbform') ne '')
	    {
		my $mainV = &getMainVerb2($verbChunk);
		my @subV = $verbChunk->findnodes('child::CHUNK[(@type="grup-verb" or @type="coor-v") and not(@verbform="" or @verbform="ambiguous" or contains(@verbform,"rel:"))]');
		my @CoorsubV = $verbChunk->findnodes('child::CHUNK[@type="coor-v" and not(@verbform="" or @verbform="ambiguous")]/CHUNK[@type="grup-verb" and not(@verbform="" or @verbform="ambiguous"  or contains(@verbform,"rel:"))]');
			
		push(@subV,@CoorsubV);
		
		if($mainV && scalar(@subV)>0)
		{
		  foreach my $subVchunk (@subV)
		  {
		    my $form = $subVchunk->getAttribute('verbform');
		    my $formnominal = $mapMorphsToClasses{$form};
		    my $subV = &getMainVerb2($subVchunk);
		    my $linker = $subVchunk->findvalue('child::NODE/NODE[@mi="CS"][1]/@lem');
		    # set linker (only necessary for desr output, in ancora, linker depends always on subordinated verb)
		    if ($linker eq '' )
		    { $linker = '0';}
		    
		    if($subV && $formnominal ne '' && $linker ne '')
		    {
		      #print STDOUT "$linker\n";
		      print STDOUT $mainV->getAttribute('lem').",".$subV->getAttribute('lem').",".$linker.",".$formnominal."\n";
		    }
		  }
		}
	    }
 	}
 	
}

sub getMainVerb2{
	my $relClause = $_[0];
	
	# main verb is always the first child of verb chunk	
	my $verb = @{$relClause->findnodes('child::NODE[starts-with(@mi,"V")][1]')}[-1];
	if($verb)
	{
		return $verb;
	}
	else
	{
		#get sentence id
		my $sentenceID = $relClause->findvalue('ancestor::SENTENCE/@ord');
		print STDERR "main verb not found in sentence nr. $sentenceID: \n ";
		print STDERR $relClause->toString();
		print STDERR "\n";
	}
 }


# print new xml to stdout
# my $docstring = $dom->toString(1);
# #print STDERR $dom->actualEncoding();
# print STDOUT $docstring;
