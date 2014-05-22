#!/usr/bin/perl 

## IMPORTANT TODO's: 
# - ambiguous lemmas from tagging... generate both forms? 
# done, changed in matxin-xfer-lex
# - atm: input needs to be 1 sentence per line: 
#   --> for automatic sentence splitting, do we want to use FreeLing or the sentence splitter from the Lingua package?
# -> freeling gseht besser us, erkennt titel...

package squoia::translate;
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
	use squoia::splitNodes;
	use squoia::intrachunkTransfer;
	use squoia::interchunkTransfer;
	use squoia::nodesToChunks;
	use squoia::childToSiblingChunk;
	use squoia::recursiveNumberChunks;
	use squoia::interchunkOrder;
	use squoia::linearOrderChunk;
	use squoia::intrachunkOrder;
	#use squoia::esqu::testSVM;
	use squoia::alternativeSentences;
	
	## esqu modules
	use squoia::esqu::disambRelClauses;
	use squoia::esqu::coref;
	use squoia::esqu::disambVerbFormsRules;
	use squoia::esqu::svm;
	use squoia::esqu::xml2morph;
	
	
	## esde modules	
	use squoia::esde::statBilexDisamb;
	use squoia::esde::verbPrepDisamb;
	use squoia::esde::addPronouns;
	use squoia::esde::addFutureAux;
	use squoia::esde::splitVerbPrefix;
	use squoia::esde::outputGermanMorph;
}


# variables needed to run the MT system
my %config;

###-----------------------------------begin read commandline arguments -----------------------------------------------####

### get commandline options
# setup options
# general options
my $help = 0;
my $config;
my $file;
my $nbest = 3;
my $direction;
my $outformat = 'nbest'; # default nbest: print nbest translations, other valid options are: tagged (wapiti), parsed (desr), conll2xml, rdisamb, coref, vdisamb, svm, lextrans, morphdisamb, prepdisamb, intraTrans, interTrans, intraOrder, interOrder, morph, words
my $informat = 'senttok'; # TODO: default better be plain..?
# options for tagging
my $wapiti;
my $wapitiModel;
my $freelingPort;
my $freelingConf;
my $matxin;
# options for parsing
my $desrPort1;	# TODO set default values here ? my $desrPort1 = 5678;
my $desrPort2;	# my $desrPort2 = 1234;
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
my $chunkMap;	# TODO option for lexical transfer; put together with $bidix ?
my $biLexProb;
my $deLemmaModel;
my $maxalt = 2;	# default maximum 2 lemma alternatives
my $verbPrep;
my $deModel;

my $helpstring = "Usage: $0 [options]
available options are:
--help|-h: print this help
--config|-c: indicate config (necessary for first run, later optional)
--file|-f: file with text to translate (optional, if no file given, reads input from stdin)
--direction|-d: translation direction, valid options are esqu (Spanish-Quechua) and esde (Spanish-German)
--outformat|-o: output format, valid formats are:
\t senttok: plain text, one sentence per line
\t tagged: wapiti crf
\t conll: tagged conll
\t parsed: desr output (conll)
\t conll2xml: xml created from parsing
\t rdisamb: xml disambiguated relative clauses, only with direction esqu
\t coref: xml after coreference resolution for subjects, only with direction esqu
\t vdisamb: xml disambiguated verb forms, rule-based, only with direction esqu
\t svm: xml disambiguated verb forms with libsvm, only with direction esqu
\t lextrans: xml after lexical transfer
\t semtags: xml after insertion of semantic tags
\t lexdisamb: xml after lexical disambiguation (rule-based)
\t morphdisamb: xml after morphological disambiguation
\t statlexdisamb: xml after statistic lexical disambiguation, only with direction esde
\t prepdisamb: xml after preposition disambiguation
\t vprepdisamb: xml after verb preposition disambiguation, only with direction esde
\t mwsplit: xml after multi-word splitting
\t pronoun: xml after inserting subject pronouns, only with direction esde
\t future: xml after inserting future auxiliary, only with direction esde
\t vprefix: xml after verb prefix splitting, only with direction esde
\t intraTrans: xml after intrachunk syntactic transfer
\t interTrans: xml after interchunk syntactic transfer
\t node2chunk: xml after promotion of nodes to chunks
\t node2sibling: xml after promtion of child chunks to siblings
\t intraOrder: xml after intrachunk syntactic ordering
\t interOrder: xml after interchunk syntactic ordering
\t morph: input for morphological generation
\t words: output of morphological generation
\t nbest: nbest translation options = default
--informat|-i: input format, valid formats are: 
\t plain: plain text
\t senttok: plain text, one sentence per line (=default)
\t tagged: wapiti crf
\t conll: tagged conll
\t parsed: desr output (conll)
\t conll2xml: xml created from parsing
\t rdisamb: xml disambiguated relative clauses, only with direction esqu
\t coref: xml after coreference resolution for subjects, only with direction esqu
\t vdisamb: xml disambiguated verb forms, rule-based, only with direction esqu
\t svm: xml disambiguated verb forms with libsvm, only with direction esqu
\t lextrans: xml after lexical transfer
\t semtags: xml after insertion of semantic tags
\t lexdisamb: xml after lexical disambiguation (rule-based)
\t morphdisamb: xml after morphological disambiguation
\t statlexdisamb: xml after statistic lexical disambiguation, only with direction esde
\t prepdisamb: xml after preposition disambiguation
\t vprepdisamb: xml after verb preposition disambiguation, only with direction esde
\t mwsplit: xml after multi-word splitting
\t pronoun: xml after inserting subject pronouns, only with direction esde
\t future: xml after inserting future auxiliary, only with direction esde
\t vprefix: xml after verb prefix splitting, only with direction esde
\t intraTrans: xml after intrachunk syntactic transfer
\t interTrans: xml after interchunk syntactic transfer
\t node2chunk: xml after promotion of nodes to chunks
\t node2sibling: xml after promotion of child chunks to siblings
\t intraOrder: xml after intrachunk syntactic ordering
\t interOrder: xml after interchunk syntactic ordering
\t morph: input for morphological generation
\t words: output of morphological generation
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
Options for translation, es-de:
--chunkMap: mapping of chunk names (for lexical transfer)
--bilexprob: bilingual lexical probabilities (for statistical disambiguation)
--deLemmaModel: German lemma language model
--maxalt: maximum number of lemma alternatives
--verbPrep: verb dependent preposition disambiguation rules (after prepDisamb)
--deModel: German language model
\n";

