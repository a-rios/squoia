#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
#use warnings;
use XML::LibXML;


chomp(my @entries = <STDIN>);

my %entries =();

my $newE = '';
my $lastquWord='';

for (my $i=0;$i<scalar(@entries);$i++)
{
	
	my $e = @entries[$i];
	my ($qu_word, $type, $trans) = ($e =~ m/^([^\.]+)\. (adj|v|s|adv|conj|imper|interj|loc|núm|prep|pron|suf)\.(.+)/);
	
	# qu word in entry
	if($qu_word ne '')
	{
		#$newE =0;
		unless($qu_word =~ /(\s.*){3,}/ )
		{
			# here starts a new entry, save last entry before starting with this one
			unless($lastquWord eq '')
			{
				$entries{$lastquWord}=$newE;
			}
			#print "\n";
			#print " $qu_word  $type # ";
			$newE = "#$type# $trans";
			$lastquWord = $qu_word;
		}	
	}
	# spanish translation/explanation
	else
	{
			#print " $e";
			$newE = $newE." ".$e;
	}
	
	
}

my %es_entries=();
foreach my $qu (keys %entries){
	#print STDOUT "$qu:  $entries{$qu}\n";
	my $es_translation = $entries{$qu};
	# get word class
		my ($pos)  = ($es_translation =~ m/#(.+)#/ );
		$es_translation =~ s/\Q#$pos#\E//g;
		#$es_translation =~ s/#//g;
		#print "pos: $pos\n";
		
		#delete stuff in brackets 
		my (@bracketedStuff)=($es_translation =~ m/(\(.+?\))/g );
		#print "brackets: @bracketedStuff\n";
		foreach my $b(@bracketedStuff){
			$es_translation =~ s/\Q$b\E//g;
		}
		#filter out he same quechua words in other dialects
		#my ($region, $dialect, $dialectwords) = ($es_translation =~ m/(Pe|Ec|Bol|Arg)(.*?):(.+?)\./g );
		my @dialectwords = ($es_translation =~ m/(Pe\.|Ec|Bol|Arg)(.*?:)(.+?\.)/g );
		foreach my $d (@dialectwords)
		{
			$es_translation =~ s/\Q$d\E//g;
			#print "$d :: ";
		}
		# filter out examples (EJEM)
		my @examples = ($es_translation =~ m/(EJEM:.+?\.)/g );
		foreach my $e (@examples)
		{
			$es_translation =~ s/\Q$e\E//g;
			#print "examples $e \n";
		}
		# get synonyms
		my ($sinon, @syns) = ($es_translation =~ m/(SINÓN:?)(.+?\.)/g );
		$es_translation =~ s/\Q$sinon\E//g;
		my @qu_synonyms;
		foreach my $s (@syns)
		{
			$es_translation =~ s/\Q$s\E//g;
			my @single_qu_synonyms = split(',',$s);
			push(@qu_synonyms, @single_qu_synonyms);
			#print "sinon: @qu_synonyms \n";
		}
		# get 'véases' v. SYNONYM
		my ($vease, @VEASE) = ($es_translation =~ m/(V.)(.+?\.)/g );
		$es_translation =~ s/\Q$vease\E//g;
		foreach my $v (@VEASE)
		{
			$es_translation =~ s/\Q$v\E//g;
			my @single_vease_synonyms = split(',',$v);
			push(@qu_synonyms, @single_vease_synonyms);
			#print "sinon: @qu_synonyms \n";
		}
		
		# split alternative translations
		my (@alternatives) = split(/\|\|/,$es_translation);
		my @es_words;
		foreach my $a (@alternatives)
		{
			#$es_translation =~ s/$s//g;
			my @single_es_words = split(/,|\//,$a);
			push(@es_words, @single_es_words);
			#print "spanish: @es_words \n";
		}
		
		# fill hash with spanish words and their translation (and word class)
		foreach my $es_word (@es_words)
		{
			unless($es_word =~ /(\s.*){3,}/ or $es_word =~ /'|\d/  )
			{
				#delete '.' at end
				$es_word =~ s/\.//g;
				
				
				#don't use spanish translations that have more than 3 whitespaces (those are rather explanations than translations)
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

my $nounproper_section =  XML::LibXML::Element->new( 'section' );
$nounproper_section->setAttribute('id', 'nounsproper_new');
$nounproper_section->setAttribute('type', 'standard');

my $verbs_section =  XML::LibXML::Element->new( 'section' );
$verbs_section->setAttribute('id', 'verbs_new');
$verbs_section->setAttribute('type', 'standard');

my $adverbs_section =  XML::LibXML::Element->new( 'section' );
$adverbs_section->setAttribute('id', 'adverbs_new');
$adverbs_section->setAttribute('type', 'standard');

my $locutions_section =  XML::LibXML::Element->new( 'section' );
$locutions_section->setAttribute('id', 'locutions_new');
$locutions_section->setAttribute('type', 'standard');

my $prepositions_section =  XML::LibXML::Element->new( 'section' );
$prepositions_section->setAttribute('id', 'prepositions_new');
$prepositions_section->setAttribute('type', 'standard');

my $conjunction_section =  XML::LibXML::Element->new( 'section' );
$conjunction_section->setAttribute('id', 'conjunctions_new');
$conjunction_section->setAttribute('type', 'standard');


$root->appendChild($noun_section);
#$root->appendChild($nounproper_section);
$root->appendChild($verbs_section);
$root->appendChild($adverbs_section);
$root->appendChild($locutions_section);
$root->appendChild($prepositions_section);
$root->appendChild($conjunction_section);


foreach my $esWord (keys %es_entries){
	      #$noun_section->appendChild($entry);
#(adj|v|s|adv|conj|imper|interj|loc|núm|prep|pron|suf
	#print "es word: $esWord \n";
	$esWord = lc($esWord);
	# remove leading and trailing whitespaces
	#$esWord=~ s/^\s+//;
	#$esWord=~ s/\s+$//;
	#print "es word: $esWord \n";
	
	foreach my $pos (keys %{$es_entries{$esWord}})
	{
			#print "pos: $pos  @{$es_entries{$esWord}->{$pos}}\n";
			foreach my $qu_word (@{$es_entries{$esWord}->{$pos}})
			{
				$qu_word = lc($qu_word);
				# remove leading and trailing whitespaces
				$qu_word=~ s/^\s+//;
				$qu_word=~ s/\s+$//;
				$qu_word=~ s/\.$//;
				my $entry =  XML::LibXML::Element->new( 'e' );
	    		my $pair =  XML::LibXML::Element->new( 'p' );
	      		my $left =  XML::LibXML::Element->new( 'l' );
	      		$left->appendText($esWord);
	      		my $right =  XML::LibXML::Element->new( 'r' );
	      		$right->appendText($qu_word);
			    my $par =  XML::LibXML::Element->new( 'par' );
			    
			    if($pos eq 's' or $pos eq 'adj')
			    {
			    	$par->setAttribute('n', 'Noun_ac');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$noun_section->appendChild($entry);
			    }
			    elsif($pos eq 'adv')
			    {
			    	$par->setAttribute('n', 'Adverb_ac');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$adverbs_section->appendChild($entry);
			    }
			    elsif($pos eq 'conj')
			    {
			    	$par->setAttribute('n', 'Conjunctions_ac');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$conjunction_section->appendChild($entry);
			    }
	      			
	      		elsif($pos eq 'v')
			    {
			    	$par->setAttribute('n', 'Verb_main_ac');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$verbs_section->appendChild($entry);
			    }
			    
			    elsif($pos eq 'prep')
			    {
			    	$par->setAttribute('n', 'Prepositions_ac');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$prepositions_section->appendChild($entry);
			    }
			    elsif($pos eq 'loc')
			    {
			    	$par->setAttribute('n', 'Locutions_ac');
	    			$entry->appendChild($pair);
	      			$entry->appendChild($par);
	      			$pair->appendChild($left);
	      			$pair->appendChild($right);
	      			$locutions_section->appendChild($entry);
			    }

			}
	
	}

}
# print xml to stdout
my $docstring = $dom->toString(3);
print STDOUT $docstring;
