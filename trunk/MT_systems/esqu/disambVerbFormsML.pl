#!/usr/bin/perl

# get the ambiguous subordinated verbs together with main verb and possible linker
# input: xml after synTransferIntra
#	<CHUNK ref="16" type="grup-verb" si="S" verbform="ambiguous" lem="lograr" verbmi="VRoot+IPst+1.Sg.Subj">
#	<NODE ref="16" alloc="" slem="lograr" smi="VMIS1S0" sform="logré" UpCase="none" lem="unspecified" mi="indirectpast" verbmi="VRoot+IPst+1.Sg.Subj">
#	<SYN lem="unspecified" mi="indirectpast" verbmi="VRoot+IPst+1.Sg.Subj"/>
#	<SYN lem="unspecified" mi="directpast" verbmi="VRoot+NPst+1.Sg.Subj"/>
#	<SYN lem="unspecified" mi="perfect" verbmi="VRoot+Perf+1.Sg.Poss"/>
#	<SYN lem="unspecified" mi="DS" verbmi="VRoot+DS+1.Sg.Poss"/>
#	<SYN lem="unspecified" mi="agentive" verbmi="VRoot+Ag"/>
#	<SYN lem="unspecified" mi="SS" verbmi="VRoot+SS"/>
#	</NODE>
# output: test file to pass to the ML classifier
#	class, main_es_verb, subord_es_verb, linker
#

use utf8;
use Storable;    # to retrieve hash from disk
use open ':utf8';
#binmode STDIN, ':utf8';
#binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use XML::LibXML;
use strict;
use AI::NaiveBayes1;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/../util.pl";

#print STDERR "actual path: $path\n";

my %mapClassToVerbform = (
	2	=> 'perfect',
	3	=> 'obligative',
	4	=> 'agentive',
	6	=> 'switch',
	7	=> 'main'
);

my $nb;
#check if verbforms.yaml (naive bayes model) exists, if not, train on verbInstances.csv
# eval
# {
# 	 my $pathToModel = $path."/verbforms.yaml";
# 	 print STDERR $pathToModel."\n";
# 	 $nb = AI::NaiveBayes1->import_from_YAML_file($pathToModel);
# 
# } or print STDERR "no model found on disk, train Naive Bayes on verbInstances.csv first\n";

$nb = AI::NaiveBayes1->import_from_YAML_file($path."/verbforms.yaml");

if(!$nb)
{
	  	my $nb = AI::NaiveBayes1->new;
	  	open TRAIN, "< verbInstances.csv" or die "Can't open verbInstances.csv : $!";
	  	my %instances = ();

		while(<TRAIN>)
		{
		 	unless($_ =~ /^%|head/)
			{
				s/\n//g;
				if(exists $instances{$_})
				{
					$instances{$_}++;
					#print STDERR $instances{$_};
				}
				else
				{
					$instances{$_} = 1;
				}
			}
		}
		
		foreach my $key (keys %instances)
		{
			my ($head, $subV, $linker, $form) = split(',', $key);
			#print STDERR "$head\t$subV\t$linker\t$form\t$instances{$key}\n";
	
			#$nb->add_instance(attributes => {head => $head, subV => $subV, linker => $linker},
    		 #label => $form);
    		$nb->add_instances(attributes => {head => $head, subV => $subV, linker => $linker},
    		 label => $form, cases=>1);

		}
		$nb->{smoothing}{head} = 'unseen count=0.001';
 		$nb->{smoothing}{subV} = 'unseen count=0.001';
 		$nb->{smoothing}{linker} = 'unseen count=0.001';
 		$nb->train;
  
  		$nb->export_to_YAML_file( "$path/verbforms.yaml" );
}
else
{
	$nb = AI::NaiveBayes1->import_from_YAML_file("$path/verbforms.yaml");
}


