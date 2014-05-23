#!/usr/bin/perl

# addFutureAux: add the corresponding form of the verb "werden" to express the future tense in German (always analytic; often synthetic in Spanish)
# example: disminuirán => werden abnehmen
# Input:
#    <CHUNK ref="2" type="VP" alloc="17" si="top">
#      <NODE ref="3" alloc="17" slem="disminuir" smi="VMIF3P0" sform="disminuirán" UpCase="none" lem="ab|nehmen" pos="VVFIN" tense="Fut" mi="3.Pl.Pres.Ind">
# but also:
#    <CHUNK ref="1" type="VP" alloc="0" si="top">
#      <NODE ref="2" alloc="9" slem="comer" smi="VMN0000" sform="comer" UpCase="none" lem="essen" pos="VVINF" mi="Inf">
#        <NODE ref="1" alloc="0" slem="poder" smi="VMIF1P0" sform="Podremos" UpCase="none" lem="können" pos="VMFIN" tense="Fut" mi="1.Pl.Pres.Ind">

# Output:
#    <CHUNK ref="2" type="VP" alloc="17" si="top"">
#      <NODE ref="3" alloc="17" slem="disminuir" smi="VMIF3P0" sform="disminuirán" UpCase="none" lem="ab|nehmen" pos="VVINF" mi="Inf">
#       <NODE ref="-1" alloc="17" slem="disminuir" smi="VMIF3P0" sform="disminuirán" UpCase="none" lem="werden" pos="VAFIN" mi="3.Pl.Pres.Ind"/>
# and also:
#    <CHUNK ref="1" type="VP" alloc="0" si="top">
#      <NODE ref="2" alloc="9" slem="comer" smi="VMN0000" sform="comer" UpCase="none" lem="essen" pos="VVINF" mi="Inf">
#        <NODE ref="1" alloc="0" slem="poder" smi="VMIF1P0" sform="Podremos" UpCase="none" lem="können" pos="VMINF" mi="Inf">
#         <NODE ref="-1" alloc="0" slem="pode" smi="VMIF1P0" sform="Podremos" UpCase="none" lem="werden" pos="VAFIN" mi="3.Pl.Pres.Ind"/>

package squoia::esde::addFutureAux;

use strict;

sub main{
	my $dom = ${$_[0]};
	
	my @specialnodes = $dom->findnodes('//CHUNK[@type="VP"]/NODE/descendant-or-self::NODE[@tense="Fut"]');
	foreach my $node (@specialnodes) {
		$node->removeAttribute('tense');
		my $newNode = $node->cloneNode(0);
		$newNode->setAttribute('ref','-1');
		$newNode->setAttribute('pos','VAFIN');
		$newNode->setAttribute('lem','werden');
		$node->addChild($newNode);
		my $origpos = $node->getAttribute('pos');
		$origpos =~ s/FIN/INF/;
		$node->setAttribute('pos',$origpos);
		$node->setAttribute('mi','Inf');
	}
}

1;
