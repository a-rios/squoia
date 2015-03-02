#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
#use open ':utf8';

#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
 use Error qw(:try);

#read xml from STDIN
#my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);
$dom->documentElement()->setAttribute( 'xmlns' , '' );

# conll: 
# 1      casa      casa         n      nc   gen=f|num=s     _       _       _       _
# number wordform  lemma        cpos   pos  morphology head edgelabel
# quechua conll
# number word      translation/-  pos  _    morphtags  head edgelabel
# new: use morphgroup-form as lemma, 
# number word      translation/-  pos  _    morphtags  head edgelabel


foreach my $sentence  ( $dom->getElementsByTagName('s'))
{

	#my %sentHash =();
   #print $sentence->getAttribute('id')."\n";
   
   # discard sentences with internally headed relative clauses.. no way to represent this in conll
   unless($sentence->exists('descendant::terminal/extHead[text() ]') or $sentence->exists('descendant::terminal[word[text() and not(text()="KAN") ] and pos[text()="DUMMY"] ]'))
   {
   
   
	   # if dummy KAN -> delete and hang children to either 'pred', 'hab', oblg
	   if($sentence->exists('descendant::terminal[word[text()="KAN"] and pos[text()="DUMMY"] ]') )
	   {
	     
	      my @KANs = $sentence->findnodes('descendant::terminal[word[text()="KAN"] and pos[text()="DUMMY"] ]');
	      
	      foreach my $KAN (@KANs){
	
		  my $pred_hab_oblg = @{$KAN->findnodes('child::children/terminal[label[text()="pred" or text()="oblg" or text()="hab"]]')}[0];   
		  # set label to pred_KAN, hab_KAN or oblg_KAN
		  my $parent = @{$KAN->findnodes('parent::children/parent::*[1]/children')}[0];
		  
		  if(!$parent){
		    print STDERR "no parent found to node: \n";
		   # print STDERR $KAN->toString()."\n\n";
		   print STDERR $sentence->toString()."\n\n";
		    exit(-1);
		  }
		  
		  # if hab, pred or oblg: make this node the head
		  # test without KAN, if oblg, hab or subj head of sentence -> clear that kan needs to be inserted
		  elsif($pred_hab_oblg){
		      my $labelstring = $pred_hab_oblg->findvalue('label/text()'); # ."_KAN";
		      &setLabel($pred_hab_oblg, $labelstring); 
		      $parent->appendChild($pred_hab_oblg);
		  
		      my @children = $KAN->findnodes('child::children/terminal');
		      my $pred_hab_oblg_children = @{$pred_hab_oblg->findnodes('children')}[0];
		      
		      # no children yet, create node
		      if(!$pred_hab_oblg_children){
			 my $newChildrenNode = XML::LibXML::Element->new( 'children' );
			$pred_hab_oblg->appendChild($newChildrenNode);
			$pred_hab_oblg_children = $newChildrenNode;
		      }
		      
		      foreach my $child (@children){
			    $pred_hab_oblg_children->appendChild($child);
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
		      #&setLabel($subj, 'subj_KAN');
		  }
	      }
		  
		
	      
	      
	   }
	   
	  # print $sentence->toString()."\n\n";
	   
	   my @terminals = $sentence->findnodes('descendant::terminal') ;
	   my $count =1;
	   
	   #set <order> in all terminals to $count, note: might have changed since we deleted Dummies!
	   foreach my $terminal (sort order_sort  @terminals){
	   		&setOrder($terminal,$count);
	   		$count++;
	   }
	   
	   
	   
	   my @terminals_sorted = sort order_sort  @terminals;
	  # foreach my $terminal (sort order_sort  @terminals){
	  for (my $i=0; $i< scalar(@terminals_sorted);$i++){
	  	  my $terminal = @terminals_sorted[$i];
	      my $wordform = $terminal->findvalue('child::word/text()');
	      my $translation =  ($terminal->findvalue('child::translation/text()') =~ /=(.+)/) ?  $terminal->findvalue('child::translation/text()') : "_";
	      $translation =~ s/^=//g;
	      my $pos = $terminal->findvalue('child::pos/text()');
	      my $morphstring;
	      my @poses= split('_',$pos);
	      my @morphtags = $terminal->findnodes('child::morph/tag');
	      if(scalar(@morphtags)>0){
			  for(my $i=0;$i<scalar(@morphtags);$i++)
			  {
			      my $tag = @morphtags[$i];
			      if($i==0){
				$morphstring .= @poses[$i]."=".$tag->textContent;
			      }
			      else{
				$morphstring .= "|".@poses[$i]."=".$tag->textContent;
				}
			  }
			  # add translation if present
			  if($translation ne '_'){
			  	$morphstring .= '|trans='.$translation;
			  }
	      }
	      else{
	        $morphstring =  ($translation eq '_') ?  "_" : "trans=".$translation;
	      }
	      my $head;
	      if($terminal->exists('parent::children/parent::terminal')){
		$head =  $terminal->findvalue('parent::children/parent::terminal/order/text()');
		}
	      else{
		$head = scalar(@terminals)+1;
	      }
	      
	      my $label = $terminal->findvalue('child::label/text()');
	      my $order = $terminal->findvalue('child::order/text()');
	   
	      # if no artificial root:
#	   	  if($terminal->exists('parent::children/preceding-sibling::cat')){
#	   	  	$head=0;
#	   	  }
	   	  
	      #print "$order\t$wordform\t$translation\t$pos\t_\t$morphstring\t$head\t$label\t_\t_\n";
	      print "$order\t$wordform\t_\t$pos\t$pos\t$morphstring\t$head\t$label\t_\t_\n";
	   
	#     print $terminal->toString."\n";
	#     print "--------------------------------------\n";
	     # $count++;
	   }
	
	 # if no artificial root:
	 #print "\n";
	 
	 # else, with artificial root:
	 print "$count\tVROOT\t_\t_\t_\t_\t0\tsentence\t_\t_\n\n";
   }
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


sub setOrder{
	my $node = $_[0];
	my $ordertext = $_[1];
	my $order= @{$node->getChildrenByLocalName('order')}[0];
	$order->removeChildNodes();
	$order->appendText($ordertext);
}