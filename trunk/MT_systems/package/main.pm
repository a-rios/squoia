#!/usr/bin/perl 

package squoia::main;
our $path;
use utf8;

BEGIN{

	use File::Spec::Functions qw(rel2abs);
	use File::Basename;
	$path = dirname(rel2abs($0));
	use lib $path.".";

	binmode STDIN, ':encoding(UTF-8)';
	#binmode STDERR, ':utf8';
	#binmode(STDOUT);
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
	
	## esqu modules
	use squoia::esqu::disambRelClauses;
	use squoia::esqu::coref;
	use squoia::esqu::disambVerbFormsRules;
	use squoia::esqu::svm;
	
	## esde modules

	#use squoia::esqu::testSVM;
	#use Encode::Detect::Detector;
	
}


# variables needed to run the MT system
my %config;

## set variables for tagging (FreeLing and Wapiti)
# tagging
my $WAPITI_DIR="/home/clsquoia/Wapiti";
my $WAPITI_MODEL="/home/clsquoia/google_squoia/MT_systems/tagging/wapiti/3gram_enhancedAncora.model";
my $FREELING_PORT="8844";
my $MATXIN_BIN="/opt/matxin/local/bin";

## set variables for desr parser
my $DESR_PORT=5678;

## set variables for lexical transfer
my $MATXIN_DIX="$path/squoia/esqu/lexica/es-quz.bin";

###-----------------------------------begin read commandline arguments -----------------------------------------------####

### get commandline options
my %options;

# setup options
# general options
my $help = 0;
my $config;
my $infile;
my $semlex;
my $lexDisamb;
my $morphDisam;
my $prepDisamb;
# esqu options
my $nounlex;
my $verblex;
my $evidentiality = "direct";
my $svmtestfile;
my $wordnet;
# esde options

