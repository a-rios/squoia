#!/usr/bin/perl -X

package squoia::parse;
our $path;
use utf8;

BEGIN{

	use File::Spec::Functions qw(rel2abs);
	use File::Basename;
	$path = dirname(rel2abs($0));
	use lib $path.".";

	binmode STDIN, ':encoding(UTF-8)';
	binmode STDERR, ':encoding(UTF-8)';
	use Storable;
	use strict;
	use Getopt::Long;
	
	## general squoia modules
# 	use squoia::util;
	#use squoia::crf2conll;
	use squoia::crf2conll;
}


# variables needed to run the MT system
my %config;

###-----------------------------------begin read commandline arguments -----------------------------------------------####

### get commandline options
# setup options
# general options
my $help = 0;
my $verbose = ''; # default is false; flag to switch verbose output on
my $config;
my $file;
my $outformat = 'parsed'; 
my $informat = 'senttok'; 
# options for tagging
my $wapiti;
my $wapitiModel;
my $wapitiPort;
my $freelingPort;
my $freelingConf;
my $nec;
my $neccfg;
my $matxin;
# options for parsing
my $maltPort;
my $maltModel;
my $maltPath;
# statistical co-reference resolution


my $helpstring = "Usage: $0 [options]
available options are:
--help|-h: print this help
--verbose: flag to switch verbose output on
--config|-c: indicate config (necessary for first run, later optional)
--file|-f: file with text to translate (optional, if no file given, reads input from stdin)
--outformat|-o: output format, valid formats are:
\t tagged: wapiti crf
\t conll: tagged conll
\t parsed: desr output (=default)
--informat|-i: input format, valid formats are: 
\t plain: plain text
\t senttok: plain text, one sentence per line (=default)
\t tagged: wapiti crf
\t conll: tagged conll
Options for tagging:
--wapiti: path to wapiti executables
--wapitiModel: path to wapiti model (for tagging)
--wapitiPort: port for wapiti_server (for tagging)
--freelingPort: port for squoia_server_analyzer (morphological analysis)
--freelingConf: path to FreeLing config, only needed if squoia_server_analyzer should be restartet (morphological analysis)
--nec: named entity classification
--neccfg: configuration file for ne classification
Options for parsing:
--maltPort1: port for maltparser server
--maltModel: model for maltparser server
\n";

my %mapInputFormats = (
	'plain' => 1, 'senttok'	=> 2,  'tagged'	=> 4, 'conll'	=> 5, 'parsed'	=> 6
);


GetOptions(
	# general options
    'help|h'     => \$help,
    'verbose'	=> \$verbose,
    'config|c=s'    => \$config,
    'file|f=s'    => \$file,
    'outformat|o=s' => \$outformat,
    'informat|i=s' => \$informat,
    # options for tagging
	'wapiti=s'    => \$wapiti,
	'wapitiModel=s'    => \$wapitiModel,
	'wapitiPort=i'    => \$wapitiPort,
	'freelingPort=i'    => \$freelingPort,
	'freelingConf=s'    => \$freelingConf,
	'nec=s' => \$nec,
	'neccfg=s' => \$neccfg,
	'matxin=s'    => \$matxin,
	# options for parsing
	'maltPort=i'	=> \$maltPort,
	'maltModel=s'	=> \$maltModel,
	'maltPath=s'	=> \$maltPath
) or die "Incorrect usage!\n $helpstring";


