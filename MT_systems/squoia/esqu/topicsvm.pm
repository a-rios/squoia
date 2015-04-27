#!/usr/bin/perl

package squoia::esqu::topicsvm;
use utf8;
#use Storable;    # to retrieve hash from disk
#use open ':utf8';
#binmode STDIN, ':utf8';
#binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
#use XML::LibXML;
use strict;
#use AI::NaiveBayes1;
use Algorithm::SVM;
use Algorithm::SVM::DataSet;

my $verbose = '';

my $path = File::Basename::dirname(File::Spec::Functions::rel2abs($0));
#print STDERR $localpath;

my %mapNsem1ToVec = ( 'abs' => 0, 'ani' => 1, 'bpart' => 2, 'cnc' => 3,'hum' => 4,'nloc' => 5,'mat' => 6,'mea' => 7,'plant' => 8,'pot' => 9,'sem' => 10, 
'soc' => 11,'tmp' => 12,'unit' => 13);


my $modelPath = "$path/models/topic.model";
#print STDERR "modelpath: $modelPath\n";
my $svm =  new Algorithm::SVM(Model => "$modelPath");

# Spanish Resource Grammar lexicon
#my %nounLex   = %{ retrieve("NounLex") };
					my $countsubjs=0;

sub main{
	my $dom = ${$_[0]};
	my %nounLex = %{$_[1]};
	my $verbose = $_[2];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my @sentences = $dom->getElementsByTagName('SENTENCE');

	for(my $i=0;$i<scalar(@sentences);$i++)
	{
			my $sentence = @sentences[$i];
			#print STDERR "SENT $i\n" if $verbose;
			
			unless($sentence->exists('descendant::.[contains(@chunkmi, "+Top") or contains(@addmi, "+Top") or contains(@conjLast, "chayqa") or contains(@conj, "ichaqa")]')){
				# get subjects in finite clauses
				my @subjects= $sentence->findnodes('descendant::CHUNK[@verbform="main"]/CHUNK[@si="suj" or @si="suj-a"]');
				if(scalar(@subjects)> 0){
					#print STDERR "found subject in finite clause in sent $sno: \n";

					foreach my $subj (@subjects){
						#print STDERR "subj chunk candidate for topic in sentence ".($i+1).": \n".$subj->toString()."\n" if $verbose;
						$countsubjs++;
						my @vec = map { 0 } 0..22;
						
						my $es_lem = $subj->findvalue('child::NODE/@slem');
						my $es_pos = $subj->findvalue('child::NODE/@smi');
						my $quz_lem = $subj->findvalue('child::NODE/@lem');
						
						my $nounSem = $nounLex{$es_lem};
						chomp($nounSem);
						my @nounSems = split('_',$nounSem);
			  			foreach my $sem (@nounSems){
							#$nounSemLabels{$sem}= 1;
							@vec[$mapNsem1ToVec{$sem}]=1;
						}
						
						# "NomRoot,VerbRoot,NP,";
				   		my $NomRoot = ($es_pos =~ /^N|^AQ/) ? 1:0;
				   		my $VerbRoot = ($es_pos =~ /^V/) ? 1:0;
				   		my $NP = ($es_pos =~ /^NP/) ? 1:0;
				   		
				   		@vec[14]= $NomRoot;
				   		@vec[15]= $VerbRoot;
				   		@vec[16]= $NP;
				   		
				   		
				   		#is upper case
				   		my $isUpperCase = ($subj->findvalue('child::NODE/@UpCase') ne 'none') ? 1:0;
				   		@vec[17] = $isUpperCase;
				   		
				   		$es_lem = lc($es_lem);
				   		my $xpath = 'descendant::NODE[@slem="'.$es_lem.'"]';
				   		
				   		my $occursinPrevSentence=0;
				   		#my $quz_lem = $subj->findvalue('child::NODE/@lem');
				   		unless($i==1){
						   		#occurs in previous sentence
						   		my $prevSentence = @sentences[$i-1];
						   		$occursinPrevSentence =  $prevSentence->exists($xpath);
						   		#print STDERR "searching for $es_lem in sent: ".$prevSentence->toString()."\n";
						 }
						 @vec[18] = $occursinPrevSentence;
						 
						# is pronoun
						
						my $isPronoun = ($es_pos=~ /^P/) ? 1:0;
						@vec[19]=$isPronoun;   		
				   		
				   		#has det
				   		my $hasDet = ($subj->exists('child::NODE/descendant::NODE[starts-with(@smi,"DA") or starts-with(@smi,"DD") ]') ) ? 1:0;
				   		@vec[20]=$hasDet;
				   		
				   		#occursInNextSentence
				   		my $occursinNextSentence=0;
				   		unless($i == scalar(@sentences)-1){
				   			$occursinNextSentence = ($sentences[$i+1]->exists($xpath) ) ? 1:0;
				   		}
				   		@vec[21]= $occursinNextSentence;
				   		#print "$occursinNextSentence," ;
				   		
				   		
				   		#occursMoreThanOnce
				   		my $occursMoreThanOnce=0;
				   		unless($quz_lem eq 'ka'){
				   			my @sameLemmas = $sentence->findnodes($xpath);
				   			$occursMoreThanOnce = (scalar(@sameLemmas)>1) ? 1:0;
				   		}
				   		@vec[22] = $occursMoreThanOnce;
				   		
				   		
				   		my @feats=  ("abs","ani","bpart","cnc","hum","nloc","mat","mea","plant","pot","sem","soc","tmp","unit","NomRoot","VerbRoot","NP","isUpperCase","occursInPrevSentence","isPronoun","hasDet","occursInNextSentence","occursMoreThanOnce");
				   		if($verbose){
				   			print STDERR "vector for predict of $es_lem in sentence ".($i+1).":\n";
				   			for(my $j=0;$j<scalar(@feats);$j++){
				   				print STDERR @feats[$j]."=".@vec[$j].",";
				   			}
				   			print STDERR "\n";
				   		}
				   		
				   		
				   		## NOTE, need an extra element, because weka inserts a 0 into libsvm file for training at beginning
						unshift(@vec,0);
						my $ds =  new Algorithm::SVM::DataSet(Label => 1, Data => \@vec);						 
						my $svmClass = $svm->predict($ds);
						if($svmClass ==1){
							my $chunkmi = $subj->getAttribute('chunkmi')."+Top";
							$subj->setAttribute('chunkmi',$chunkmi);
							print STDERR "predicted topic for $es_lem, $quz_lem in\n".$subj->toString()."\n" if $verbose;
						}
					}
				}
				
			}
		}
		
	#print STDERR "numberof subjs: $countsubjs\n";
}

1;