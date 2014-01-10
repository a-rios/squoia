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
#use AI::NaiveBayes1;
use Algorithm::SVM;
use Algorithm::SVM::DataSet;
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

my @length; $length[14] = undef;
my $i =0;
my $j=29;
my %mapSemsToVec =  map { $j++ => $i++; } @length;

my %mapFramesToVec = (
	'A11'	=> 15, 'A12'	=> 16, 'A13'	=> 17, 'A21'	=> 18, 'A22'	=> 19, 'A23'	=> 20, 'A31'	=> 21, 'A32'	=> 22, 'A33'	=> 23, 'A34'	=> 24, 'A35'	=> 25,
	'B11'	=> 26, 'B12'	=> 27, 'B21'	=> 28, 'B22'	=> 29, 'B23'	=> 30,
	'C11'	=> 31, 'C21'	=> 32, 'C31'	=> 33, 'C41'	=> 34, 'B42'	=> 35,
	'D11'	=> 36, 'D21'	=> 37, 'D31'	=> 38
);

my %mapTenseToVec = (
	'S'	=> 39, 'I'	=> 40, 'P'	=> 41, '0'	=> 42, 'C'	=> 43, 'F'	=> 44
);

my %mapModToVec = (
	'I'	=> 45, 'S'	=> 46, 'P'	=> 47, 'N'	=> 48, 'G'	=> 49, 'M'	=> 50
);

# version comoCorr
#my %mapLinkerToVec = (
#	'none'	=> 51, 'que'	=> 52, 'ya_que'	=> 53, 'para_que'	=> 54, 'el_hecho_de_que'	=> 55, 'pues'	=> 56,
#	'como'	=> 57, 'mientras_que'	=> 58, 'después_de_que'	=> 59,  'al_tiempo_que'	=> 60, 'puesto_que'	=> 61, 'si'	=> 62, 
#	'hasta_que'	=> 63, 'mientras'	=> 64,
#	'aunque'	=> 65, 'cuando'	=> 66, 'desde_que'	=> 67, 'porque'	=> 68, 'antes_de_que'	=> 69, 'sin_que'	=> 70, 'y_cuando'	=> 71,
#	'según'	=> 72, 'una_vez_que'	=> 73, 'en_cuanto'	=> 74, 'aun_cuando'	=> 75, 'de_modo_que'	=> 76, 'así_que'	=> 77, 'a_pesar_de_que'	=> 78, 'en_caso_de_que'	=> 79,
#	'si_bien'	=> 80, 'tan_pronto'	=> 81, 'por_eso'	=> 82, 'aún_cuando'	=> 83, 'tal_y_como'	=> 84, 'siempre_y_cuando'	=> 85, 'a_fin_de_que'	=> 86, 'siempre_que'	=> 87,
#	'a_medida_que'	=> 88, 'en_cuanto_que'	=> 89
#	);
#	

# version 4
my %mapLinkerToVec = (
	'none'	=> 51, 'que'	=> 52, 'ya_que'	=> 53, 'para_que'	=> 54, 'el_hecho_de_que'	=> 55, 'pues'	=> 56,
	'como'	=> 57, 'mientras_que'	=> 58, 'después_de_que'	=> 59,  'al_tiempo_que'	=> 60, 'puesto_que'	=> 61, 
	'si'	=> 62, 'hasta_que'	=> 63, 'mientras'	=> 64, 'aunque'	=> 65, 'cuando'	=> 66, 'desde_que'	=> 67, 
	'porque'	=> 68, 'antes_de_que'	=> 69, 'sin_que'	=> 70, 'a_pesar_de_que'	=> 71, 'y_cuando'	=> 72,
	'según'	=> 73, 'una_vez_que'	=> 74, 'en_cuanto'	=> 75, 'debido_a_que'	=> 76, 'dado_que'	=> 77,
	 'de_modo_que'	=> 78, 'así_que'	=> 79,  'en_caso_de_que'	=> 80,
	'si_bien'	=> 81, 'tan_pronto'	=> 82, 'por_eso'	=> 83, 'aún_cuando'	=> 84, 'tal_y_como'	=> 85, 
	'siempre_y_cuando'	=> 86, 'a_fin_de_que'	=> 87, 'siempre_que'	=> 88,
	'a_medida_que'	=> 89, 'en_cuanto_que'	=> 90
	);

