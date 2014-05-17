#!/usr/bin/perl 

## IMPORTANT TODO's: 
# - ambiguous lemmas from tagging... generate both forms? 
# - atm: input needs to be 1 sentence per line: 
#   --> for automatic sentence splitting, do we want to use FreeLing or the sentence splitter from the Lingua package?

package squoia::main;
our $path;
use utf8;

BEGIN{

	use File::Spec::Functions qw(rel2abs);
	use File::Basename;
	$path = dirname(rel2abs($0));
	use lib $path.".";

	binmode STDIN, ':encoding(UTF-8)';
	use XML::LibXML;
	use Storable;
	use strict;
	use Getopt::Long;
	
	## general squoia modules
	use squoia::util;
	use squoia::conll2xml;
	use squoia::crf2conll;
	use squoia::insertSemanticTags;
	use squoia::semanticDisamb;
	use squoia::morphDisamb;
	use squoia::prepositionDisamb;
	use squoia::intrachunkTransfer;
	use squoia::interchunkTransfer;
	use squoia::nodesToChunks;
	use squoia::childToSiblingChunk;
	use squoia::recursiveNumberChunks;
	use squoia::interchunkOrder;
	use squoia::linearOrderChunk;
	use squoia::intrachunkOrder;
	#use squoia::esqu::testSVM;

	
	## esqu modules
	use squoia::esqu::disambRelClauses;
	use squoia::esqu::coref;
	use squoia::esqu::disambVerbFormsRules;
	use squoia::esqu::svm;
	use squoia::esqu::xml2morph;
	
	
	## esde modules	
	
}


# variables needed to run the MT system
my %config;

###-----------------------------------begin read commandline arguments -----------------------------------------------####

### get commandline options
# setup options
# general options
my $help = 0;
my $config;
my $infile;
my $nbest = 3;
my $direction;
my $outformat; # default nbest: print nbest translations, other valid options are: tagged (wapiti), parsed (desr), conll2xml, rdisamb, coref, vdisamb, svm, lextrans, morphdisamb, prepdisamb, intraTrans, interTrans, intraOrder, interOrder, morph, words
# options for tagging
my $wapiti;
my $wapitiModel;
my $freelingPort;
my $freelingConf;
my $matxin;
# options for parsing
my $desrPort1;
my $desrPort2;
my $desrModel1;
my $desrModel2;
# options for lexical transfer
my $bidix;
# general options for translation
my $semlex;
my $lexDisamb;
my $morphDisam;
my $prepDisamb;
my $intraTransfer;
my $interTransfer;
my $nodes2chunks;
my $child2sibling;
my $interOrder;
my $intraOrder;
# esqu options
my $nounlex;
my $verblex;
my $evidentiality = "direct";
my $svmtestfile;
my $wordnet;
my $morphgenerator;
my $quModel;
# esde options
my $deModel;

my $helpstring = "Usage: main.pm [options]
available options are:
--help|-h: print this help
--config|-c: indicate config (necessary for first run, later optional)
--infile|-i: infile with text to translate (optional, if no infile given, reads input from stdin)
--direction|-d: translation direction, valid options are esqu (Spanish-Quechua) and esde (Spanish-German)
--outformat|-o: output format, valid formats are:
\t tagged: (wapiti crf)
\t parsed: (conll)
\t conll2xml: (xml created from parsing)
\t rdisamb: (xml disambiguated relative clauses, only with direction esqu)
\t coref: (xml after coreference resolution for subjects, only with direction esqu)
\t vdisamb: (xml disambiguated verb forms, rule-based, only with direction esqu)
\t svm: (xml disambiguated verb forms with libsvm, only with direction esqu)
\t lextrans: (xml after lexical transfer)
\t morphdisamb: (xml after morphological disambiguation)
\t prepdisamb: (xml after preposition disambiguation)
\t intraTrans: (xml after intrachunk syntactic transfer)
\t interTrans: (xml after interchunk syntactic transfer)
\t intraOrder: (xml after intrachunk syntactic ordering)
\t interOrder: (xml after interchunk syntactic ordering)
\t morph: (input for morphological generation)
\t words: (output of morphological generation)
\t nbest: (nbest translation options = default)
Options for tagging:
--wapiti: path to wapiti executables
--wapitiModel: path to wapiti model (for tagging)
--freelingPort: port for squoia_analyzer (morphological analysis)
--freelingConf: path to FreeLing config, only needed if squoia_analyzer should be restartet (morphological analysis)
Options for parsing:
--desrPort1: port for desr_server with model 1
--desrPort2: port for desr_server with model 2
--desrModel1: model 1 for desr_server
--desrModel2: model 2 for desr_server
Options for lexical transfer:
--bidix: bilingual dictionary for lexical transfer
--matxin: path to maxtin executables
Options for translation, general:
--semlex: semantic lexicon (semantic tags will be inserted during translation)
--lexDisamb: lexical disambiguation rules
--morphDisamb: morphological disambiguation rules
--prepDisamb: preposition disambiguation rules
--intraTransfer: intrachunk transfer rules
--interTransfer: interchunk transfer rules
--nodes2chunks: rules to promote nodes to chunks
--child2sibling: rules to promote child to sibling chunks
--interOrder: rules for interchunk reordering
--intraOrder: rules for intrachunk reordering
--nbest|-n: print n-best translations
Options for translation, es-quz:
--evidentiality|-e: basic evidentiality (direct, indirect)
--svmtestfile: test file for svm module (only for debugging)
--nounlex: semantic noun lexicon
--verblex: verbframe lexicon
--wordnet: spanish wordnet (path to mcr30 directory of wordnet)
--morphgenerator: path to morphological generation binary
--quModel: Quechua language model
Options for translation, es-de: TODO
--deModel: German langugage model
\n";