my %mapInputFormats = (
	'plain' => 1, 'senttok'	=> 2,  'tagged'	=> 4, 'conll'	=> 5, 'parsed'	=> 6, 'conll2xml'	=> 7,
	'rdisamb' => 8, 'coref'	=> 9, 'vdisamb'	=> 10, 'svm'	=> 11, 'lextrans'	=> 12, 'semtags'	=> 13, 'lexdisamb'	=> 14,
	'morphdisamb' => 15,
	'statlexdisamb'	=> 15.5,
	'prepdisamb'	=> 16, 
	'vprepdisamb'	=> 16.4, 'mwsplit'	=> 16.5, 'pronoun'	=> 16.6, 'future'	=> 16.7, 'vprefix'	=> 16.8,
	'intraTrans'	=> 17, 'interTrans'	=> 18, 'node2chunk'	=> 19, 'child2sibling'	=> 20,
	'interOrder'=> 21, 'intraOrder'=> 22, 'morph'=> 23, 'words'=> 24, 'nbest' => 25
);


GetOptions(
	# general options
    'help|h'     => \$help,
    'config|c=s'    => \$config,
    'file|f=s'    => \$file,
    'direction|d=s' => \$direction,
    'outformat|o=s' => \$outformat,
    'informat|i=s' => \$informat,
    # options for tagging
	'wapiti=s'    => \$wapiti,
	'wapitiModel=s'    => \$wapitiModel,
	'freelingPort=i'    => \$freelingPort,
	'freelingConf=s'    => \$freelingConf,
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
    # options for es-de
    'chunkMap=s' => \$chunkMap,
    'bilexprob=s' => \$biLexProb,
    'deLemmaModel=s' => \$deLemmaModel,
    'maxalt=i' => \$maxalt,
    'verbPrep=s' => \$verbPrep,
    'deModel=s' => \$deModel
) or die "Incorrect usage!\n $helpstring";

	if($help){ print STDERR $helpstring; exit;}
	if($config ne ''){
		print STDERR "reading config file: $config\n";
		open (CONFIG, "<:encoding(UTF-8)", $config) or die "Can't open configuration file $config: $!\n";
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
	if($outformat !~ /^senttok|tagged|conll|parsed|conll2xml|rdisamb|coref|vdisamb|svm|lextrans|semtags|lexdisamb|morphdisamb|statlexdisamb|prepdisamb|vprepdisamb|mwsplit|pronoun|future|vprefix|intraTrans|interTrans|node2chunk|child2sibling|interOrder|intraOrder|morph|words|nbest$/){
		die "Invalid output format $outformat, valid options are:
\t senttok: plain text, one sentence per line
\t tagged: wapiti crf
\t conll: tagged conll
\t parsed: desr output (conll)
\t conll2xml: xml created from parsing
\t rdisamb: xml disambiguated relative clauses, only with direction esqu
\t coref: xml after coreference resolution for subjects, only with direction esqu
\t vdisamb: xml disambiguated verb forms, rule-based, only with direction esqu
\t svm: xml disambiguated verb forms with libsvm, only with direction esqu
\t lextrans: xml after lexical transfer
\t semtags: xml after insertion of semantic tags
\t lexdisamb: xml after lexical disambiguation (rule-based)
\t morphdisamb: xml after morphological disambiguation
\t statlexdisamb: xml after statistic lexical disambiguation, only with direction esde
\t prepdisamb: xml after preposition disambiguation
\t vprepdisamb: xml after verb preposition disambiguation, only with direction esde
\t mwsplit: xml after multi-word splitting
\t pronoun: xml after inserting subject pronouns, only with direction esde
\t future: xml after inserting future auxiliary, only with direction esde
\t vprefix: xml after verb prefix splitting, only with direction esde
\t intraTrans: xml after intrachunk syntactic transfer
\t interTrans: xml after interchunk syntactic transfer
\t node2chunk: xml after promotion of nodes to chunks
\t node2sibling: xml after promtion of child chunks to siblings
\t intraOrder: xml after intrachunk syntactic ordering
\t interOrder: xml after interchunk syntactic ordering
\t morph: input for morphological generation
\t words: output of morphological generation
\t nbest: nbest translation options = default";
	}
	## check if input format is a valid option, and check if it's set in config, if neither --informat nor informat= set in config: set to 'senttok'
	if($informat eq ''){
		eval{
			$informat = $config{'informat'};
		} or $informat ='senttok';
	}
	if($informat !~ /^plain|senttok|tagged|conll|parsed|conll2xml|rdisamb|coref|vdisamb|svm|lextrans|semtags|lexdisamb|morphdisamb|statlexdisamb|prepdisamb|mwsplit|pronoun|future|vprefix|intraTrans|interTrans|node2chunk|child2sibling|interOrder|intraOrder|morph|words$/ ){
				die "Invalid input format $informat, valid options are:
\t plain: plain text
\t senttok: plain text, one sentence per line (=default)
\t crf: crf instances, freeling output (morphological analysis)
\t tagged: wapiti crf
\t conll: tagged conll
\t parsed: desr output (conll)
\t conll2xml: xml created from parsing
\t rdisamb: xml disambiguated relative clauses, only with direction esqu
\t coref: xml after coreference resolution for subjects, only with direction esqu
\t vdisamb: xml disambiguated verb forms, rule-based, only with direction esqu
\t svm: xml disambiguated verb forms with libsvm, only with direction esqu
\t lextrans: xml after lexical transfer
\t semtags: xml after insertion of semantic tags
\t lexdisamb: xml after lexical disambiguation (rule-based)
\t morphdisamb: xml after morphological disambiguation
\t statlexdisamb: xml after statistic lexical disambiguation, only with direction esde
\t prepdisamb: xml after preposition disambiguation
\t vprepdisamb: xml after verb preposition disambiguation, only with direction esde
\t mwsplit: xml after multi-word splitting
\t pronoun: xml after inserting subject pronouns, only with direction esde
\t future: xml after inserting future auxiliary, only with direction esde
\t vprefix: xml after verb prefix splitting, only with direction esde
\t intraTrans: xml after intrachunk syntactic transfer
\t interTrans: xml after interchunk syntactic transfer
\t node2chunk: xml after promotion of nodes to chunks
\t node2sibling: xml after promtion of child chunks to siblings
\t intraOrder: xml after intrachunk syntactic ordering
\t interOrder: xml after interchunk syntactic ordering
\t morph: input for morphological generation
\t words: output of morphological generation";
	}

	my $startTrans = $mapInputFormats{$informat};
print STDERR "start $startTrans\n"."end " . $mapInputFormats{$outformat}. "\n";
	if($startTrans > $mapInputFormats{$outformat}){
		die "cannot process input from format=$informat to format=$outformat (wrong direction)!!\n";
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
			print STDERR "starting squoia_analyzer server on port $freelingPort with config $freelingConf, logging to $path/logs/logcrfmorf...\n";
			system("squoia_analyzer -f $freelingConf --outf=crfmorf --server --port=$freelingPort 2> $path/logs/logcrfmorf &");
			while(`echo "test" | analyzer_client "$freelingPort" 2>/dev/null` eq ''){
				print STDERR "starting squoia_analyzer, please wait...\n";
				sleep 10;
			}
			print STDERR "squoia_analyzer now ready\n";
		}
	

###-----------------------------------end read commandline arguments -----------------------------------------------####

###-----------------------------------begin analysis Spanish input -----------------------------------------------####
#if($startTrans<$mapInputFormats{'senttok'})	#2)
#{ } TODO sentence tokenization

if($startTrans<$mapInputFormats{'tagged'})	#4)
{
	### tagging: if input file given with --file or -f:
	# check if $matxin,  $wapiti and $wapitiModel are all set, otherwise exit
	if($matxin eq '' or $wapiti eq '' or $wapitiModel eq ''){
		eval{
			$matxin = $config{'matxin'}; $wapiti = $config{'wapiti'}; $wapitiModel = $config{'wapitiModel'};
		}
		or die "Tagging failed, location of matxin, wapiti or wapiti model not indicated!\n";;
	}
	if($file ne ''){
				open(CONLL,"-|" ,"cat $file | $matxin/analyzer_client $freelingPort | $wapiti/wapiti label --force -m $wapitiModel"  ) || die "tagging failed: $!\n";
		}
		# if no file given, expect input on stdin
		else{
			# solution without open2, use tmp file
			my $tmp = $path."/tmp/tmp.txt";
			open (TMP, ">:encoding(UTF-8)", $tmp) or die "Can't open temporary file \"$tmp\" to write: $!\n";
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
}
my $conllLines;
if($startTrans<$mapInputFormats{'conll'}){	#5){
	# if starting translation process from here, read file or stdin
	if($startTrans==$mapInputFormats{'tagged'}){	#4){
		if($file){
			open (FILE, "<", $file) or die "Can't open input file \"$file\" to translate: $!\n";
			$conllLines = squoia::crf2conll::main(\*FILE);
			close(FILE);
		}
		else{
			#### convert to wapiti crf to conll for desr parser
			binmode(STDIN);
			$conllLines = squoia::crf2conll::main(\*STDIN);
		}

	}
	else{
		#### convert to wapiti crf to conll for desr parser
		$conllLines = squoia::crf2conll::main(\*CONLL);
		close(CONLL);
	}
	
	if($outformat eq 'conll'){
		foreach my $line (@$conllLines){
			print STDOUT $line;
		}
		exit;
	}
}
my $dom;
if($startTrans <$mapInputFormats{'conll2xml'})	#7)
{
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
			print STDERR "starting desr_server on port $desrPort1 with model $desrModel1, logging to $path/logs/logdesr_1...\n";
			system("desr_server -m $desrModel1 --port $desrPort1 2> $path/logs/logdesr_1 &");
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
			print STDERR "starting desr_server on port $desrPort2 with model $desrModel2, logging to $path/logs/logdesr_2...\n";
			system("desr_server -m $desrModel2 --port $desrPort2 2> $path/logs/logdesr_2 &");
			print STDERR "desr_server with model 2 = $desrModel2 started on port $desrPort2...\n";
			sleep 1;
		}

	if($startTrans <$mapInputFormats{'parsed'})	#6)
	{
		### parse tagged text:
		my $tmp2;
		# if starting translation process from here, read file or stdin
		if($startTrans ==$mapInputFormats{'conll'} && $file ne ''){	#5
			$tmp2 = $file;
		}
		else{
			$tmp2 = $path."/tmp/tmp.conll";
			open (TMP2, ">", $tmp2)  or die "Can't open temporary file \"$tmp2\" to write: $!\n";
			# if starting translation from here and no file given: read from stdin
			if($startTrans ==$mapInputFormats{'conll'}){	#5)
				binmode(STDIN);
				while(<>){
					print TMP2 $_;
				}
			}
			else{		
				foreach my $l (@$conllLines){print TMP2 $l;}
			}
		}
		open(CONLL2,"-|" ,"cat $tmp2 | desr_client $desrPort1"  ) || die "parsing failed: $!\n";
		close(TMP2);
		
		## if output format is 'conll': print and exit
		if($outformat eq 'parsed'){
			while(<CONLL2>){print;}
			close(CONLL2);
			exit;
		}
	}

	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'parsed'}){	#6){
		if($file ne ''){
			open (FILE, "<", $file) or die "Can't open input file \"$file\" to translate: $!\n";
			$dom = squoia::conll2xml::main(\*FILE, $desrPort2);
			close(FILE);
		}
		else{
			binmode(STDIN);
			$dom = squoia::conll2xml::main(\*STDIN, $desrPort2);
		}
	}
	else{
		#### create xml from conll
		$dom = squoia::conll2xml::main(\*CONLL2, $desrPort2);
		close(CONLL2);
		
	}
	
	## if output format is 'conll2xml': print and exit
	if($outformat eq 'conll2xml'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

####-----------------------------------end analysis Spanish input -----------------------------------------------####


####-----------------------------------begin preprocessing for es-qu -----------------------------------------------####
#### verb disambiguation
if($direction eq 'esqu' && $startTrans < $mapInputFormats{'svm'})	#11)
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

if($startTrans < $mapInputFormats{'rdisamb'})	#8)
{
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'conll2xml'}){	#7){
		if($file ne '' ){
				open (FILE, "<", $file)  or die "Can't open input file \"$file\" to translate: $!\n";
				$dom  = XML::LibXML->load_xml( IO => *FILE );
				close(FILE);
		}
		else{
			binmode(STDIN);
			$dom  = XML::LibXML->load_xml( IO => *STDIN);
		}
	}
	squoia::esqu::disambRelClauses::main(\$dom, \%nounLex, \%verbLex);

	## if output format is 'rdisamb': print and exit
	if($outformat eq 'rdisamb'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

if($startTrans < $mapInputFormats{'coref'})	#9)
{
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'rdisamb'}){	#8){
		$dom = &readXML();
	}
	squoia::esqu::coref::main(\$dom);
	
	## if output format is 'coref': print and exit
	if($outformat eq 'coref'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

if($startTrans < $mapInputFormats{'vdisamb'})	#10)
{
	# check if evidentiality set
	if($evidentiality ne 'direct' or $evidentiality eq 'indirect'){
		print STDERR "Invalid value  '$evidentiality' for option --evidentiality, possible values are 'direct' or 'indirect'. Using default (=direct)\n";
		$evidentiality = 'direct';
	}
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'coref'}){	#9){
		$dom = &readXML();
	}
	
	squoia::esqu::disambVerbFormsRules::main(\$dom, $evidentiality, \%nounLex);

	## if output format is 'vdisamb': print and exit
	if($outformat eq 'vdisamb'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

if($startTrans<$mapInputFormats{'svm'})	# 11)
{
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
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'vdisamb'}){	#10){
		$dom = &readXML();
	}

 	squoia::esqu::svm::main(\$dom, \%verbLex, \%verbLemClasses);

	## if output format is 'svm': print and exit
	if($outformat eq 'svm'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
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
if($startTrans <$mapInputFormats{'lextrans'})	#12)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'lextrans'} .") lexical transfer\n";
	## check if $bidix is set
	if($bidix eq ''){
		eval{
			$bidix = $config{'bidix'};
		}
		or die "Lexical transfer failed, location of bilingual dictionary not indicated (set option bidix in confix or use --bidix on commandline)!\n";
	}
	
	# if starting translation process from here, read file or stdin
	my $tmp3;
	if($startTrans ==$mapInputFormats{'svm'} && $file ne ''){	#11
		$tmp3 = $file;
	}
	else{
		$tmp3 = $path."/tmp/tmp.xml";
		open (TMP3, ">", $tmp3) or die "Can't open temporary file \"$tmp3\" to write: $!\n";
		# if starting translation from here and no file given: read from stdin
		if($startTrans ==$mapInputFormats{'svm'}){	#11){
			binmode(STDIN);
			while(<>){
				print TMP3 $_;
			}
		}else{		
			my $docstring = $dom->toString(1);
			print TMP3 $docstring;
		}
	}
	# check if $matxin is set, otherwise exit
	if($matxin eq ''){
		eval{
			$matxin = $config{'matxin'}; 
		}or die "Lexical failed, location of matxin-xfer-lex not indicated! Set option matxin in config or use --matxin on commandline\n";;
	}

	if($chunkMap eq '' and $config{'chunkMap'} eq ''){
		open(XFER,"-|" ,"cat $tmp3 | $matxin/matxin-xfer-lex $bidix"  ) || die "lexical transfer failed: $!\n";
	} else {
		$chunkMap = $config{'chunkMap'} if ($chunkMap eq '');
		open(XFER,"-|" ,"cat $tmp3 | $matxin/matxin-xfer-lex -c $chunkMap $bidix"  ) || die "lexical transfer failed: $!\n";
	}
	close(TMP3);
	
	$dom = XML::LibXML->load_xml( IO => *XFER );
	close(XFER);

	## if output format is 'lextrans': print and exit
	if($outformat eq 'lextrans'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

#### insert semantic tags: 
if($startTrans <$mapInputFormats{'semtags'})	#13)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'semtags'} .") insert semantic tags\n";
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
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'lextrans'}){	#12){
		$dom = &readXML();
	}
	squoia::insertSemanticTags::main(\$dom, \%semanticLexicon);
	
	if($outformat eq 'semtags'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

### lexical disambiguation, rule-based
if($startTrans <$mapInputFormats{'lexdisamb'})	#14)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'lexdisamb'} .") lexical disambiguation, rule-based\n";
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
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'semtags'}){	#13){
		$dom = &readXML();
	}
	squoia::semanticDisamb::main(\$dom, \%lexSel);
	
	if($outformat eq 'lexdisamb'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

### morphological disambiguation, rule-based
if($startTrans <$mapInputFormats{'morphdisamb'})	#15)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'morphdisamb'} .") morphological disambiguation, rule-based\n";
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

	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'lexdisamb'}){	#14){
		$dom = &readXML();
	}
	squoia::morphDisamb::main(\$dom, \%morphSel);

	## if output format is 'morphdisamb': print and exit
	if($outformat eq 'morphdisamb'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

####-----------------------------------begin specific processing for es-de -----------------------------------------------####
if($direction eq 'esde')
{
### statistic lexical disambiguation
if($startTrans <$mapInputFormats{'statlexdisamb'})
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'statlexdisamb'} .") statistical lexical disambiguation\n";
	my %bilexprobs = ();
	$readrules =0;

	# check if deModel is set
	if($deLemmaModel eq ''){
		eval{
			$deLemmaModel = $config{'deLemmaModel'};
		}
		or die "Statistic lexical disambiguation failed, location of German lemma language model not indicated (set option deLemmaModel in config or use --deLemmaModel on commandline)!\n";
	}
	
	if($biLexProb ne ''){
		$readrules =1;
		print STDERR "reading bilingual lexical probabilities from $biLexProb\n";
		open (BILEXPROBFILE, "<:encoding(UTF-8)", $biLexProb) or die "Can't open $biLexProb: $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$biLexProb = $config{"BilexProbFile"} or die "Bilingual lexical probability file not specified in config, insert BilexProbFile='path to bilingual lexical probabilities' or use option --bilexprob!";
		print STDERR "reading bilingual lexical probabilities from file specified in $config: $biLexProb\n";
		open (BILEXPROBFILE, "<:encoding(UTF-8)", $biLexProb) or die "Can't open $biLexProb as specified in config: $!";
	}
	if($readrules){
		#read bilingual lexical probabilities from file into a hash (slem, tlem, prob)
		while (<BILEXPROBFILE>) {
			chomp;
			s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ( $slem, $tlem, $prob ) = split( /\s*\t+\s*/, $_, 3 );
			# assure key is unique, use slem:tlem as key
			my $key = "$slem\t$tlem";
			$bilexprobs{$key} = $prob;
		}
		store \%bilexprobs, "$path/storage/BilexProbabilities";
		close(BILEXPROBFILE);
	}
	else{
		## if neither --bilexProb nor --config given: check if bilingual lexical probabilities are already available in storage
		eval{
			retrieve("$path/storage/BilexProbabilities");
		} or print STDERR "Failed to retrieve bilingual lexical probabilities, set option BilexProbFile=path in config or use --bilexprob path on commandline to indicate bilingual lexical probabilities!\n";
		%bilexprobs = %{ retrieve("$path/storage/BilexProbabilities") };
	}

	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'morphdisamb'}){
		$dom = &readXML();
	}
	squoia::esde::statBilexDisamb::main(\$dom, \%bilexprobs, $deLemmaModel, $maxalt);
	squoia::alternativeSentences::main(\$dom);
	## if output format is 'statlexdisamb': print and exit
	if($outformat eq 'statlexdisamb'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}
}
####-----------------------------------end specific processing for es-de -----------------------------------------------####