if($help){ print STDERR $helpstring; exit;}
if($config ne ''){
	$configIsSet =1;
	print STDERR "reading config file: $config\n";
	open (CONFIG, "<:encoding(UTF-8)", $config) or die "Can't open configuration file $config: $!\n";
	while (<CONFIG>) {
			chomp;       # no newline
			s/#.*//;     # no comments
			s/^\s+//;    # no leading white
			s/\s+$//;    # no trailing white
			next unless length;    # anything left?
			my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );
# 			print STDERR "var:$var, value:$value\n";
			if($value =~ /^\$/){
			  my ($setVariable,$path) = ( $value =~ m/^\$([^\/]+)\/(.+)/);
# 			  print STDERR "\t variable: $setVariable, path:$path\n";
			  my $fullpath_prefix = $config{$setVariable};
			  if($fullpath_prefix ne ''){
			    $value = $fullpath_prefix."/".$path;
			    $value =~ s/\/\//\//g;
# 			    print STDERR "\t full path: $value\n";
			  }
			  else{
			    die "variable $setVariable has not been set in config, but used in path to $var";
			  }
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
	

## check if outformat is a valid option, and check if it's set in config, if neither --outformat nor outformat= set in config: set to 'nbest'
if($outformat eq ''){
	eval{
		$outformat = $config{'outformat'};
	} or $outformat ='nbest';
}
if($outformat !~ /^tagged|conll|parsed$/){
die "Invalid output format $outformat, valid options are:
\t senttok: plain text, one sentence per line
\t tagged: wapiti crf
\t conll: tagged conll
\t parsed: maltparser output (conll)";
}
## check if input format is a valid option, and check if it's set in config, if neither --informat nor informat= set in config: set to 'senttok'
if($informat eq ''){
	eval{
		$informat = $config{'informat'};
	} or $informat ='senttok';
}
if($informat !~ /^plain|senttok|tagged|conll|parsed$/ ){
die "Invalid input format $informat, valid options are:
\t senttok: plain text, one sentence per line (=default)
\t crf: crf instances, freeling output (morphological analysis)
\t tagged: wapiti crf
\t conll: tagged conll
\t parsed: maltparser output (conll)\n";
}
 
my $startTrans = $mapInputFormats{$informat};
print STDERR "start $startTrans\n"."end " . $mapInputFormats{$outformat}. "\n";
if($startTrans >= $mapInputFormats{$outformat}){
	die "cannot process input from format=$informat to format=$outformat (wrong direction)!!\n";
}


## check if freeling and maltparser are running on indicated ports (for maltparser: further below, before parsing starts)
# #test if squoia_server_analyzer is already listening
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
my $server_squoia = $config{'squoia_server'};
my $analyzer_client = $config{'squoia_analyzer'};
my $analyzerRunning = `ps ax | grep -v grep | grep "server_squoia.*port=$freelingPort"` ;
if($analyzerRunning eq ''){
	print STDERR "no instance of server_squoia running on port $freelingPort with config $freelingConf\n";
	print STDERR "starting server_squoia on port $freelingPort with config $freelingConf, logging to $path/logs/logcrfmorf...\n";
	system("$server_squoia -f $freelingConf --server --port=$freelingPort 2> $path/logs/logcrfmorf &");
	my $ready = `echo "test" | $analyzer_client $freelingPort 2>/dev/null`;
	while($ready eq ''){
	    print STDERR "starting server_squoia, please wait...\n";
	    sleep 10;
	    $ready = `echo "test" | $analyzer_client $freelingPort 2>/dev/null`;
	}
	print STDERR "server_squoia now ready\n";
}
if($wapitiModel eq '' or $wapitiPort eq ''){
	eval{
	  $wapitiModel = $config{'wapitiModel'}; $wapitiPort = $config{'wapitiPort'};
	}
	or die "Could not start tagging, no wapiti model or port given!\n";;
}

# ###-----------------------------------end read commandline arguments -----------------------------------------------####
# 
# ###-----------------------------------begin analysis Spanish input -----------------------------------------------####
#if($startTrans<$mapInputFormats{'senttok'})	#2)
#{ } TODO sentence tokenization

if($startTrans<$mapInputFormats{'tagged'})	#4)
{
	print STDERR "* TRANS-STEP " . $mapInputFormats{'tagged'} .") [-o tagged] tagging\n";

	### tagging: if input file given with --file or -f:
	# check if $matxin,  $wapiti and $wapitiModel are all set, otherwise exit
	eval{
		$matxin = $config{'matxin'} unless $matxin; $wapiti = $config{'wapiti'} unless $wapiti; $wapitiModel = $config{'wapitiModel'} unless $wapitiModel; $wapitiPort = $config{'wapitiPort'} unless $wapitiPort; $nec = $config{'nec'} unless $nec; $neccfg = $config{'neccfg'} unless $neccfg;
	}
	or die "Tagging failed, location of matxin, wapiti or wapiti model or port not indicated!\n";
	#print STDERR "necdir is $nec, nec cfg is $neccfg\n";
		#print STDERR "wapiti set as $wapiti, model set as $wapitiModel\n";
	if($file ne ''){
		open(CONLL,"-|" ,"cat $file | $analyzer_client $freelingPort | $wapiti/wapiti label --force -m $wapitiModel | $nec $neccfg" ) || die "tagging failed: $!\n";
#		open(CONLL,"-|" ,"cat $file | $analyzer_client $freelingPort | wapiti_client $wapitiPort"  ) || die "tagging failed: $!\n";
	}
	# if no file given, expect input on stdin
	else{
		# solution without open2, use tmp file
		my $tmp = $path."/tmp/tmp.txt";
		open (TMP, ">:encoding(UTF-8)", $tmp) or die "Can't open temporary file \"$tmp\" to write: $!\n";
		while(<>){print TMP $_;}
		open(CONLL,"-|" ,"cat $tmp | $analyzer_client $freelingPort | $wapiti/wapiti label --force -m $wapitiModel | $nec $neccfg"  ) || die "tagging failed: $!\n";
#		open(CONLL,"-|" ,"cat $tmp | $analyzer_client $freelingPort | wapiti_client $wapitiPort"  ) || die "tagging failed: $!\n";
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
	print STDERR "* TRANS-STEP " . $mapInputFormats{'conll'} .")  [-o conll] conll format\n";
	# if starting translation process from here, read file or stdin
	if($startTrans==$mapInputFormats{'tagged'}){	#4){
		if($file){
			open (FILE, "<", $file) or die "Can't open input file \"$file\" to translate: $!\n";
			$conllLines = squoia::crf2conll::main(\*FILE,$verbose);
			close(FILE);
		}
		else{
			#### convert from wapiti crf to conll for malt parser
			binmode(STDIN);
			$conllLines = squoia::crf2conll::main(\*STDIN,$verbose);
		}

	}
	else{
		#### convert from wapiti crf to conll for malt parser
		$conllLines = squoia::crf2conll::main(\*CONLL,$verbose);
		close(CONLL);
	}
	
	if($outformat eq 'conll'){
		foreach my $line (@$conllLines){
			print STDOUT $line;
		}
		exit;
	}
}


#### Check if parser server are already running
# set maltparser parameters
		if($maltPort eq ''){
			eval{
				$maltPort = $config{'maltPort'};
			} or warn  "no maltPort given, using default 1234\n";
			if($maltPort eq ''){
				$maltPort = 1234; 
			}
		}
		if($maltModel eq ''){
			eval{
				$maltModel = $config{'maltModel'};
			} or die  "Could not start parsing, no maltModel given\n";
		}
		if($maltPath eq ''){
			eval{
				$maltPath = $config{'maltPath'};
			} or die  "Could not start parsing, no path to maltparser.jar (option: maltPath) given\n";
		}
		my $maltRunning = `ps ax | grep -v grep | grep "MaltParserServer.*$maltPort"` ;
		if($maltRunning eq ''){
			print STDERR "no instance of MaltParserServer running on port $maltPort with model $maltModel\n";
			print STDERR "starting MaltParserServer on port $maltPort with model $maltModel, logging to $path/logs/log.malt...\n";
			system("java -cp $maltPath:$path/maltparser_tools/bin MaltParserServer $maltPort $maltModel 2> $path/logs/log.malt &");
			print STDERR "MaltParserServer with model = $maltModel started on port $maltPort...\n";
			while(`echo "test" |java -cp $path/maltparser_tools/bin MPClient localhost $maltPort 2>&1 | grep "Connection established"`  eq ''){
				print STDERR "starting MaltParserServer, please wait...\n";
				sleep 1;
			}
			print STDERR "MaltParserServer now ready\n";
		}
		
		
if($startTrans <$mapInputFormats{'parsed'})	#6)
{
		print STDERR "* TRANS-STEP " . $mapInputFormats{'parsed'} .")  [-o parsed] parsing\n";
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
		#open(CONLL2,"-|" ,"cat $tmp2 | desr_client $desrPort1"  ) || die "parsing failed: $!\n";
		open(CONLL2,"-|" ,"cat $tmp2 | java -cp $path/maltparser_tools/bin MPClient localhost $maltPort "  ) || die "parsing failed: $!\n";
		close(TMP2);
		
		## if output format is 'conll': print and exit
		if($outformat eq 'parsed'){
			while(<CONLL2>){print;}
			close(CONLL2);
			exit;
		}
}



# ####-----------------------------------end analysis Spanish input -----------------------------------------------####

# END{
# 	## done!! cleanup?
# }
