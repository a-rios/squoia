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
	use Getopt::Std;
	use squoia::util;
	use squoia::conll2xml;
	use squoia::crf2conll;
	use squoia::esqu::disambRelClauses;
	use squoia::esqu::coref;
	use squoia::esqu::disambVerbFormsRules;
	use squoia::esqu::svm;

#	use squoia::esqu::testSVM;
	#use Encode::Detect::Detector;
	

	# TODO: read config
	
	
}


# variables needed to run the MT system
my $evid;


## set variables for tagging
# tagging
my $WAPITI_DIR="/home/clsquoia/Wapiti";
my $WAPITI_MODEL="/home/clsquoia/google_squoia/MT_systems/tagging/wapiti/3gram_enhancedAncora.model";
my $FREELING_PORT="8844";
my $MATXIN_BIN="/opt/matxin/local/bin";

# get commandline options
my %options;
getopts('e:f:t:h', \%options);
	if ($options{'h'}) { print STDERR "TODO help\n"; exit;}
	if($options{'e'}){
		$evid = $options{'e'}
	}else{
		$evid = "rqa";
	}
	# if input file:
	if($options{'f'}){
		my $tmp = $options{'f'};
		open(CONLL,"-|" ,"cat $tmp | $MATXIN_BIN/analyzer_client 8844 | $WAPITI_DIR/wapiti label --force -m $WAPITI_MODEL"  ) || die "tagging failed: $!\n";
	}
	else{
		# solution without open2, use tmp file
		my $tmp = $path."/tmp/tmp.txt";
		open (TMP, ">:encoding(UTF-8)", $tmp);
		while(<>){print TMP $_;}
		open(CONLL,"-|" ,"cat $tmp | $MATXIN_BIN/analyzer_client 8844 | $WAPITI_DIR/wapiti label --force -m $WAPITI_MODEL"  ) || die "tagging failed: $!\n";
		close(TMP);
	}

    # test svm
#    if($options{'t'}){
#    	squoia::esqu::testSVM::main($options{'t'});
#    }

### convert to wapiti crf to conll for desr parser
my $conllLines = squoia::crf2conll::main(\*CONLL);

### parse tagged text:
my $DESR_PORT=5678;
my $tmp2 = $path."/tmp/tmp.conll";
		# !! not again ">:encoding(UTF-8)", results in 'doble' encoded strings!!
		open (TMP2, ">", $tmp2);
		foreach my $l (@$conllLines){print TMP2 $l;}
		open(CONLL2,"-|" ,"cat $tmp2 | desr_client $DESR_PORT"  ) || die "parsing failed: $!\n";
		close(TMP2);


### create xml from conll
my $dom = squoia::conll2xml::main(\*CONLL2);

### verb disambiguation: TODO: only if direction es-quz
squoia::esqu::disambRelClauses::main(\$dom);
squoia::esqu::coref::main(\$dom);
squoia::esqu::disambVerbFormsRules::main(\$dom);
squoia::esqu::svm::main(\$dom);

### lexical transfer
#$MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX 
my $MATXIN_DIX="$path/squoia/esqu/lexica/es-quz.bin";
my $tmp3 = $path."/tmp/tmp.xml";
		# !! not again ">:encoding(UTF-8)", results in 'doble' encoded strings!!
		open (TMP3, ">", $tmp3);
		my $docstring = $dom->toString(1);
		print TMP3 $docstring;
		open(XFER,"-|" ,"cat $tmp3 | $MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX"  ) || die "lexical transfer failed: $!\n";
		close(TMP3);

$dom = XML::LibXML->load_xml( IO => *XFER );	
my $docstring = $dom->toString();
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

END{
	
}