my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my $sno;
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	$sno = $sentence->getAttribute('ref');
	print STDERR "SENT $sno\n";
	#get all interesting NODES within SENTENCE
	my @sentenceNodes = $sentence->findnodes('descendant::NODE[parent::CHUNK[@verbform] or starts-with(@smi,"PR") or @smi="CS"]'); #head verb, relative pronoun, or subordinating conjunction

	my %nodereforder;
	foreach my $node (@sentenceNodes) {
		my $ref = $node->getAttribute('ref');
		$nodereforder{$ref} = $node;
	}
	my @nodes;
	foreach my $ref (sort { $a <=> $b } keys %nodereforder) {
		my $node = $nodereforder{$ref};
		push(@nodes,$node);
	}
	for (my $i=0;$i<scalar(@nodes);$i++) {
		my $node = $nodes[$i];
		my $subordverb = $node->getAttribute('slem');
		#print STDERR "NODE ref: ".$node->getAttribute('ref')."\tnode lemma: ".$node->getAttribute('slem')."\t";
		my $smi = $node->getAttribute('smi');
		if ($smi =~ /^PR/) {
			#print STDERR "RELPRONOUN\t";
			my $nextverbnode = $nodes[$i+1];
			if($nextverbnode)
			{
				my $nextverb = $nextverbnode->getAttribute('slem');
				my $nextverbform = $nextverbnode->parentNode->getAttribute('verbform');
				if ($nextverbform =~ /^rel/) {
					#print STDERR "OK: relative pronoun before relative verb form\n";
				}
				else {
					#print STDERR "NOK?: verb form $nextverbform after relative pronoun\n";
					#print STDERR "\n***ERROR: verb form $nextverbform after relative pronoun\n";
					#$nextverbnode->parentNode->setAttribute('verbform','rel:');
					#print STDERR "verb form '$nextverbform' of following verb $nextverb set to 'rel:'\n";
				}
			}
			
		}
		elsif ($smi =~ /^CS/) {
			print STDERR "LINKER\n";
		}
		else {
			my $verbform = $node->parentNode->getAttribute('verbform');
			if ($verbform =~ /ambiguous/) {
				print STDERR "\n---AMBIGUOUS ";
				# search left for linker or relative pronoun
				if ($i > 0) {
					my $prevnode = $nodes[$i-1];
					my $prevsmi = $prevnode->getAttribute('smi');
					my $newverbform = "main"; # default?
					if ($prevsmi =~/^CS/) {
						my $linker = $prevnode->getAttribute('slem');
						$newverbform = "MLdisamb";
						#print STDOUT "FOUND an example in sentence $sno\n";
						print STDERR "linked with $linker\n";
						# search main verb left or right of this one
						my $found=0;
						for (my $j=$i-2; $j>=0; $j--) { # left
							my $cand = $nodes[$j];
							if ($cand->parentNode->hasAttribute('verbform')) {
								print STDERR "found candidate main verb left of subordinated verb\n";
								my $candverb = $cand->getAttribute('slem');
								print STDERR "classifiy: $candverb,$subordverb,$linker\n";
								my $class = &predictVerbform($candverb,$subordverb,$linker);
								$newverbform = $mapClassToVerbform{$class};
								$node->parentNode->setAttribute('verbform', "ML1:".$newverbform);
								#$node->parentNode->setAttribute('verbform', $newverbform);
								$found = 1;
								last;
							}
							else {
								print STDERR "WEIRD left $cand ....\n";
							}
						}
						if (not $found) {
							for (my $j=$i+1; $j<scalar(@nodes); $j++) { # search right for the next verb; 
								my $cand = $nodes[$j];
								if ($cand->parentNode->hasAttribute('verbform')) {
									print STDERR "found candidate main verb right of subordinated verb\n";
									if ($nodes[$j-1]->getAttribute('smi') =~ /^CS|^PR/ ) {
										print STDERR "candidate is rather subordinated with ".$nodes[$j-1]->getAttribute('slem')."... continue searching\n";
										next; 
									}
									my $candverb = $cand->getAttribute('slem');
									print STDERR "classifiy: $candverb,$subordverb,$linker\n";
									#print STDOUT "$candverb,$subordverb,$linker\n";
									my $class = &predictVerbform($candverb,$subordverb,$linker);
									$newverbform = $mapClassToVerbform{$class};
									$node->parentNode->setAttribute('verbform', "ML2:".$newverbform);
									#$node->parentNode->setAttribute('verbform', $newverbform);
									$found = 1;
									last;
								}
							}
							# if still no main verb: ML with subord+linker
							if(not $found)
							{
								my $class = &predictVerbform('0',$subordverb,$linker);
								$newverbform = $mapClassToVerbform{$class};
								$node->parentNode->setAttribute('verbform', "ML3:".$newverbform);
								#$node->parentNode->setAttribute('verbform', $newverbform);
								print STDERR "no main verb but linker\n";
								print STDERR "classify: 0,$subordverb,$linker\n";
							}
						
						}
					}
					elsif ($prevsmi =~ /^PR/) {
						print STDERR "relative clause\n";
						$newverbform = "rel:";
						#$node->parentNode->setAttribute('verbform',$newverbform);
						$node->parentNode->setAttribute('verbform',"MLr:".$newverbform);
						print STDERR "verb form of $subordverb set to 'rel:'\n";
					}
					else {
						print STDERR "no linker, not in relative clause, no coordinative conjunction\n";
						my $headverb = $prevnode->getAttribute('slem');
						$newverbform = $prevnode->parentNode->getAttribute('verbform');
						
						print STDERR "verb form of $subordverb set to 'main' (coordination would be $newverbform)\n";
						#$node->parentNode->setAttribute('verbform','main');
						$node->parentNode->setAttribute('verbform',"MLr:".'main')
						
#						print STDERR "verb form passed to ML without linker\n";
#						my $class = &predictVerbform($headverb,$subordverb,'0');
#						$newverbform = $mapClassToVerbform{$class};
#						$node->parentNode->setAttribute('verbform', "ML:".$newverbform);
						
					}
				}
				else {
					print STDERR "no previous verb, no linker, not in relative clause\n";
					print STDERR "verb form of $subordverb set to 'main'\n";
					#$node->parentNode->setAttribute('verbform','main');
					$node->parentNode->setAttribute('verbform',"MLr:".'main')
				}
			}
			else {
				print STDERR "VERB form: $verbform\n";
			}
		}
	}
	
	print STDERR "\n";	# empty line between sentences
}


# print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;

sub predictVerbform{
	my ($head,$subV,$linker) = @_;
	
	my $resultref = $nb->predict
    (attributes => {head => $head, subV => $subV, linker => $linker});

	 my %result = %$resultref;
 	 my @sortedKeys =  sort {$result{$b}<=>$result{$a}} (keys %result) ;
 	 print STDERR "result: $head,$subV,$linker,@sortedKeys[0]\n";
 	 return @sortedKeys[0];
}
