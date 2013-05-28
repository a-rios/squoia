#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
#use warnings;
use XML::LibXML;


chomp(my @entries = <STDIN>);

my %entries =();


for (my $i=0;$i<scalar(@entries);$i++)
{
	
	my $e = @entries[$i];
	# v. intr/tr pron. dem., dialects A./C., Cf. synonym, synonym separated with ',' different meanings in polysemous words separated with ';'
	#my ($qu_word, $type, $exactType, $trans) = ($e =~ m/^([^\.]+)\. (adj|conect|interrog|v|s|adv|interj|num)\.\s*(dem|interrog|cop|tr|intr|rec|reflex|impers|def|obsol|fig|arc)?\.(.+)/);
	my ($qu_word, $type, $rest) = ($e =~ m/^([^\.]+)\. (adj|conect|interrog|v|s|adv|interj|num)\.(.+)/);
	my ($exactType, $trans) = ($rest =~ m/(dem|interrog|cop|tr|intr|rec|reflex|impers|def|obsol|fig|arc)?(.+)/);
	
	# qu word in entry
	if($qu_word ne '')
	{
		unless($qu_word =~ /(\s.*){3,}/ )
		{
			#print "pos1: $type, exact: $exactType\n";
			#print " $qu_word # $type--$exactType# $trans\n";
			#print " rest: $rest\n";
			$entries{$qu_word} =  "#$type--$exactType# $trans";
		}	
	}
	
}