### preposition disambiguation, rule-based
if($startTrans <$mapInputFormats{'prepdisamb'})	#16)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'prepdisamb'} .") preposition disambiguation, rule-based\n";
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
	
	# if starting translation process from here, read file or stdin
	if(($direction eq 'esqu' and $startTrans ==$mapInputFormats{'morphdisamb'})
	 or ($direction eq 'esde' and $startTrans ==$mapInputFormats{'statlexdisamb'})){
		$dom = &readXML();
	}
	squoia::prepositionDisamb::main(\$dom, \%prepSel);
	
	## if output format is 'prepdisamb': print and exit
	if($outformat eq 'prepdisamb'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}
####-----------------------------------begin specific processing for es-de -----------------------------------------------####
if($direction eq 'esde')
{
### verb preposition disambiguation
if($startTrans <$mapInputFormats{'vprepdisamb'})
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'vprepdisamb'} .") verb preposition disambiguation\n";
	my %verbPrepSel = ();
	$readrules =0;

	if($verbPrep ne ''){
		$readrules =1;
		print STDERR "reading verb preposition disambiguation rules from $verbPrep\n";
		open (VERBPREPFILE, "<:encoding(UTF-8)", $verbPrep) or die "Can't open $verbPrep: $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$verbPrep = $config{"VerbPrepFile"} or die "Verb preposition disambiguation file not specified in config, insert VerbPrepFile='path to verb preposition disambiguation rules' or use option --verbPrep!";
		print STDERR "reading verb preposition disambiguation rules from file specified in $config: $verbPrep\n";
		open (VERBPREPFILE, "<:encoding(UTF-8)", $verbPrep) or die "Can't open $verbPrep as specified in config: $!";
	}
	if($readrules){
		#read verb prep information from file into a hash (SLverb, SLprep, TLverb, TLprep, TLcase)
		while (<VERBPREPFILE>) {
			chomp;
			s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next if /^$/;	# skip if empty line
			my ( $SLverb, $SLprep, $TLverb, $TLprep, $TLcase ) = split( /\s*\t+\s*/, $_, 5 );

			# assure key is unique, use SLverb+SLprep+TLverb as key
			my $key = "$SLverb\t$SLprep\t$TLverb";
			my @value = ( $TLprep, $TLcase );
			$verbPrepSel{$key} = \@value;
		}
		store \%verbPrepSel, "$path/storage/VerbPrepSelRules";
		close(VERBPREPFILE);
	}
	else{
		## if neither --verbPrep nor --config given: check if verb preposition disambiguation rules are already available in storage
		eval{
			retrieve("$path/storage/VerbPrepSelRules");
		} or print STDERR "Failed to retrieve verb preposition selection rules, set option VerbPrepFile=path in config or use --verbPrep path on commandline to indicate verb preposition disambiguation rules!\n";
		%verbPrepSel = %{ retrieve("$path/storage/VerbPrepSelRules") };
	}

	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'prepdisamb'}){
		$dom = &readXML();
	}
	squoia::esde::verbPrepDisamb::main(\$dom, \%verbPrepSel);
	## if output format is 'vprepdisamb': print and exit
	if($outformat eq 'vprepdisamb'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

### split multi-words
if($startTrans <$mapInputFormats{'mwsplit'})
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'mwsplit'} .") split multi-words\n";
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'vprepdisamb'}){
		$dom = &readXML();
	}
	squoia::splitNodes::main(\$dom);
	## if output format is 'mwsplit': print and exit
	if($outformat eq 'mwsplit'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}