GetOptions(
    'help|h'     => \$help,
    'config|c=s'    => \$config,
    'infile|i=s'    => \$infile,
     # general options
    'semlex=s' => \$semlex,
    'lexDisamb=s' => \$lexDisamb,
    'morphDisamb=s' => \$morphDisamb,
    'prepDisamb=s' => \$prepDisamb,
    # options for es-quz
    'evidentiality|e=s'     => \$evidentiality,
    'svmtestfile=s' => \$svmtestfile,
    'nounlex=s' => \$nounlex,
    'verblex=s' => \$verblex,
    'wordnet=s' => \$wordnet,
    # TODO options for es-de
) or die "Incorrect usage! TODO helpstring\n";

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
			if($var ne 'GRAMMAR_DIR'){
				my $grammarPath = $config{'GRAMMAR_DIR'} or die "GRAMMAR_DIR not specified in config!";
				$value =~ s/\$GRAMMAR_DIR/$grammarPath/g;
		
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

	if($help){ print STDERR "TODO help\n"; exit;}
	# if input file given with --infile or -i:
	if($infile ne ''){
			open(CONLL,"-|" ,"cat $infile | $MATXIN_BIN/analyzer_client 8844 | $WAPITI_DIR/wapiti label --force -m $WAPITI_MODEL"  ) || die "tagging failed: $!\n";
	}
	# if no infile given, expect input on stdin
	else{
		# solution without open2, use tmp file
		my $tmp = $path."/tmp/tmp.txt";
		open (TMP, ">:encoding(UTF-8)", $tmp);
		while(<>){print TMP $_;}
		open(CONLL,"-|" ,"cat $tmp | $MATXIN_BIN/analyzer_client 8844 | $WAPITI_DIR/wapiti label --force -m $WAPITI_MODEL"  ) || die "tagging failed: $!\n";
		close(TMP);
	}	

###-----------------------------------end read commandline arguments -----------------------------------------------####

###-----------------------------------begin analysis Spanish input -----------------------------------------------####
#### convert to wapiti crf to conll for desr parser
my $conllLines = squoia::crf2conll::main(\*CONLL);

### parse tagged text:
my $tmp2 = $path."/tmp/tmp.conll";
		# !! not again ">:encoding(UTF-8)", results in 'doble' encoded strings!!
		open (TMP2, ">", $tmp2);
		foreach my $l (@$conllLines){print TMP2 $l;}
		open(CONLL2,"-|" ,"cat $tmp2 | desr_client $DESR_PORT"  ) || die "parsing failed: $!\n";
		close(TMP2);

#### create xml from conll
my $dom = squoia::conll2xml::main(\*CONLL2);
close(CONLL2);

####-----------------------------------end analysis Spanish input -----------------------------------------------####


####-----------------------------------begin preprocessing for es-qu -----------------------------------------------####
#
#### verb disambiguation: TODO: only if direction es-quz

	# retrieve semantic verb and noun lexica for verb disambiguation
	my %nounLex = (); my %verbLex = ();
	if($nounlex ne ''){
		open NOUNS, "<:encoding(UTF-8) $nounlex" or die "Can't open $nounlex : $!";
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
squoia::esqu::coref::main(\$dom);

	# check if evidentiality set
	if($evidentiality ne 'direct' or $evidentiality eq 'indirect'){
		print STDERR "Invalid value  '$evidentiality' for option --evidentiality, possible values are 'direct' or 'indirect'. Using default (=direct)\n";
		$evidentiality = 'direct';
	}
squoia::esqu::disambVerbFormsRules::main(\$dom, $evidentiality, \%nounLex);

	# get verb lemma classes from word net for disambiguation with svm
	my %verbLemClasses=();
	
	if($wordnet ne ''){
		my $spa2ilimap = "$wordnet/spaWN/wei_spa-30_to_ili.tsv";
		my $ilirecord = "$wordnet/data/wei_ili_record.tsv";
		my $variant = "$wordnet/spaWN/wei_spa-30_variant.tsv";
		open SPA2ILI, "<:encoding(UTF-8) $spa2ilimap" or die "Can't open $spa2ilimap : $!";
		open ILIREC, "<:encoding(UTF-8) $ilirecord" or die "Can't open $ilirecord : $!";
		open VARIANT,  "<:encoding(UTF-8) $variant" or die "Can't open $variant : $!";
	
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
## test svm module
#    if($options{'t'}){
#    	squoia::esqu::testSVM::main($options{'t'});
#    }
#
####-----------------------------------end preprocessing for es-qu -----------------------------------------------####


####-----------------------------------begin translation ---------------------------------------------------------####
#### lexical transfer with matxin-xfer-lex
my $tmp3 = $path."/tmp/tmp.xml";
		# !! not again ">:encoding(UTF-8)", results in 'doble' encoded strings!!
		open (TMP3, ">", $tmp3);
		my $docstring = $dom->toString(1);
		print TMP3 $docstring;
		open(XFER,"-|" ,"cat $tmp3 | $MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX"  ) || die "lexical transfer failed: $!\n";
		close(TMP3);

$dom = XML::LibXML->load_xml( IO => *XFER );
close(XFER);

#### insert semantic tags: 
## if semantic dictionary or new config file given on commandline: read into %semanticLexicone
	my %semanticLexicon =();
	my $readrules=0;
	if($semlex ne ''){
		$readrules =1;
		print STDERR "reading semantic lexicon from $semlex\n";
		open SEMFILE, "< $semlex" or die "Can't open $semlex : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$semlex= $config{"SemLex"} or die "Semantic dictionary not specified in config, insert SemLex='path to semantic lexicon' or use option --semlex!";
		print STDERR "reading semantic lexicon from file specified in $config: $semlex\n";
		open SEMFILE, "< $semlex" or die "Can't open $semlex as specified in config: $!";
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
		open LEXFILE, "< $lexDisamb" or die "Can't open $lexDisamb : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$lexDisamb = $config{"LexSelFile"} or die "Lexical selection file not specified in config, insert LexSelFile='path to lexical disambiguation rules' or use option --lexDisamb!";
		print STDERR "reading lexical selection rules from file specified in $config: $lexDisamb\n";
		open LEXFILE, "< $lexDisamb" or die "Can't open $lexDisamb as specified in config: $!";
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
		open MORPHFILE, "< $morphDisamb" or die "Can't open $morphDisamb : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$morphDisamb = $config{"MorphSelFile"} or die "Morphological selection file not specified in config, insert MorphSelFile='path to morphological disambiguation rules' or use option --morphDisamb!";
		print STDERR "reading morphological selection rules from file specified in $config: $morphDisamb\n";
		open MORPHFILE, "< $morphDisamb" or die "Can't open $morphDisamb as specified in config: $!";
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
		## if neither --morphDisamb nor --config given: check if semantic dictionary is already available in storage
		eval{
			retrieve("$path/storage/MorphSelRules");
		} or print STDERR "Failed to retrieve morphological selection rules, set option MorphSelFile=path in config or use --morphDisamb path on commandline to indicate morphological selection rules!\n";
		%morphSel = %{ retrieve("$path/storage/MorphSelRules") };
	}

squoia::morphDisamb::main(\$dom, \%morphSel);

### preposition disambiguation, rule-based
	my %prepSel = ();
	$readrules =0;

	if($prepDisamb ne ''){
		$readrules =1;
		print STDERR "reading preposition disambiguation rules from $prepDisamb\n";
		open PREPFILE, "< $prepDisamb" or die "Can't open $prepDisamb : $!";
	}
	elsif($config ne ''){
		$readrules =1;
		$prepDisamb = $config{"PrepFile"} or die "Preposition disambiguation file not specified in config, insert PrepFile='path to preposition disambiguation rules' or use option --prepDisamb!";
		print STDERR "reading preposition disambiguation rules from file specified in $config: $prepDisamb\n";
		open PREPFILE, "< $prepDisamb" or die "Can't open $prepDisamb as specified in config: $!";
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
		## if neither --prepDisamb nor --config given: check if semantic dictionary is already available in storage
		eval{
			retrieve("$path/storage/PrepSelRules");
		} or print STDERR "Failed to retrieve preposition selection rules, set option PrepFile=path in config or use --prepDisamb path on commandline to indicate preposition disambiguation rules!\n";
		%prepSel = %{ retrieve("$path/storage/PrepSelRules") };
	}

squoia::prepositionDisamb::main(\$dom, \%prepSel);

my $docstring = $dom->toString(3);
print STDOUT $docstring;
#foreach my $n ($dom->getElementsByTagName('NODE')){
#	if($n->getAttribute('form') =~ /ó/){
#	print "matched: ".$n->getAttribute('form')."\n";
#	}
#	else{
#		print "not matched: ".$n->getAttribute('form')."\n";
#	}
#}
#

###-----------------------------------end translation ---------------------------------------------------------####

###-----------------------------------begin morphological generation ---------------------------------------------------------####


###-----------------------------------end morphological generation ---------------------------------------------------------####

###-----------------------------------begin ranking (kenlm) ---------------------------------------------------------####

###-----------------------------------end ranking (kenlm) ---------------------------------------------------------####

END{
	
}