my %es_entries=();
foreach my $qu (keys %entries){
	#print  "$qu:  $entries{$qu}\n";
	my $es_translation = $entries{$qu};
	# get word class
		my ($postags)  = ($es_translation =~ m/#(.+)#/ );
		my ($pos, $exactType) = split('--',$postags);
		$es_translation =~ s/\Q#$postags#\E//g;
		#$es_translation =~ s/#//g;
		#print  "pos: $pos\n";
		#print STDERR "translation: $es_translation\n";
		
		#filter out he same quechua words in other dialects
		#my ($region, $dialect, $dialectwords) = ($es_translation =~ m/(C\.|A\.)\s*(.+?)\./g );
		my @dialectwords = ($es_translation  =~ m/((Cf\.\s*)?A\.\s*.+?)\./g );
		foreach my $d (@dialectwords)
		{
			$es_translation =~ s/\Q$d\E//g;
			#print "dialect: $d\n";
		}
		
		# get Cuczo synonyms
		my ($sinon, @syns) = ($es_translation =~ m/(Cf\.\s*C\.)\s*(.+?\.)/g );
		$es_translation =~ s/\Q$sinon\E//g;
		my @qu_synonyms;
		foreach my $s (@syns)
		{
			$es_translation =~ s/\Q$s\E//g;
			my @single_qu_synonyms = split(',',$s);
			push(@qu_synonyms, @single_qu_synonyms);
			#print "C sinon: @qu_synonyms \n";
		}
	
		# split alternative translations
		my (@es_words) = split(/;|,|\./,$es_translation);
		#print "words: @es_words\n";
		#my @es_words;
#		foreach my $a (@alternatives)
#		{
#			print "alt: $a\n";
#			my @single_es_words = split(',',$a);
#			push(@es_words, @single_es_words);
#			#print  "spanish: @single_es_words\n";
#		}
		
		# fill hash with spanish words and their translation (and word class)
		foreach my $es_word (@es_words)
		{	$es_word =~ s/^\s+//;
			#if($es_word =~ /(\s.*){4,}/){print "$es_word\n";}
			#don't use spanish translations that have more than 3 whitespaces (those are rather explanations than translations)
			unless($es_word =~ /(\s.*){3,}/  )
			{
				#delete '.' at end
				$es_word =~ s/\.$//g;
				#print "es:: $es_word: $qu\n";
				my %qu_trans;
				$qu_trans{$pos} = [$qu,@qu_synonyms];
				#print "$qu_trans{$pos}\n";
				if(exists $es_entries{$es_word}->{$pos} ){
					#print "contained: @{$es_entries{$es_word}->{$pos}}\n";
					push($es_entries{$es_word}->{$pos}, $qu);
					push($es_entries{$es_word}->{$pos}, @qu_synonyms);
				}
				else{
					#print "$es_word\n";
					$es_entries{$es_word} = \%qu_trans;
				}
			}
		}
		
	#print "shortened: $es_translation\n";
}
my $dom = XML::LibXML->createDocument ('1.0', 'UTF-8');
my $root = $dom->createElementNS( "", "dictionary" );
$dom->setDocumentElement( $root );

my $noun_section =  XML::LibXML::Element->new( 'section' );
$noun_section->setAttribute('id', 'nouns_new');
$noun_section->setAttribute('type', 'standard');

my $verbs_section =  XML::LibXML::Element->new( 'section' );
$verbs_section->setAttribute('id', 'verbs_new');
$verbs_section->setAttribute('type', 'standard');

my $adverbs_section =  XML::LibXML::Element->new( 'section' );
$adverbs_section->setAttribute('id', 'adverbs_new');
$adverbs_section->setAttribute('type', 'standard');

my $pronouns_section =  XML::LibXML::Element->new( 'section' );
$pronouns_section->setAttribute('id', 'pronouns_new');
$pronouns_section->setAttribute('type', 'standard');

my $conjunction_section =  XML::LibXML::Element->new( 'section' );
$conjunction_section->setAttribute('id', 'conjunctions_new');
$conjunction_section->setAttribute('type', 'standard');


$root->appendChild($noun_section);
$root->appendChild($verbs_section);
$root->appendChild($adverbs_section);
$root->appendChild($pronouns_section);
$root->appendChild($conjunction_section);


foreach my $esWord (keys %es_entries){
	      #$noun_section->appendChild($entry);
#adj|conect|interrog|v|s|adv|interj|num) (dem|interrog|cop|tr|intr|rec|reflex|impers|def|obsol|fig|arc)
	#print "es word: $esWord \n";
	$esWord = lc($esWord);
	# remove leading and trailing whitespaces
	#$esWord=~ s/^\s+//;
	#$esWord=~ s/\s+$//;
	chomp($esWord);
	#print  "es word: $esWord \n";
	
	foreach my $pos (keys %{$es_entries{$esWord}})
	{
		#print " pos: $pos\n";
			#print "pos: $pos  @{$es_entries{$esWord}->{$pos}}\n";
			foreach my $qu_word (@{$es_entries{$esWord}->{$pos}})
			{
				$qu_word = lc($qu_word);
				# remove leading and trailing whitespaces
				$qu_word=~ s/^\s+//;
				$qu_word=~ s/\s+$//;
				$qu_word=~ s/\.$//;
				#print "$qu_word\n";
				my $entry =  XML::LibXML::Element->new( 'e' );
	    		my $pair =  XML::LibXML::Element->new( 'p' );
	      		my $left =  XML::LibXML::Element->new( 'l' );
	      		$left->appendText($esWord);
	      		my $right =  XML::LibXML::Element->new( 'r' );
	      		$right->appendText($qu_word);
			    my $par =  XML::LibXML::Element->new( 'par' );
			    
			    if($pos eq 's' or $pos eq 'adj')
			    {
			    	$par->setAttribute('n', 'Noun_cp');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$noun_section->appendChild($entry);
			    }
			    elsif($pos eq 'adv')
			    {
			    	$par->setAttribute('n', 'Adverb_cp');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$adverbs_section->appendChild($entry);
			    }
			    elsif($pos eq 'conect')
			    {
			    	$par->setAttribute('n', 'Conjunctions_cp');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$conjunction_section->appendChild($entry);
			    }
	      			
	      		elsif($pos eq 'v')
			    {
			    	$par->setAttribute('n', 'Verb_main_cp');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$verbs_section->appendChild($entry);
			    }
			    
			    elsif($pos eq 'pron')
			    {
			    	$par->setAttribute('n', 'Pronouns_cp');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$pronouns_section->appendChild($entry);
			    }

			}
	
	}

}
# print xml to stdout
my $docstring = $dom->toString(3);
print STDOUT $docstring;