### insert subject pronouns
if($startTrans <$mapInputFormats{'pronoun'})
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'pronoun'} .") insert subject pronouns\n";
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'mwsplit'}){
		$dom = &readXML();
	}
	squoia::esde::addPronouns::main(\$dom);
	## if output format is 'pronoun': print and exit
	if($outformat eq 'pronoun'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}
### insert future auxiliaries
if($startTrans <$mapInputFormats{'future'})
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'future'} .") insert future auxiliaries\n";
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'pronoun'}){
		$dom = &readXML();
	}
	squoia::esde::addFutureAux::main(\$dom);
	## if output format is 'future': print and exit
	if($outformat eq 'future'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}
### split verb prefixes
if($startTrans <$mapInputFormats{'vprefix'})
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'vprefix'} .") split verb prefixes\n";
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'future'}){
		$dom = &readXML();
	}
	squoia::esde::splitVerbPrefix::main(\$dom);
	## if output format is 'vprefix': print and exit
	if($outformat eq 'vprefix'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}
}
####-----------------------------------end specific processing for es-de -----------------------------------------------####

### syntactic transfer, intra-chunks (from nodes to chunks and vice versa)
if($startTrans <$mapInputFormats{'intraTrans'})	#17)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'intraTrans'} .") syntactic transfer, intra-chunks\n";
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
	
	# if starting translation process from here, read file or stdin
	if(($direction eq 'esqu' and $startTrans ==$mapInputFormats{'prepdisamb'})
	 or ($direction eq 'esde' and $startTrans ==$mapInputFormats{'vprefix'})){
		$dom = &readXML();
	}
	squoia::intrachunkTransfer::main(\$dom, \%intraConditions);
	
	## if output format is 'intraTrans': print and exit
	if($outformat eq 'intraTrans'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

### syntactic transfer, inter-chunks (move/copy information between chunks)
if($startTrans <$mapInputFormats{'interTrans'})	#18)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'interTrans'} .") syntactic transfer, inter-chunks\n";
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
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'intraTrans'}){	#17){
		$dom = &readXML();
	}
	squoia::interchunkTransfer::main(\$dom, \%interConditions);
	
	## if output format is 'interTrans': print and exit
	if($outformat eq 'interTrans'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

### promote nodes to chunks, if necessary
if($startTrans <$mapInputFormats{'node2chunk'})	#19)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'node2chunk'} .") promote nodes to chunks\n";
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
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'interTrans'}){	#18){
		$dom = &readXML();
	}
	squoia::nodesToChunks::main(\$dom, \@nodes2chunksRules);
	## if output format is 'node2chunk': print and exit
	if($outformat eq 'node2chunk'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}