# comoCorr
#my %mapUnknownLinkerToKnowns = (
#	'una_vez_que'	=> 'en_cuanto', 'con_tal_que'	=> 'si', 'con_tal_de_que'	=> 'si','conque'	=> 'si', 'si_bien'	=> 'aunque', 'empero'	=> 'pero', 
#	'puesto_que'	=> 'pues', 'dado_que'	=> 'ya_que', 'con_fin_de_que'	=> 'para_que', 'con_objeto_de_que'	=> 'para_que', 
#	'al_tiempo_que'	=> 'mientras_que', 'a_que' => 'para_que', 'debido_a_que' => 'por_eso', 'por_lo_tanto' => 'por_eso'
#);

#version 4
my %mapUnknownLinkerToKnowns = (
	'con_tal_que'	=> 'si', 'con_tal_de_que'	=> 'si','conque'	=> 'si', 'empero'	=> 'pero', 
	'puesto_que'	=> 'pues', 'con_fin_de_que'	=> 'para_que', 'con_objeto_de_que'	=> 'para_que', 
	'al_tiempo_que'	=> 'mientras_que', 'a_que' => 'para_que', 'por_lo_tanto' => 'por_eso'
);
	
## in svm model:
# class 3 = 7 = finite
# class 1 = 3 = obligative
# class 0 = 2 = perfect
# class 2 = 6 = switch
my %mapSVMClassToXmlClass = ( 3.0 => 7, 1.0 => 3, 0.0 => 2, 2.0 => 6);
	
#foreach my $k (keys (%mapSemsToVec)){
#	print STDERR "$k: ".$mapSemsToVec{$k}."\n";
#}

my $verblexPath = "$path/../VerbLex";
my $verbLemPath = "$path/verbLemClasses";
my %verbLexWithFrames   = %{ retrieve($verblexPath) };
my %verbLemClasses =  %{ retrieve($verbLemPath) };

#my $modelPath = "$path/ancoraAndiula_svm.model";
# testing
my $modelPath = "$path/ancoraAndiula_v4_preliminary.model";
#print STDERR "modelpath: $modelPath\n";
my $svm =  new Algorithm::SVM(Model => $modelPath);

my $dom    = XML::LibXML->load_xml( IO => *STDIN );