GetOptions(
	# general options
    'help|h'     => \$help,
    'config|c=s'    => \$config,
    'infile|i=s'    => \$infile,
    'direction|d=s' => \$direction,
    'outformat|o=s' => \$outformat,
    # options for tagging
	'wapiti=s'    => \$wapiti,
	'wapitiModel=s'    => \$wapitiModel,
	'freelingPort=i'    => \$freelingPort,
	'freelingConf=i'    => \$freelingConf,
	'matxin=s'    => \$matxin,
	# options for parsing
	'desrPort1=i'	=> \$desrPort1,
	'desrPort2=i'	=> \$desrPort2,
	'desrModel1=s'	=> \$desrModel1,
	'desrModel2=s'	=> \$desrModel2,
	# options for lexical transfer
	'bidix=s'	=> \$bidix,
     # translation options
    'semlex=s' => \$semlex,
    'lexDisamb=s' => \$lexDisamb,
    'morphDisamb=s' => \$morphDisamb,
    'prepDisamb=s' => \$prepDisamb,
    'intraTransfer=s' => \$intraTransfer,
    'interTransfer=s' => \$interTransfer,
    'nodes2chunks=s' => \$nodes2chunks,
    'child2sibling=s' => \$child2sibling,
    'interOrder=s' => \$interOrder,
    'intraOrder=s' => \$intraOrder,
    'nbest|n=i' => \$nbest,
    # options for es-quz
    'evidentiality|e=s'     => \$evidentiality,
    'svmtestfile=s' => \$svmtestfile,
    'nounlex=s' => \$nounlex,
    'verblex=s' => \$verblex,
    'wordnet=s' => \$wordnet,
    'morphgenerator=s' => \$morphgenerator,
    'quModel=s' => \$quModel,
    # TODO options for es-de
    'deModel' => \$deModel
) or die "Incorrect usage!\n $helpstring";

	if($help){ print STDERR $helpstring; exit;}
	if($config ne ''){
		print STDERR "reading config file: $config\n";
		open (CONFIG, "<:encoding(UTF-8)", $config);
		while (<CONFIG>) {
			chomp;       # no newline
			s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next unless length;    # anything left?
			my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );
			if($var ne 'GRAMMAR_DIR' and $var ne 'SQUOIA_DIR'){
				my $grammarPath = $config{'GRAMMAR_DIR'} or die "GRAMMAR_DIR not specified in config!";
				$value =~ s/\$GRAMMAR_DIR/$grammarPath/g;
				my $squoiaPath = $config{'SQUOIA_DIR'} or die "SQUOIA_DIR not specified in config!";
				$value =~ s/\$SQUOIA_DIR/$squoiaPath/g;
		
			}
			#print "$var=$value\n";
			$config{$var} = $value;
		}
		close CONFIG;
		store \%config, "$path/storage/config.bin";
	}
	else{
		# no config given on commandline: retrieve config from disk
		print STDERR "using saved config file $path/storage/config.bin\n";
		eval{
			retrieve("$path/storage/config.bin");
			%config = %{ retrieve("$path/storage/config.bin") };
		
		} or print STDERR "No config file specified and no saved $path/storage/config.bin found, specifiy a config file with -c!\n";
	}
	
	# specify translation direction, valid options are esqu and esde
	if($direction eq ''){
		eval{
			$direction = $config{'direction'};
		} or die "Translation direction not specified, set direction=esqu or direction=esde in config, or use --direction or -d on commandline!\n";
	}
	if($direction !~ /^esqu|esde$/){
		die "Invalid translation direction $direction, valid options are 'esde' or 'esqu'!\n";
	}

	## check if outformat is a valid option, and check if it's set in config, if neither --outformat nor outformat= set in config: set to 'nbest'
	if($outformat eq ''){
		eval{
			$outformat = $config{'outformat'};
		} or $outformat ='nbest';
	}
	if($outformat !~ /^nbest|tagged|parsed|conll2xml|rdisamb|coref|vdisamb|svm|lextrans|morphdisamb|prepdisamb|intraTrans|interTrans|intraOrder|interOrder|morph|words$/){
		die "Invalid output format $outformat, valid options are:
\t tagged: (wapiti crf)
\t parsed: (conll)
\t conll2xml: (xml created from parsing)
\t rdisamb: (xml disambiguated relative clauses, only with direction esqu)
\t coref: (xml after coreference resolution for subjects, only with direction esqu)
\t vdisamb: (xml disambiguated verb forms, rule-based, only with direction esqu)
\t svm: (xml disambiguated verb forms with libsvm, only with direction esqu)
\t lextrans: (xml after lexical transfer)
\t morphdisamb: (xml after morphological disambiguation)
\t prepdisamb: (xml after preposition disambiguation)
\t intraTrans: (xml after intrachunk syntactic transfer)
\t interTrans: (xml after interchunk syntactic transfer)
\t intraOrder: (xml after intrachunk syntactic ordering)
\t interOrder: (xml after interchunk syntactic ordering)
\t morph: (input for morphological generation)
\t words: (output of morphological generation)
\t nbest: (nbest translation options = default)";
	}

		## TODO check if freeling and desr are running on indicated ports (for desr: further below, before parsing starts)
		# #test if squoia_analyzer is already listening
		# set freeling parameters
		if($freelingPort eq ''){
			eval{
				$freelingPort = $config{'freelingPort'};
			} or warn  "no freelingPort given, using default 8844\n";
			if($freelingPort eq ''){
				$freelingPort = 8844; 
			}
		}
		if($freelingConf eq ''){
			eval{
				$freelingConf = $config{'freelingConf'};
			} or die  "Could not start tagging, no freelingConf given\n";
		}
		my $analyzerRunning = `ps ax | grep -v grep | grep "squoia_analyzer.*$freelingConf.*port=$freelingPort"` ;
		if($analyzerRunning eq ''){
			print STDERR "no instance of squoia_analyzer server running on port $freelingPort with config $freelingConf\n";
			print STDERR "starting squoia_analyzer server on port $freelingPort with config $freelingConf...\n";
			system("squoia_analyzer -f $freelingConf --outf=crfmorf --server --port=$freelingPort 2> logcrfmorf &");
			while(`echo "test" | analyzer_client "$freelingPort" 2>/dev/null` eq ''){
				print STDERR "starting squoia_analyzer, please wait...\n";
				sleep 10;
			}
			print STDERR "squoia_analyzer now ready\n";
		}
		
