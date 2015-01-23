#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
 use Error qw(:try);

#read xml from STDIN
#my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

# conll: 
# number wordform  lemma cpos pos morphology head edgelabel
# quechua conll
# number word  translation/-  pos - morphtags head edgelabel


foreach my $sentence  ( $dom->getElementsByTagName('s'))
{

   my $hasDummy = 0;
   # if dummy KAN -> delete and hang children to either 'pred', 'hab', oblg
   if($sentence->exists('descendant::terminal[word[text()="KAN"] and pos[text()="DUMMY"] ]') )
   {
      $hasDummy=1;
      my @KANs = $sentence->findnodes('descendant::terminal[word[text()="KAN"] and pos[text()="DUMMY"] ]');
      
      foreach my $KAN (@KANs){

	  my $pred_hab_oblg = @{$KAN->findnodes('child::children/terminal[label[text()="pred" or text()="oblg" or text()="hab"]]')}[0];   
	  my $parent = @{$KAN->findnodes('parent::children/parent::*[1]/children')}[0];
	  
	  # if hab, pred or oblg: make this node the head
	  if($pred_hab_oblg){
	      $parent->appendChild($pred_hab_oblg);
	  
	      my @children = $KAN->findnodes('child::children/terminal');
	      foreach my $child (@children){
		  $pred_hab_oblg->appendChild($child);
	      }
	      $parent->removeChild($KAN);
	  }
	  # if existential clause, make subj the head and annotate as subj_KAN
	  else{
	      my $subj = @{$KAN->findnodes('child::children/terminal[label[text()="subj"]]')}[0]; 
	      $parent->appendChild($subj);
	      my @children = $KAN->findnodes('child::children/terminal');
	      foreach my $child (@children){
		  $parent->appendChild($child);
	      }
	      $parent->removeChild($KAN);
	      &setLabel($subj, 'subj_KAN');
	  }
      }
	  
	
      
      
   }
   
  # print $sentence->toString()."\n\n";
   
   my @terminals = $sentence->findnodes('descendant::terminal') ;
   foreach my $terminal (sort order_sort  @terminals){
   
      my $ord = $terminal->findvalue('child::order/text()');
      my $wordform = $terminal->findvalue('child::word/text()');
      my $translation = $terminal->findvalue('child::translation/text()');
      my $pos = $terminal->findvalue('child::pos/text()');
      my $morphstring;
      my @poses= split('_',$pos);
      my @morphtags = $terminal->findnodes('child::morph/tag');
      if(scalar(@morphtags)>0){
	  for(my $i=0;$i<scalar(@morphtags);$i++){
	      my $tag = @morphtags[$i];
	      if($i==0){
		$morphstring .= @poses[$i]."=".$tag->textContent;
	      }
	      else{
		$morphstring .= "|".@poses[$i]."=".$tag->textContent;
		}
	  }
      }
      else{
	  $morphstring = "_";
      }
      my $head;
      if($terminal->exists('parent::children/parent::terminal')){
	$head =  $terminal->findvalue('parent::children/parent::terminal/order/text()');
	}
      else{
	$head = scalar(@terminals)+1;
      }
      
      my $label = $terminal->findvalue('child::label/text()');
   
      print "$ord\t$wordform\t$translation\t$pos\t_\t$morphstring\t$head\t$label\n";
   
#     print $terminal->toString."\n";
#     print "--------------------------------------\n";
   
   }

 print  (scalar(@terminals)+1);
 
 
 print "\tVROOT\t_\t_\t_\t_\t0\tsentence\n\n";
}


# $a,$b -> terminal nodes
sub order_sort {
	my ($order_a) = $a->findvalue('child::order/text()');
	my ($order_b) = $b->findvalue('child::order/text()');
	
	#print "order a: $order_a, order b: $order_b\n";
	
	if($order_a > $order_b){
		return 1;
	}
	elsif($order_b > $order_a){
		return -1;
	}
	return 0;
}

sub setLabel{
	my $node = $_[0];
	my $labeltext = $_[1];
	my $label= @{$node->getChildrenByLocalName('label')}[0];
	$label->removeChildNodes();
	$label->appendText($labeltext);
}