### rules to promote child chunks to siblings (necessary for ordering Quechua internally headed relative clauses)
if($startTrans <$mapInputFormats{'child2sibling'})	#20)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'child2sibling'} .") promote child chunks to siblings\n";
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
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'node2chunk'}){	#19){
		$dom = &readXML();
	}
	squoia::childToSiblingChunk::main(\$dom, \%targetAttributes);
	
	## if output format is 'node2chunk': print and exit
	if($outformat eq 'child2sibling'){
		my $docstring = $dom->toString(3);
		print STDOUT $docstring;
		exit;
	}
}
if($startTrans <$mapInputFormats{'interOrder'})	#21)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'interOrder'} .") reorder the chunks, inter-chunks\n";
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'child2sibling'}){	#20){
		$dom = &readXML();
	}
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
}

if($startTrans <$mapInputFormats{'intraOrder'})	#22)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'intraOrder'} .") reorder the nodes, intra-chunks\n";
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'interOrder'}){	#21){
		$dom = &readXML();
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
}

###-----------------------------------end translation ---------------------------------------------------------####

###-----------------------------------begin morphological generation ---------------------------------------------------------####
my $sentFile = "$path/tmp/tmp.words";
my $morphfile = "$path/tmp/tmp.morph";
if($startTrans < $mapInputFormats{'morph'})	#23)
{
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'intraOrder'}){	#22)
		$dom = &readXML();
	}
	if ($direction eq 'esqu') {
		squoia::esqu::xml2morph::main(\$dom, $morphfile);
	} elsif ($direction eq 'esde') {
		squoia::esde::outputGermanMorph::main(\$dom,$morphfile);
	} else {
		print STDERR "Translation direction not defined!\n";
	}
	## if output format is 'morph': print and exit
	if($outformat eq 'morph'){
		system("cat $morphfile");
		exit;
	}
}
if($startTrans< $mapInputFormats{'words'})
{
	## generate word forms with xfst
	## check if $morphgenerator is set
	if($morphgenerator eq ''){
		eval{
			$morphgenerator = $config{'morphgenerator'};
		}
		or die "Morphological generation failed, location of xfst generator not indicated (set option morphgenerator in confix or use --morphgenerator on commandline)!\n";
	}
	# if starting with a morph file: take file as input or stdin TODO
	if($startTrans == $mapInputFormats{'morph'} && $file ne ''){	#23 
		if($file ne ''){
			$morphfile = $file;
		}
		else{
			open (MORPH, ">:encoding(UTF-8)", $morphfile) or die "Can't open file \"$morphfile\" to write: $!\n";
			while(<>){
				print MORPH $_;
			}
			close(MORPH);
		}
	}
	## quz
	if($direction eq 'esqu')
	{

				open(XFST,"-|" ,"cat $morphfile | lookup -flags xcKv29TT $morphgenerator "  ) || die "morphological generation failed: $!\n";		
				open (SENT, ">:encoding(UTF-8)", $sentFile) or die "Can't open file \"$sentFile\" to write: $!\n";
				binmode(XFST, ':utf8');
				while(<XFST>){
					print SENT $_;
				}
				close(XFST);
				close(SENT);
	}
	## de
	elsif($direction eq 'esde')
	{
		my $morphwordFile = "$path/tmp/tmp.morphword";
		squoia::esde::outputGermanMorph::generateMorphWord($morphfile,$morphwordFile,"flookup $morphgenerator");
		squoia::esde::outputGermanMorph::cleanFstOutput($morphwordFile,$sentFile);
	}
	## if output format is 'words': print and exit
	if($outformat eq 'words'){
		system("cat $sentFile");
		exit;
	}
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
		or die "Ranking failed, location of quechua language model not indicated (set option quModel in config or use --quModel on commandline)!\n";
	}
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'words'}){	#24){
		if($file ne ''){
			$sentFile = $file;
		}
		else{
			open (SENT, ">:encoding(UTF-8)", $sentFile) or die "Can't open file \"$sentFile\" to write: $!\n";
			while(<>){
				print SENT $_;
			}
			close(SENT);
		}
	}
	system("$path/squoia/esqu/outputSentences -m $quModel -n $nbest -i $sentFile");
}
## de
elsif($direction eq 'esde'){
	# check if deModel is set
	if($deModel eq ''){
		eval{
			$deModel = $config{'deModel'};
		}
		or die "Ranking failed, location of German language model not indicated (set option deModel in confix or use --deModel on commandline)!\n";
	}
	
	# if starting translation process from here, read file or stdin
	if($startTrans ==$mapInputFormats{'words'}){
		if($file ne ''){
			$sentFile = $file;
		}
		else{
			open (SENT, ">:encoding(UTF-8)", $sentFile) or die "Can't open file \"$sentFile\" to write: $!\n";
			while(<>){
				print SENT $_;
			}
			close(SENT);
		}
	}
	system("$path/squoia/esde/outputSentences -m $deModel -n $nbest -i $sentFile");	# TODO: outputSentences for German...
	
}

###-----------------------------------end ranking (kenlm) ---------------------------------------------------------####

END{
	## done!! cleanup?
}


sub readXML{
	if($file ne '' ){
		open (FILE, "<", $file) or die "Can't open file \"$file\": $!\n";
		$dom  = XML::LibXML->load_xml( IO => *FILE );
		close(FILE);
	}
	else{
		binmode(STDIN);
		$dom  = XML::LibXML->load_xml( IO => *STDIN);
	}
	return $dom;
}