###-----------------------------------end read commandline arguments -----------------------------------------------####

###-----------------------------------begin analysis Spanish input -----------------------------------------------####
### tagging: if input file given with --infile or -i:
# check if $matxin,  $wapiti and $wapitiModel are all set, otherwise exit
if($matxin eq '' or $wapiti eq '' or $wapitiModel eq ''){
	eval{
		$matxin = $config{'matxin'}; $wapiti = $config{'wapiti'}; $wapitiModel = $config{'wapitiModel'};
	}
	or die "Tagging failed, location of matxin, wapiti or wapiti model not indicated!\n";;
}
if($infile ne ''){
			open(CONLL,"-|" ,"cat $infile | $matxin/analyzer_client $freelingPort | $wapiti/wapiti label --force -m $wapitiModel"  ) || die "tagging failed: $!\n";
	}
	# if no infile given, expect input on stdin
	else{
		# solution without open2, use tmp file
		my $tmp = $path."/tmp/tmp.txt";
		open (TMP, ">:encoding(UTF-8)", $tmp);
		while(<>){print TMP $_;}
		open(CONLL,"-|" ,"cat $tmp | $matxin/analyzer_client $freelingPort | $wapiti/wapiti label --force -m $wapitiModel"  ) || die "tagging failed: $!\n";
		close(TMP);
}
## if output format is 'crf': print and exit
if($outformat eq 'tagged'){
	while(<CONLL>){print;}
	close(CONLL);
	exit;
}

#### convert to wapiti crf to conll for desr parser
my $conllLines = squoia::crf2conll::main(\*CONLL);

	#### Check if parser servers are already running (2 instances with different models)
	# first instance
	# set desr parameters
		if($desrPort1 eq ''){
			eval{
				$desrPort1 = $config{'desrPort1'};
			} or warn  "no desrPort1 given, using default 5678\n";
			if($desrPort1 eq ''){
				$desrPort1 = 5678; 
			}
		}
		if($desrModel1 eq ''){
			eval{
				$desrModel1 = $config{'desrModel1'};
			} or die  "Could not start parsing, no desrModel1 given\n";
		}
		my $desr1Running = `ps ax | grep -v grep | grep "desr_server.*$desrModel1.*--port $desrPort1"` ;
		if($desr1Running eq ''){
			print STDERR "no instance of desr_server running on port $desrPort1 with model $desrModel1\n";
			print STDERR "starting desr_server on port $desrPort1 with model $desrModel1...\n";
			system("desr_server -m $desrModel1 --port $desrPort1 2> logdesr_1 &");
			print STDERR "desr_server with model 1 = $desrModel1 started on port $desrPort1...\n";
			sleep 1;
		}
	# same for 2nd instance
		if($desrPort2 eq ''){
			eval{
				$desrPort2 = $config{'desrPort2'};
			} or warn  "no desrPort2 given, using default 1234\n";
			if($desrPort2 eq ''){
				$desrPort2 = 1234; 
			}
		}
		if($desrModel2 eq ''){
			eval{
				$desrModel2 = $config{'desrModel2'};
			} or die  "Could not start parsing, no desrModel2 given\n";
		}
		my $desr2Running = `ps ax | grep -v grep | grep "desr_server.*$desrModel2.*--port $desrPort2"` ;
		if($desr2Running eq ''){
			print STDERR "no instance of desr_server running on port $desrPort2 with model $desrModel2\n";
			print STDERR "starting desr_server on port $desrPort2 with model $desrModel2...\n";
			system("desr_server -m $desrModel2 --port $desrPort2 2> logdesr_2 &");
			print STDERR "desr_server with model 2 = $desrModel2 started on port $desrPort2...\n";
			sleep 1;
		}

### parse tagged text:
my $tmp2 = $path."/tmp/tmp.conll";
		# !! not again ">:encoding(UTF-8)", results in 'doble' encoded strings!!
		open (TMP2, ">", $tmp2);
		foreach my $l (@$conllLines){print TMP2 $l;}
		open(CONLL2,"-|" ,"cat $tmp2 | desr_client $desrPort1"  ) || die "parsing failed: $!\n";
		close(TMP2);

## if output format is 'conll': print and exit
if($outformat eq 'parsed'){
	while(<CONLL2>){print;}
	close(CONLL2);
	exit;
}
#### create xml from conll
my $dom = squoia::conll2xml::main(\*CONLL2, $desrPort2);
close(CONLL2);