my $sno;
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{
	$sno = $sentence->getAttribute('ord');
	print STDERR "SENT $sno\n";
	#get all interesting NODES within SENTENCE
	my @sentenceNodes = $sentence->findnodes('descendant::NODE[parent::CHUNK[@verbform] or starts-with(@mi,"PR") or @mi="CS"]'); #head verb, relative pronoun, or subordinating conjunction

	my %nodereforder;
	foreach my $node (@sentenceNodes) {
		my $ref = $node->getAttribute('ord');
		$nodereforder{$ref} = $node;
	}
	my @nodes;
	foreach my $ref (sort { $a <=> $b } keys %nodereforder) {
		my $node = $nodereforder{$ref};
		push(@nodes,$node);
	}
	for (my $i=0;$i<scalar(@nodes);$i++) {
		my $node = $nodes[$i];
		my $subordverb = $node->getAttribute('lem');
		#print STDERR "NODE ref: ".$node->getAttribute('ord')."\tnode lemma: ".$node->getAttribute('lem')."\t";
		my $smi = $node->getAttribute('mi');
		if ($smi =~ /^PR/) {
			#print STDERR "RELPRONOUN\t";
			my $nextverbnode = $nodes[$i+1];
			if($nextverbnode)
			{
				my $nextverb = $nextverbnode->getAttribute('lem');
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
				# before trying to find the main verb and linker: check if this is a passive form
				# (smv cannot classify passives!)
				if($node->getAttribute('mi') =~ /VMP00S[MF]/ && $node->exists('child::NODE[@lem="ser" or NODE[@lem="ser"] ]')){
					$node->parentNode->setAttribute('verbformMLrule', 'passive');
				}
				
				# search left for linker or relative pronoun
				elsif ($i > 0) {
					my $prevnode = $nodes[$i-1];
					my $prevsmi = $prevnode->getAttribute('mi');
					my $newverbform = "main"; # default?
					if ($prevsmi =~/^CS/) 
					{
						my $linker = $prevnode->getAttribute('lem');
						$newverbform = "MLdisamb";
						#print STDOUT "FOUND an example in sentence $sno\n";
						print STDERR "linked with $linker\n";
						# search main verb left or right of this one
						my $found=0;
						for (my $j=$i-2; $j>=0; $j--) { # left
							my $cand = $nodes[$j];
							if ($cand->parentNode->hasAttribute('verbform')) {
								print STDERR "found candidate main verb left of subordinated verb\n";
								my $candverb = $cand->getAttribute('lem');
								print STDERR "classifiy: $candverb,$subordverb,$linker\n";
								my $class = &predictVerbform($candverb,$subordverb,$smi,$linker);
								$newverbform = $mapClassToVerbform{$class};
								#$node->parentNode->setAttribute('verbform', "ML1:".$newverbform);
								$node->parentNode->setAttribute('verbformMLsvm', $newverbform);
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
									if ($nodes[$j-1]->getAttribute('mi') =~ /^CS|^PR/ ) {
										print STDERR "candidate is rather subordinated with ".$nodes[$j-1]->getAttribute('lem')."... continue searching\n";
										next; 
									}
									my $candverb = $cand->getAttribute('lem');
									print STDERR "classifiy: $candverb,$subordverb,$linker\n";
									#print STDOUT "$candverb,$subordverb,$linker\n";
									my $class = &predictVerbform($candverb,$subordverb,$smi,$linker);
									$newverbform = $mapClassToVerbform{$class};
									#$node->parentNode->setAttribute('verbform', "ML2:".$newverbform);
									$node->parentNode->setAttribute('verbformMLsvm', $newverbform);
									$found = 1;
									last;
								}
							}
							# if still no main verb: ML with subord+linker
							if(not $found)
							{
								my $class = &predictVerbform('0',$subordverb,$smi,$linker);
								$newverbform = $mapClassToVerbform{$class};
								#$node->parentNode->setAttribute('verbform', "ML3:".$newverbform);
								$node->parentNode->setAttribute('verbformMLsvm', $newverbform);
								print STDERR "no main verb but linker\n";
								print STDERR "classify: 0,$subordverb,$linker\n";
							}
						
						}
					}
					elsif (($prevsmi =~ /^PR/ && $prevnode->getAttribute('lem') ne 'cuyo' ) or $node->exists('child::NODE[ (starts-with(@mi,"PR") and not(@lem="cuyo"))  or NODE[NODE[starts-with(@mi,"PR") and not(@lem="cuyo") ]] ]')) {
						print STDERR "relative clause\n";
						$newverbform = "rel:";
						$node->parentNode->setAttribute('verbformMLrule',$newverbform);
						#$node->parentNode->setAttribute('verbform',"MLr:".$newverbform);
						print STDERR "verb form of $subordverb set to 'rel:'\n";
						# try to find head noun
						my $headnoun = &getHeadNoun($node->parentNode());
						if($headnoun != -1){
							print STDERR "headnoun is:".$headnoun->toString()."\n";
						}
						else{
							# TODO: scan to the left....? or better leave ambiguous?
							print STDERR "head noun not found\n";
						}
					}
					else {
						print STDERR "no linker, not in relative clause, no coordinative conjunction\n";
						my $headverb = $prevnode->getAttribute('lem');
						$newverbform = $prevnode->parentNode->getAttribute('verbform');
						
						print STDERR "verb form of $subordverb set to 'main' (coordination would be $newverbform)\n";
						$node->parentNode->setAttribute('verbformMLrule','main');
						#$node->parentNode->setAttribute('verbform',"MLr:".'main')
						
#						print STDERR "verb form passed to ML without linker\n";
#						my $class = &predictVerbform($headverb,$subordverb,'0');
#						$newverbform = $mapClassToVerbform{$class};
#						$node->parentNode->setAttribute('verbform', "ML:".$newverbform);
						
					}
				}
				else {
					print STDERR "no previous verb, no linker, not in relative clause\n";
					print STDERR "verb form of $subordverb set to 'main'\n";
					$node->parentNode->setAttribute('verbformMLrule','main');
					#$node->parentNode->setAttribute('verbform',"MLr:".'main')
				}
			}
			else {
				print STDERR "VERB form: $verbform\n";
			}
		}
	}
	
	print STDERR "\n";	# empty line between sentences
}


