#!/usr/bin/perl


use strict;
use utf8;
use XML::LibXML;
binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
#binmode (STDERR);
use Getopt::Long;



#	Usage:  perl quzconll2pml.pl -s pmlscheme -n name (id)\n";
my $helpstring = "Usage: $0 [options]
available options are:
--help|-h: print this help
--schema|-s: pml schema
--name|-n: name (corpus id)\n";

my $schema;
my $name;
my $help;

GetOptions(
	# general options
    'help|h'     => \$help,
    'schema|s=s' => \$schema,
    'name|n=s' => \$name,
) or die "Incorrect usage!\n $helpstring";

if($help or (!$schema or !$name)){ print STDERR $helpstring; exit;}


# read conll file and create xml (still flat)
my $scount=1; #sentence ord
my %docHash;

my $dom = XML::LibXML->createDocument ('1.0', 'UTF-8');
my $root = $dom->createElementNS( "", "quechua_corpus" );
$dom->setDocumentElement( $root );

my $head = XML::LibXML::Element->new( 'head' );
my $body = XML::LibXML::Element->new( 'body' );
my $schemanode = XML::LibXML::Element->new( 'schema' );
$schemanode->setAttribute('href', $schema);


$root->appendChild($head);
$head->appendChild($schemanode);
$root->appendChild($body);


my $sentence; # actual sentence
my $actual_nt_children;


#read in conll from stdin
my $scount=1;

while(<>){
	
	my $line = $_;
	#skip empty line
	if($line =~ /^\s*$/)
	{
      $scount++;
      undef $sentence;
      undef $actual_nt_children;
	}
	elsif($line =~ /\tVROOT\t/){
		my ($ord, @rest) = split(/\t/,$line);
		$docHash{"s".$scount."_headnode"}= $ord;
	}
	# word with analysis
	else
	{
	 	#create a new sentence node 
	     if(!$sentence) 
	     {
		     $sentence = XML::LibXML::Element->new( 's' );
		     $sentence->setAttribute( 'id', "s".$scount );
		     $body->appendChild($sentence);
		     my $saphi = XML::LibXML::Element->new( 'saphi' );
		     $sentence->addChild($saphi);
		     my $nonterminal = XML::LibXML::Element->new( 'nonterminal' );	     
		     $saphi->appendChild($nonterminal);	     
		     $nonterminal->setAttribute( 'id', "s".$scount."_VROOT" );
		     my $cat = XML::LibXML::Element->new( 'cat' );
		     $cat->appendText('VROOT');
		     $nonterminal->appendChild($cat);
		     $actual_nt_children = XML::LibXML::Element->new( 'children' );
		     $nonterminal->appendChild($actual_nt_children);
	     }
	     
	     # create a new word node and attach it to children of nonterminal
	     my $terminal = XML::LibXML::Element->new( 'terminal' );
	     $actual_nt_children->appendChild($terminal);
 		 my ($order, $wordform, $emtpy1, $pos, $emtpy2, $morph, $head, $label, $emtpy3, $emtpy4) = split('\t',$line);
	
	  
	  	 my $id = "s".$scount."_".$order;
	     $terminal->setAttribute( 'id', $id );
	     $terminal->setAttribute( 'head', $head );
		 my $ordernode = XML::LibXML::Element->new( 'order' );
		 my $wordnode = XML::LibXML::Element->new( 'word' );
		 my $posnode = XML::LibXML::Element->new( 'pos' );
		 my $labelnode  = XML::LibXML::Element->new( 'label' );
		 
		 $ordernode->appendText($order);
		 $wordnode->appendText($wordform);
		 $posnode->appendText($pos);
		 $labelnode->appendText($label);
		 
		 $terminal->appendChild($ordernode);
		 $terminal->appendChild($wordnode);
		 $terminal->appendChild($posnode);
		 $terminal->appendChild($labelnode);
		 
		 
		 # get morphs and translation
		 my $hasMorphs=0;
		 my $morphnode;
		 unless($morph eq "_"){
		 	my @value_pairs = split(/\|/, $morph);
		 	foreach my $valuepair (@value_pairs){
		 		my ($att,$value) = split('=', $valuepair);
		 		
		 		if($att eq 'trans'){
		 			my $translation  = XML::LibXML::Element->new( 'translation' );
		 			$translation->appendText("=".$value);
		 			$terminal->appendChild($translation);
		 		}
		 		else{
		 			my $tag  = XML::LibXML::Element->new( 'tag' );
		 			$tag->appendText($value);
		 			if($hasMorphs==1){
		 				$morphnode->appendChild($tag);
		 			}
		 			else{
		 				$morphnode  = XML::LibXML::Element->new( 'morph' );
		 				$terminal->appendChild($morphnode);
		 				$morphnode->appendChild($tag);
		 				$hasMorphs=1;
		 			}
		 		}
		 	}
		 }
	
	
	    # print "$eaglesTag\n";
	     # store node in hash, key=wordId in order to resolve dependencies
	     $docHash{$id}= $terminal;
	    # print "node id $id\n";
	     
	     }
}
	
	
# build dependencies:
foreach my $sentence ($dom->getElementsByTagName('s')){
	my $s_id = $sentence->getAttribute('id');
	my $headnodenumber = $docHash{$s_id."_headnode"};
	#print STDERR "headnode in sentence $s_id is $headnodenumber\n";
	
	
	my @terminals = $sentence->findnodes('saphi/nonterminal/children/terminal');
	
	
	foreach my $terminal (@terminals){
		my $id = $terminal->getAttribute('id');
		my $head = $terminal->getAttribute('head');
		$terminal->removeAttribute('head');
		unless($head == $headnodenumber)
		{
			my $head_id=$s_id."_$head";
			my $parent = $docHash{$head_id};
			
			my $parent_children;
			if(!$parent->exists('children')){
				$parent_children  = XML::LibXML::Element->new( 'children' );
				$parent->appendChild($parent_children);
			}
			else{
				($parent_children) = $parent->findnodes('child::children');
			}
			#print STDERR "my id is $id, my head is $head, node= ".$parent->toString()."\n";
			eval{
				$parent_children->appendChild($terminal);
			}
			or do{
				print STDERR "cannot append $id to $head_id, invalid tree in sentence \n".$sentence->toString()."\n";
				exit;
			}
		}
		
		
		
	}
}
	


# print  xml to stdout
$root->setAttribute('xmlns', 'http://ufal.mff.cuni.cz/pdt/pml/');
$root->setAttribute('id', $name);
my $docstring = $dom->toString(1);
print STDOUT $docstring;