## if output format is 'conll2xml': print and exit
if($outformat eq 'conll2xml'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

####-----------------------------------end analysis Spanish input -----------------------------------------------####


####-----------------------------------begin preprocessing for es-qu -----------------------------------------------####
#
#### verb disambiguation
if($direction eq 'esqu')
{
	# retrieve semantic verb and noun lexica for verb disambiguation
	my %nounLex = (); my %verbLex = ();
	if($nounlex ne ''){
		open (NOUNS, "<:encoding(UTF-8)", $nounlex) or die "Can't open $nounlex : $!";
		print STDERR "reading semantic noun lexicon form $nounlex...\n";
		while(<NOUNS>){
		s/#.*//;     # no comments
		(my $lemma, my $semTag) = split(/:/,$_);
		$nounLex{$lemma} = $semTag;
		}
		store \%nounLex, "$path/storage/NounLex";
		close(NOUNS);
	}
	else{
		## retrieve from disk
		eval {
			my $hashref = Storable::retrieve("$path/storage/NounLex");
		} or die "No NounLex in $path/storage found! specify --nounlex=path to read in the Spanish noun lexicon!";
		%nounLex = %{ Storable::retrieve("$path/storage/NounLex") };
	}
	if($verblex ne ''){
		open VERBS, "< $verblex" or die "Can't open $verblex : $!";
		print STDERR "reading verb frame lexicon form $verblex...\n";
		my $verbdom    = XML::LibXML->load_xml( IO => *VERBS );
		my @lexEntriesList = $dom->getElementsByTagName('lexentry');
		foreach my $lexentry (@lexEntriesList)
		{
			my $lemma = $lexentry->getAttribute('lemma');
			my @frames = $lexentry->findnodes('descendant::frame');
			my @types = ();
			foreach my $frame (@frames)
			{
				#get old_type (subcategorization classes of frames)
				my $lss = $frame->getAttribute('lss');
				my $type = $frame->getAttribute('type');
				my $thematicRoleOfSubj = $frame->findvalue('child::argument[@function="suj"]/@thematicrole');
		
				# save frame as combination of lss (lexical semantic structure) & type (diathesis)
				my $lsstype = "$lss#$type##$thematicRoleOfSubj";
				if (!grep {$_ eq $lsstype} @types && $type ne 'resultative'){
						push(@types,$lsstype);
				}
			}
		$verbLex{$lemma} = \@types;
		}
		store \%verbLex, "$path/storage/VerbLex";
		close(VERBS);
	}
	else{
		## retrieve from disk
		eval {
			my $hashref = Storable::retrieve("$path/storage/VerbLex");
		} or die "No VerbLex in $path/storage found! specify --verblex=path to read in the Spanish verb frame lexicon! ";
		%verbLex   = %{ Storable::retrieve("$path/storage/VerbLex") };	
	}

squoia::esqu::disambRelClauses::main(\$dom, \%nounLex, \%verbLex);

## if output format is 'rdisamb': print and exit
if($outformat eq 'rdisamb'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

squoia::esqu::coref::main(\$dom);

## if output format is 'coref': print and exit
if($outformat eq 'coref'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

	# check if evidentiality set
	if($evidentiality ne 'direct' or $evidentiality eq 'indirect'){
		print STDERR "Invalid value  '$evidentiality' for option --evidentiality, possible values are 'direct' or 'indirect'. Using default (=direct)\n";
		$evidentiality = 'direct';
	}
squoia::esqu::disambVerbFormsRules::main(\$dom, $evidentiality, \%nounLex);

## if output format is 'vdisamb': print and exit
if($outformat eq 'vdisamb'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

	# get verb lemma classes from word net for disambiguation with svm
	my %verbLemClasses=();
	
	if($wordnet ne ''){
		my $spa2ilimap = "$wordnet/spaWN/wei_spa-30_to_ili.tsv";
		my $ilirecord = "$wordnet/data/wei_ili_record.tsv";
		my $variant = "$wordnet/spaWN/wei_spa-30_variant.tsv";
		open (SPA2ILI, "<:encoding(UTF-8)", $spa2ilimap) or die "Can't open $spa2ilimap : $!";
		open (ILIREC, "<:encoding(UTF-8)", $ilirecord) or die "Can't open $ilirecord : $!";
		open (VARIANT,  "<:encoding(UTF-8)", $variant) or die "Can't open $variant : $!";
	
		my %VerbSem; my %synsets; my %spa2ili; my %ilirecs;
		while(<SPA2ILI>){
		    my ($ili,$pos,$spa,$rest) = split('\t');
		    if($pos eq 'v'){
				$spa2ili{$spa} = $ili;
		    }
		}
		while(<ILIREC>){
		    my ($ili,$pos,$bla,$bli,$class,$rest) = split('\t');
		    if($pos eq 'v'){
				$ilirecs{$ili} = $class;
				#print "$ili : $class\n";
		    }
		}
		while(<VARIANT>){
		    unless( /^\s*$/ ){ 
				chomp;
				my ($lem,$n,$synset,$pos,$rest) = split('\t');
				$lem =~ s/se$//;
				
				if($pos eq 'v'){
				    unless( grep {$_ =~ /\Q$synset\E/} @{$VerbSem{$lem}} ){
						push(@{$VerbSem{$lem}},$synset);
					}
					$synsets{$synset}=1;
				}
	  	  	}
		}
	
		# get classes for each verb
		foreach my $lem (keys %VerbSem){
		      foreach my $spa (@{${VerbSem}{$lem}}){
		            my $ili = $spa2ili{$spa};
		            my $class = $ilirecs{$ili};
		            if( $verbLemClasses{$lem}{$class} > 0 ){
						$verbLemClasses{$lem}{$class}++;
		   			}
		    		else{
						$verbLemClasses{$lem}{$class} = 1;
		    		}
	      		}
		}
		# verbs: 15 classes, 29-43
		store \%verbLemClasses, "$path/storage/verbLemClasses";	
	}
	else{
		## retrieve verb lemma classes from word net from disk
		eval {
			my $hashref = Storable::retrieve("$path/storage/verbLemClasses");
		} or die "No VerbLemClasses in $path/storage found! specify --wordnet to read in the Spanish verb synsets from wordnet (indicate path to mcr30). ";
		%verbLemClasses =  %{ retrieve("$path/storage/verbLemClasses") };
	}

squoia::esqu::svm::main(\$dom, \%verbLex, \%verbLemClasses);

## if output format is 'svm': print and exit
if($outformat eq 'svm'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}
## test svm module
#    if($options{'t'}){
#    	squoia::esqu::testSVM::main($options{'t'});
#    }
#
}
####-----------------------------------end preprocessing for es-qu -----------------------------------------------####


####-----------------------------------begin translation ---------------------------------------------------------####
#### lexical transfer with matxin-xfer-lex
## check if $bidix is set
if($bidix eq ''){
	eval{
		$bidix = $config{'bidix'};
	}
	or die "Lexical transfer failed, location of bilingual dictionary not indicated (set option bidix in confix or use --bidix on commandline)!\n";
}
my $tmp3 = $path."/tmp/tmp.xml";
		# !! not again ">:encoding(UTF-8)", results in 'doble' encoded strings!!
		open (TMP3, ">", $tmp3);
		my $docstring = $dom->toString(1);
		print TMP3 $docstring;
		open(XFER,"-|" ,"cat $tmp3 | $matxin/matxin-xfer-lex $bidix"  ) || die "lexical transfer failed: $!\n";
		close(TMP3);

$dom = XML::LibXML->load_xml( IO => *XFER );
close(XFER);

## if output format is 'lextrans': print and exit
if($outformat eq 'lextrans'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

#### insert semantic tags: 
## if semantic dictionary or new config file given on commandline: read into %semanticLexicone
	my %semanticLexicon =();
	my $readrules=0;
	if($semlex ne ''){
		$readrules =1;
		print STDERR "reading semantic lexicon from $semlex\n";
		open (SEMFILE, "<:encoding(UTF-8)", $semlex) or die "Can't open $semlex : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$semlex= $config{"SemLex"} or die "Semantic dictionary not specified in config, insert SemLex='path to semantic lexicon' or use option --semlex!";
		print STDERR "reading semantic lexicon from file specified in $config: $semlex\n";
		open (SEMFILE, "<:encoding(UTF-8)", $semlex) or die "Can't open $semlex as specified in config: $!";
	}
	if($readrules){
		## read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while(<SEMFILE>){
			 	chomp;
			 	s/#.*//;     # no comments
				s/^\s+//;    # no leading white
				s/\s+$//;    # no trailing white
				my ($lemma, $semTag ,$condition ) = split( /\s*\t+\s*/, $_, 3 );
				my @value = ($semTag, $condition);
				$semanticLexicon{$lemma} = \@value;
			}
			store \%semanticLexicon, "$path/storage/SemLex";
	}
	else{
		## if neither --semlex nor --config given: check if semantic dictionary is already available in storage
		eval{
			retrieve("$path/storage/SemLex");
		} or print STDERR "Failed to retrieve semantic lexicon, set option SemLex=path in config or use --semlex on commandline to indicate semantic lexicon!\n";
		%semanticLexicon = %{ retrieve("$path/storage/SemLex") };
	}
	
squoia::insertSemanticTags::main(\$dom, \%semanticLexicon);

### lexical disambiguation, rule-based
	my %lexSel =();
	$readrules=0;
	
	if($lexDisamb ne ''){
		$readrules =1;
		print STDERR "reading lexical disambiguation rules from $lexDisamb\n";
		open (LEXFILE, "<:encoding(UTF-8)", $lexDisamb) or die "Can't open $lexDisamb : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$lexDisamb = $config{"LexSelFile"} or die "Lexical selection file not specified in config, insert LexSelFile='path to lexical disambiguation rules' or use option --lexDisamb!";
		print STDERR "reading lexical selection rules from file specified in $config: $lexDisamb\n";
		open (LEXFILE, "<:encoding(UTF-8)", $lexDisamb) or die "Can't open $lexDisamb as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<LEXFILE>) {
			chomp;
			s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ( $srclem, $trgtlem, $keepOrDelete, $condition ) = split( /\s*\t+\s*/, $_, 4 );
			$condition =~ s/\s//g;	# no whitespace within condition
			# assure key is unique, use srclemma:trgtlemma as key
			my $key = "$srclem:$trgtlem";  
			my @value = ( $condition, $keepOrDelete );
			$lexSel{$key} = \@value;
		}
		store \%lexSel, "$path/storage/LexSelRules";
		close(LEXFILE);
	}
	else{
		## if neither --lexDisamb nor --config given: check if semantic dictionary is already available in storage
		eval{
			retrieve("$path/storage/LexSelRules");
		} or print STDERR "Failed to retrieve lexical selection rules, set option LexSelFile=path in config or use --lexDisamb path on commandline to indicate lexical selection rules!\n";
		%lexSel = %{ retrieve("$path/storage/LexSelRules") };
	}
	
squoia::semanticDisamb::main(\$dom, \%lexSel);

### morphological disambiguation, rule-based
	my %morphSel = ();
	$readrules=0;
	
	if($morphDisamb ne ''){
		$readrules =1;
		print STDERR "reading morphological disambiguation rules from $morphDisamb\n";
		open (MORPHFILE, "<:encoding(UTF-8)", $morphDisamb) or die "Can't open $morphDisamb : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$morphDisamb = $config{"MorphSelFile"} or die "Morphological selection file not specified in config, insert MorphSelFile='path to morphological disambiguation rules' or use option --morphDisamb!";
		print STDERR "reading morphological selection rules from file specified in $config: $morphDisamb\n";
		open (MORPHFILE, "<:encoding(UTF-8)", $morphDisamb) or die "Can't open $morphDisamb as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<MORPHFILE>) {
			chomp;
			s/^(\s)*#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ( $srcNodeConds, $trgtMI, $keepOrDelete, $conditions, $prob ) = split( /\s*\t+\s*/, $_, 5 );
		
			$conditions =~ s/\s//g;	# no whitespace within condition
			# assure key is unique, use srcConds:trgts as key
			my $key = "$srcNodeConds---$trgtMI";
			#print STDERR "key: $key\n";
			my @value = ( $conditions, $keepOrDelete, $prob );
			$morphSel{$key} = \@value;
		}
		store \%morphSel, "$path/storage/MorphSelRules";
		close(MORPHFILE);
	}
	else{
		## if neither --morphDisamb nor --config given: check if lexical disambiguaiton rules are already available in storage
		eval{
			retrieve("$path/storage/MorphSelRules");
		} or print STDERR "Failed to retrieve morphological selection rules, set option MorphSelFile=path in config or use --morphDisamb path on commandline to indicate morphological selection rules!\n";
		%morphSel = %{ retrieve("$path/storage/MorphSelRules") };
	}

squoia::morphDisamb::main(\$dom, \%morphSel);

## if output format is 'morphdisamb': print and exit
if($outformat eq 'morphdisamb'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

### preposition disambiguation, rule-based
	my %prepSel = ();
	$readrules =0;

	if($prepDisamb ne ''){
		$readrules =1;
		print STDERR "reading preposition disambiguation rules from $prepDisamb\n";
		open (PREPFILE, "<:encoding(UTF-8)", $prepDisamb) or die "Can't open $prepDisamb: $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$prepDisamb = $config{"PrepFile"} or die "Preposition disambiguation file not specified in config, insert PrepFile='path to preposition disambiguation rules' or use option --prepDisamb!";
		print STDERR "reading preposition disambiguation rules from file specified in $config: $prepDisamb\n";
		open (PREPFILE, "<:encoding(UTF-8)", $prepDisamb) or die "Can't open $prepDisamb as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<PREPFILE>) {
			chomp;
			s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ( $srcprep, $trgtprep, $condition, $isDefault ) = split( /\s*\t+\s*/, $_, 4 );
			#print STDERR "src: $srcprep, target: $trgtprep, cond:$condition, default: $isDefault\n";
			
			# read into hash, key is srcprep, for each key define a two-dimensional array of
			# translations, whose element are arrays of the values read in from the prep file
			my @value = ($trgtprep, $condition, $isDefault );
			if (!exists( $prepSel{$srcprep} )){
				my @translations=();
				push(@translations,\@value);	
				$prepSel{$srcprep} = \@translations;
			}
			else{
				push(@{ $prepSel{$srcprep} },\@value);	
			}
		}
		store \%prepSel, "$path/storage/PrepSelRules";
		close(PREPFILE);
	}
	else{
		## if neither --prepDisamb nor --config given: check if preposition disambiguation rules are already available in storage
		eval{
			retrieve("$path/storage/PrepSelRules");
		} or print STDERR "Failed to retrieve preposition selection rules, set option PrepFile=path in config or use --prepDisamb path on commandline to indicate preposition disambiguation rules!\n";
		%prepSel = %{ retrieve("$path/storage/PrepSelRules") };
	}
squoia::prepositionDisamb::main(\$dom, \%prepSel);

## if output format is 'prepdisamb': print and exit
if($outformat eq 'prepdisamb'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

### syntactic transfer, intra-chunks (from nodes to chunks and vice versa)
	my %intraConditions = ();
	$readrules =0;
	
	if($intraTransfer ne ''){
		$readrules =1;
		print STDERR "reading syntactic intrachunk transfer rules from $intraTransfer\n";
		open (INTRAFILE, "<:encoding(UTF-8)", $intraTransfer) or die "Can't open $intraTransfer : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$intraTransfer = $config{"IntraTransferFile"} or die "Syntactic intrachunk transfer rules file not specified in config, insert IntraTransferFile='path to syntactic intrachunk transfer rules' or use option --intraTransfer!";
		print STDERR "reading syntactic intrachunk transfer rules from file specified in $config: $intraTransfer\n";
		open (INTRAFILE, "<:encoding(UTF-8)", $intraTransfer) or die "Can't open $intraTransfer as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<INTRAFILE>) {
			#read syntactic transfer information from file into an array with intra chunk conditions
		 	chomp;
		 	s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;   # skip if empty line
			my ($descCond, $descAttr ,$ancCond, $ancAttr, $direction, $wmode ) = split( /\s*\t\s*/, $_, 6 );
		#	print STDERR "descendant condition: $descCond; descendant attribute: $descAttr;\nancestor condition: $ancCond; ancestor attribute: $ancAttr;\ndir: $direction; mode: $wmode\n\n";
			$descCond =~ s/\s//g;
			$ancCond =~ s/\s//g;
			my $condKey = "$descCond\t$ancCond";
			$intraConditions{$condKey} = $descAttr."\t".$ancAttr."\t".$direction."\t".$wmode;
		}
		store \%intraConditions, "$path/storage/IntraTransferRules";
		close(INTRAFILE);
	}
	else{
		## if neither --intraTransfer nor --config given: check if syntactic intrachunk transfer rules are already available in storage
		eval{
			retrieve("$path/storage/IntraTransferRules");
		} or print STDERR "Failed to retrieve syntactic intrachunk transfer rules, set option IntraTransferFile=path in config or use --intraTransfer path on commandline to indicate syntactic intrachunk transfer rules!\n";
		%intraConditions = %{ retrieve("$path/storage/IntraTransferRules") };
	}
	
squoia::intrachunkTransfer::main(\$dom, \%intraConditions);

## if output format is 'intraTrans': print and exit
if($outformat eq 'intraTrans'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

### syntactic transfer, inter-chunks (move/copy information between chunks)
	my %interConditions =();
	$readrules =0;
	
	if($interTransfer ne ''){
		$readrules =1;
		print STDERR "reading syntactic interchunk transfer rules from $interTransfer\n";
		open (INTERFILE, "<:encoding(UTF-8)", $interTransfer) or die "Can't open $interTransfer : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$interTransfer = $config{"InterTransferFile"} or die "Syntactic interchunk transfer rules file not specified in config, insert InterTransferFile='path to syntactic interchunk transfer rules' or use option --interTransfer!";
		print STDERR "reading syntactic interchunk transfer rules from file specified in $config: $interTransfer\n";
		open (INTERFILE, "<:encoding(UTF-8)", $interTransfer) or die "Can't open $interTransfer as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<INTERFILE>) {
			chomp;
		 	s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;   # skip if empty line
			my ($chunk1Cond, $chunk1Attr ,$chunk2Cond, $chunk2Attr, $path1to2, $direction, $wmode ) = split( /\s*\t\s*/, $_, 7 );
			#print STDERR "chunk1 condition: $chunk1Cond; attribute: $chunk1Attr;\nchunk2 condition: $chunk2Cond; attribute: $chunk2Attr; path: $path1to2;\ndir: $direction; mode: $wmode\n\n";
			$chunk1Cond =~ s/\s//g;
			$chunk2Cond =~ s/\s//g;
			my $condKey = "$chunk1Cond\t$chunk2Cond\t$path1to2";
			$interConditions{$condKey} = $chunk1Attr."\t".$chunk2Attr."\t".$direction."\t".$wmode;
		}
		store \%interConditions, "$path/storage/InterTransferRules";
		close(INTERFILE);
	}
	else{
		## if neither --interTransfer nor --config given: check if syntactic interchunk transfer rules are already available in storage
		eval{
			retrieve("$path/storage/InterTransferRules");
		} or print STDERR "Failed to retrieve syntactic interchunk transfer rules, set option InterTransferFile=path in config or use --interTransfer path on commandline to indicate syntactic interchunk transfer rules!\n";
		%interConditions = %{ retrieve("$path/storage/InterTransferRules") };
	}
	
squoia::interchunkTransfer::main(\$dom, \%interConditions);

## if output format is 'interTrans': print and exit
if($outformat eq 'interTrans'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

### promote nodes to chunks, if necessary
	my %targetAttributes;
	my %sourceAttributes;
	my @nodes2chunksRules;
	$readrules =0;
	
	if($nodes2chunks ne ''){
		$readrules =1;
		print STDERR "reading node2chunk rules from $nodes2chunks\n";
		open (NODES2CHUNKSFILE, "<:encoding(UTF-8)", $nodes2chunks) or die "Can't open $nodes2chunks : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$nodes2chunks = $config{"NodeChunkFile"} or die "node2chunks rules file not specified in config, insert NodeChunkFile='path to node2chunks rules' or use option --node2chunks!";
		print STDERR "reading node2chunks rules from file specified in $config: $node2chunks\n";
		open (NODES2CHUNKSFILE, "<:encoding(UTF-8)", $nodes2chunks) or die "Can't open $nodes2chunks as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<NODES2CHUNKSFILE>) {
			chomp;
		 	s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ($origNodeCond, $sourceChunkAttrVal, $targetChunkAttrVal ) = split( /\s*\t+\s*/, $_, 3 );
			$targetAttributes{$origNodeCond} = $targetChunkAttrVal;
			$sourceAttributes{$origNodeCond} = $sourceChunkAttrVal;
		}
		@nodes2chunksRules[0]=\%targetAttributes;
		@nodes2chunksRules[1]=\%sourceAttributes;
		store \@nodes2chunksRules, "$path/storage/nodes2chunksRules";
		close(NODES2CHUNKSFILE);
	}
	else{
		## if neither --node2chunks nor --config given: check if node2chunks rules are already available in storage
		eval{
			retrieve("$path/storage/nodes2chunksRules");
		} or print STDERR "Failed to retrieve node2chunks rules, set option NodeChunkFile=path in config or use --node2chunks path on commandline to indicate node2chunks rules!\n";
		@nodes2chunksRules = @{ retrieve("$path/storage/nodes2chunksRules") };
	}
	
squoia::nodesToChunks::main(\$dom, \@nodes2chunksRules);

### rules to promote child chunks to siblings (necessary for ordering Quechua internally headed relative clauses)
	my %targetAttributes;
	$readrules =0;
	
	if($child2sibling ne ''){
		$readrules =1;
		print STDERR "reading child2sibling rules from $child2sibling\n";
		open (CHILD2SIBLINGFILE, "<:encoding(UTF-8)", $child2sibling) or die "Can't open $child2sibling : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$child2sibling= $config{"ChildToSiblingFile"} or die "child2sibling rules file not specified in config, insert NodeChunkFile='path to child2sibling rules' or use option --child2sibling!";
		print STDERR "reading child2sibling rules from file specified in $config: $child2sibling\n";
		open (CHILD2SIBLINGFILE, "<:encoding(UTF-8)", $child2sibling) or die "Can't open $child2sibling as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<CHILD2SIBLINGFILE>) {
			chomp;
		 	s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ($childChunkCond, $targetChunkAttrVal ) = split( /\s*\t+\s*/, $_, 2 );
			$targetAttributes{$childChunkCond} = $targetChunkAttrVal;			
		}
		store \%targetAttributes, "$path/storage/child2siblingRules";
		close(CHILD2SIBLINGFILE);
	}
	else{
		## if neither --child2sibling nor --config given: check if child2sibling rules are already available in storage
		eval{
			retrieve("$path/storage/child2siblingRules");
		} or print STDERR "Failed to retrieve child2sibling rules, set option ChildToSiblingFile=path in config or use --child2sibling path on commandline to indicate child2sibling rules!\n";
		%targetAttributes = %{ retrieve("$path/storage/child2siblingRules") };
	}
	
squoia::childToSiblingChunk::main(\$dom, \%targetAttributes);

### number chunks recursively
squoia::recursiveNumberChunks::main(\$dom);

### order chunks relative to each other (interchunk ordering)
	my %interOrderRules = ();
	$readrules=0;
	
	if($interOrder ne ''){
		$readrules =1;
		print STDERR "reading interchunk order rules from $interOrder\n";
		open (INTERORDERFILE, "<:encoding(UTF-8)", $interOrder) or die "Can't open $interOrder : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$interOrder= $config{"ChunkOrderFile"} or die "interchunk order rules file not specified in config, insert ChunkOrderFile='path to interchunk order rules' or use option --interOrder!";
		print STDERR "reading interchunk order rules from file specified in $config: $interOrder\n";
		open (INTERORDERFILE, "<:encoding(UTF-8)", $interOrder) or die "Can't open $interOrder as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<INTERORDERFILE>) {
				chomp;
				s/#.*//;     # no comments
				s/^\s+//;    # no leading white
				s/\s+$//;    # no trailing white
				next if /^$/;	# skip if empty line
				my ($parentchunk, $childchunks, $order ) = split( /\s*\t+\s*/, $_, 3 );
				# split childchunks into array and remove empty fields resulted from split
				$childchunks =~ s/(xpath{[^}]+),([^}]+})/\1XPATHCOMMA\2/g;	#replace comma within xpath with special string so it will not get split
				my @childsWithEmptyFields = split( /\s*,\s*/, $childchunks);
				foreach my $ch (@childsWithEmptyFields) {
					$ch =~ s/XPATHCOMMA/,/g;	#replace comma back
				}
				my @childs = grep {$_} @childsWithEmptyFields; 
				
				# fill hash, key is head condition(s)
				my @value = ( \@childs, $order);
				$interOrderRules{$parentchunk} = \@value;
		}
		store \%interOrderRules, "$path/storage/interchunkOrderRules";
		close(INTERORDERFILE);
	}
	else{
		## if neither --interOrder nor --config given: check if interchunk order rules are already available in storage
		eval{
			retrieve("$path/storage/interchunkOrderRules");
		} or print STDERR "Failed to retrieve interchunk order rules, set option ChunkOrderFile=path in config or use --interOrder path on commandline to indicate interchunk order rules!\n";
		%interOrderRules = %{ retrieve("$path/storage/interchunkOrderRules") };
	}
	