## print new xml to stdout
my $docstring = $dom->toString;
print STDOUT $docstring;


sub predictVerbform{
	my ($headV,$subV,$smi,$linker) = @_;

	my @vec = map { 0 } 0..90;

	#get semantic class main verb
	if($verbLemClasses{$headV})
	{
			foreach my $class (keys %{$verbLemClasses{$headV}})
			{
				#print STDERR "$headV: $class position:".$mapSemsToVec{$class}."\n";
				@vec[$mapSemsToVec{$class}]=1;
			}
	}

	# get frames main verb
	my $mainFrames = $verbLexWithFrames{$headV};
	if($mainFrames)
	{
			#print "main: $main ";
			foreach my $f (@$mainFrames){
				my ($label) = ($f =~ m/^(.\d\d)/);
				# some errors in Ancora dix! skip those... (e.g. 'dar' has a frame 'a3'?!)
				unless($label eq ''){
					#	print STDERR "$label  $f position: ".$mapFramesToVec{$label}."\n";
						@vec[$mapFramesToVec{$label}]=1;
				}
			}
	}
	
	# get tense subV
	my $tense = substr($smi,3,1);
	my $mod = substr($smi,2,1);
	#print STDERR "mi: $smi, tense: $tense at pos: ".$mapTenseToVec{$tense}." mod: $mod at pos: ".$mapModToVec{$mod}."\n";
	@vec[$mapTenseToVec{$tense}] = 1;
	@vec[$mapModToVec{$tense}] = 1;
	
	# get linker
	if($mapUnknownLinkerToKnowns{$linker}){
		$linker = $mapUnknownLinkerToKnowns{$linker};
		print STDERR "mapped linker to: $linker\n";
	}
	if($mapLinkerToVec{$linker}){
		@vec[$mapLinkerToVec{$linker}] = 1;
		#print STDERR "linker $linker at pos: ".$mapLinkerToVec{$linker}."\n";
	}
	else{
		@vec[$mapLinkerToVec{'none'}] = 1;
		#print STDERR "linker $linker at pos: ".$mapLinkerToVec{'none'}."\n";
	}
	
	
	## NOTE, need an extra element!!
	unshift(@vec,0);
	print STDERR "vec: @vec\n";
	print STDERR "length: ".scalar(@vec)."\n";
	my $ds =  new Algorithm::SVM::DataSet(Label => 1, Data => \@vec);
									 
	my $svmClass = $svm->predict($ds);
	
	print STDERR "predicted $svmClass, in xml: $mapSVMClassToXmlClass{$svmClass}, verb form: $mapClassToVerbform{$mapSVMClassToXmlClass{$svmClass}}\n";
	
	return $mapSVMClassToXmlClass{$svmClass};
#	my  @test  = 	$ds->asArray();						 
#	print STDERR "vec: @test\n"; 
#    my  $result = $svm1->predict($ds);
#	print STDERR "result: $result\n";

	#return 2;
}
