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

# csv:
# lemma/stem morph, occursInPrevSentence isPronoun isTopic

print "Lemma,morph1,morph2,morph3,morph4,morph5,occursInPrevSentence,isPronoun,isTopic\n";

my @sentences = $dom->getElementsByTagName('s');
for(my $i=0;$i<scalar(@sentences);$i++)
{
	my $sentence = @sentences[$i];
	
	my @subjects = $sentence->findnodes('descendant::terminal[label[text()="sntc"] or label[text()="co"] ]/children/terminal[label[text()="subj"] and not(pos[text()="DUMMY" ]) ] ');
   
    my @sorted_subjs = sort order_sort  @subjects;
   	foreach my $subj (@sorted_subjs){
		
		# for testing:
   		#print "subj ".$subj->getAttribute('id').":\t";
		
   		my $lemma = $subj->findvalue('word');
   		print lc("$lemma");
   		my @morphtags = $subj->findnodes('morph/tag');
  		if(scalar(@morphtags)>5){ print STDERR "More than 5 morphtags in word ".$subj->getAttribute('id')."\n...aborting\n"; exit(0);}
   		
   		my $printedTags =0;
   		foreach my $tag (@morphtags){
   			print ",".$tag->textContent();
   			$printedTags++;
   		}
   		while($printedTags<5){
   			print ",-";
   			$printedTags++;
   		}
   		
   		my $occursinPrevSentence=0;
   		unless($i==0){
		   		#occurs in previous sentence
		   		my $prevSentence = @sentences[$i-1];
		   		my $xpath = 'descendant::terminal/word[text()="'.$lemma.'"]';
		   		$occursinPrevSentence =  $prevSentence->exists($xpath);
		 }
		 print ",$occursinPrevSentence";
   		
		# is pronoun
		
		my $isPronoun = ($subj->findvalue('morph/tag') =~ /^Prn/) ? 1:0;
		print ",$isPronoun";   		
   		
   		#my $discourse = $subj->findvalue('discourse');
   		my $isTopic = ($subj->findvalue('discourse') eq 'TOPIC') ? 1:0;

   		print ",$isTopic\n";
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