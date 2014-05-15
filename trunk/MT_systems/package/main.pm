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
#	use squoia::insertSemanticTags;
	
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

# setup my defaults
my $config;
my $infile;
my $semlex;
my $nounlex;
my $verblex;
my $evidentiality = "direct";
my $svmtestfile;
my $wordnet;
my $help     = 0;

GetOptions(
    'config|c=s'    => \$config,
    'infile|i=s'    => \$infile,
    'evidentiality|e=s'     => \$evidentiality,
    'svmtestfile|t=s' => \$svmtestfile,
    'semlex=s' => \$semlex,
    'help|h'     => \$help,
    'nounlex=s' => \$nounlex,
    'verblex=s' => \$verblex,
    'wordnet=s' => \$wordnet,
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
		} or die "No VerbLemClasses in $path/storage found! specify --wordnet=path to read in the Spanish verb synsets from wordnet (indicate path to mcr30). ";
		%verbLemClasses =  %{ Storable::retrieve("$path/storage/verbLemClasses") };
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
#
#### insert semantic tags: 
### if semantic dictionary or new config file given on commandline: read into %semanticLexicone
#my %semanticLexicon =();
#if($semlex ne ''){
#	print STDERR "reading semantic lexicon from $semlex\n";
#	open SEMFILE, "< $semlex" or die "Can't open $semlex : $!";
#}
#elsif($config ne ''){
#	$semlex= $config{"SemLex"} or die "Semantic dictionary not specified in config, insert SemLex='path to semantic lexicon' or use option --semlex=path!";
#	print STDERR "reading semantic lexicon from file specified in $config: $semlex\n";
#	open SEMFILE, "< $semlex" or die "Can't open $semlex as specified in config: $!";
#}
#if(SEMFILE){
#	## read semantic information from file into a hash (lemma, semantic Tag,  condition)
#	while(<SEMFILE>){
#		 	chomp;
#		 	s/#.*//;     # no comments
#			s/^\s+//;    # no leading white
#			s/\s+$//;    # no trailing white
#			my ($lemma, $semTag ,$condition ) = split( /\s*\t+\s*/, $_, 3 );
#			my @value = ($semTag, $condition);
#			$semanticLexicon{$lemma} = \@value;
#		}
#		store \%semanticLexicon, "$path/storage/SemLex";
#}
#else{
#	## if neither semlex nor config given: check if semantic dictionary is already available in storage
#	eval{
#		retrieve("$path/storage/SemLex");
#		%semanticLexicon = %{ retrieve("$path/storage/SemLex") };
#	} or print STDERR "Failed to retrieve semantic lexicon, set option SemLex=path in config or use --semlex=path on commandline to indicate semantic lexicon!\n";
#	
#}









my $docstring = $dom->toString(1);
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