squoia::interchunkOrder::main(\$dom, \%interOrderRules);

## if output format is 'interOrder': print and exit
if($outformat eq 'interOrder'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

## linear odering of chunks
squoia::linearOrderChunk::main(\$dom);

## ordering of nodes in chunks (intrachunk order)
my %intraOrderRules = ();
	$readrules=0;
	
	if($intraOrder ne ''){
		$readrules =1;
		print STDERR "reading intrachunk order rules from $intraOrder\n";
		open (INTRAORDERFILE, "<:encoding(UTF-8)", $intraOrder) or die "Can't open $intraOrder : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$intraOrder= $config{"NodeOrderFile"} or die "intrachunk order rules file not specified in config, insert NodeOrderFile='path to intrachunk order rules' or use option --intraOrder!";
		print STDERR "reading intrachunk order rules from file specified in $config: $intraOrder\n";
		open (INTRAORDERFILE, "<:encoding(UTF-8)", $intraOrder) or die "Can't open $intraOrder as specified in config: $!";
	}
	if($readrules){
		#read semantic information from file into a hash (lemma, semantic Tag,  condition)
		while (<INTRAORDERFILE>) {
			chomp;
			s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ($head, $childnodes, $order ) = split( /\s*\t+\s*/, $_, 3 );
		
			$head =~ s/\s//g;	# no whitespace within condition
			$childnodes =~ s/\s//g;	# no whitespace within condition
		
			# split childnodes into array and remove empty fields resulted from split
			my @childsWithEmptyFields = split( ',', $childnodes);
			my @childs = grep {$_} @childsWithEmptyFields; 
			
			#print STDERR @childs[0];
			# fill hash, key is head condition(s)
			my @value = ( \@childs, $order);
			$intraOrderRules{$head} = \@value;
		}
		store \%intraOrderRules, "$path/storage/intrachunkOrderRules";
		close(INTRAORDERFILE);
	}
	else{
		## if neither --intraOrder nor --config given: check if intrachunk order rules are already available in storage
		eval{
			retrieve("$path/storage/intrachunkOrderRules");
		} or print STDERR "Failed to retrieve intrachunk order rules, set option NodeOrderFile=path in config or use --intraOrder path on commandline to indicate intrachunk order rules!\n";
		%intraOrderRules = %{ retrieve("$path/storage/intrachunkOrderRules") };
	}
	
squoia::intrachunkOrder::main(\$dom, \%intraOrderRules);

## if output format is 'intraOrder': print and exit
if($outformat eq 'intraOrder'){
	my $docstring = $dom->toString(3);
	print STDOUT $docstring;
	exit;
}

###-----------------------------------end translation ---------------------------------------------------------####

###-----------------------------------begin morphological generation ---------------------------------------------------------####
## quz
my $sentFile;
if($direction eq 'esqu')
{
	### esqu: get morph tags from xml, use
	my $morphfile = "$path/tmp/tmp.morph";
	squoia::esqu::xml2morph::main(\$dom, $morphfile);
	
	## if output format is 'morph': print and exit
	if($outformat eq 'morph'){
		system("cat $morphfile");
		exit;
	}
	
	## generate word forms with xfst
	## check if $morphgenerator is set
	if($morphgenerator eq ''){
		eval{
			$morphgenerator = $config{'morphgenerator'};
		}
		or die "Morphological generation failed, location of xfst generator not indicated (set option morphgenerator in confix or use --morphgenerator on commandline)!\n";
	}
			open(XFST,"-|" ,"cat $morphfile | lookup -flags xcKv29TT $morphgenerator "  ) || die "morphological generation failed: $!\n";		
			$sentFile = "$path/tmp/tmp.words";
			open (SENT, ">:encoding(UTF-8)", $sentFile);
			binmode(XFST, ':utf8');
			while(<XFST>){
				print SENT $_;
			}
			close(XFST);
			
		## if output format is 'words': print and exit
		if($outformat eq 'words'){
			system("cat $sentFile");
			exit;
		}
}
## de
elsif($direction eq 'esde'){
	
}


###-----------------------------------end morphological generation ---------------------------------------------------------####


###-----------------------------------begin ranking (kenlm) ---------------------------------------------------------####
## use kenlm to print the n-best ($nbest) translations	
if($direction eq 'esqu')
{
	# check if quModel is set
	if($quModel eq ''){
		eval{
			$quModel = $config{'quModel'};
		}
		or die "Ranking failed, location of quechua language model not indicated (set option quModel in confix or use --quModel on commandline)!\n";
	}
	system("$path/squoia/esqu/outputSentences -m $quModel -n $nbest -i $sentFile");
}
## de
elsif($direction eq 'esde'){
	
}

###-----------------------------------end ranking (kenlm) ---------------------------------------------------------####

END{
	## done!! cleanup?
}
