#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/../util.pl";


#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

my @sentenceList = $dom->getElementsByTagName('SENTENCE');

foreach my $sentence (@sentenceList)
{
		# para que, sin que, hasta que, desde que
		my @linkerSP  = $sentence->findnodes('descendant::CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="para" or @lem="sin" or @lem="desde" or @lem="hasta"] and CHUNK[(@type="coor-v" or @type="grup-verb") and ( NODE[NODE[@lem="que" and @mi="CS"]] or NODE[@lem="que" and @mi="CS"] ) ]  ] ');
		#my @linkerSPiula = $sentence->findnodes('descendant::CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="para" or @lem="sin"]  and ( NODE[NODE[@lem="que" and @mi="CS"]] or NODE[@lem="que" and @mi="CS"] )  and NODE/NODE/CHUNK[(@type="coor-v" or @type="grup-verb") ]  ] ');
		
		foreach my $linker (@linkerSP)
		{
			#print STDERR $linker->toString()."\n";
			my $linkerParent = $linker->parentNode();
			if($linkerParent)
			{
				#$linkerParent->removeChild($linkerParent);
				$linkerParent->removeChild($linker);
				
				my $verbChild = @{$linker->findnodes( 'CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
				# iula:
				#my $verbChild = @{$linker->findnodes( 'NODE/NODE[@lem="que" and @mi="CS"]/CHUNK[(@type="coor-v" or @type="grup-verb")][1]' )}[0];
			#	print STDERR $verbChild->toString()."\n";
				
				my ($QUE) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"]');
				# iula:
				#my ($QUE) = $linker->findnodes('NODE/NODE[@lem="que" and @mi="CS"]');
				if($QUE && $linker->exists('NODE[@lem="para"]')){
					$QUE->setAttribute('lem', 'para_que');
					$QUE->setAttribute('form', 'para_que');
				}
			    elsif($QUE && $linker->exists('NODE[@lem="sin"]')){
					$QUE->setAttribute('lem', 'sin_que');
					$QUE->setAttribute('form', 'sin_que');
				}
				elsif($QUE && $linker->exists('NODE[@lem="desde"]')){
					$QUE->setAttribute('lem', 'desde_que');
					$QUE->setAttribute('form', 'desde_que');
				}
				elsif($QUE && $linker->exists('NODE[@lem="hasta"]')){
					$QUE->setAttribute('lem', 'hasta_que');
					$QUE->setAttribute('form', 'hasta_que');
				}
				
				my ($PARA) = $linker->findnodes('NODE[@lem="para" or @lem="sin"]');
				$linkerParent->appendChild($verbChild);
				if($PARA){
					$linker->removeChild($PARA);
					my @children = $linker->childNodes();
					#iula:
					#my @children = $PARA->childNodes();
					
					foreach my $child (@children)
					{
						unless($child == $verbChild){
							$verbChild->appendChild($child);
						}
					}
				}
				
				
				
	#			print STDERR $linker->getAttribute('ord')."\n";
	#			print STDERR $verbChild->getAttribute('ord')."\n";
	#			print STDERR $verbChild->toString."\n";
			}
		}
		
		# mientras_que
		my @linkerADV  = $sentence->findnodes('descendant::CHUNK[(@type="sadv" or @type="coor-sadv") and NODE[@lem="mientras"] and CHUNK[(@type="coor-v" or @type="grup-verb") and ( NODE[NODE[@lem="que" and @mi="CS"]] or NODE[@lem="que" and @mi="CS"] ) ]] ');		
		foreach my $linker (@linkerADV)
		{
			#print $linker->toString()."\n";
			my $linkerParent = $linker->parentNode();
			if($linkerParent)
			{
				
				#$linkerParent->removeChild($linkerParent);
				$linkerParent->removeChild($linker);
				
	
				my $verbChild = @{$linker->findnodes( 'CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
				my ($QUE) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"]');
				if($QUE)
				{
					$QUE->setAttribute('lem', 'mientras_que');
					$QUE->setAttribute('form', 'mientras_que');
				}
					
				my ($MIENTRAS) = $linker->findnodes('NODE[@lem="mientras"]');
				if($MIENTRAS)
				{
					$linker->removeChild($MIENTRAS);
					my @children = $linker->childNodes();
					
					foreach my $child (@children){
						unless($child == $verbChild){
							$verbChild->appendChild($child);
						}
					}
				}
				
				$linkerParent->appendChild($verbChild);
	#			print STDERR $linker->getAttribute('ord')."\n";
	#			print STDERR $verbChild->getAttribute('ord')."\n";
	#			print STDERR $verbChild->toString."\n";
			}
		}
		
		# el hecho de que
		my @hechos =  $sentence->findnodes('descendant::CHUNK[(@type="sn" or @type="coor-n") and NODE[@form="hecho"] and CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="de"] and CHUNK[@type="coor-v" or @type="grup-verb" ] and descendant::NODE[@lem="que" and @mi="CS"] ]] ');		
		
		foreach my $hecho (@hechos)
		{
			my $verbChild = @{$hecho->findnodes( 'CHUNK[(@type="grup-sp" or @tye="coor-sp") and NODE[@lem="de"]]/CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
			my ($linker) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"][1]');
			if($linker)
			{
				$linker->setAttribute('lem', 'el_hecho_de_que');
				$linker->setAttribute('form', 'el_hecho_de_que');
				my $hechoParent = $hecho->parentNode();
				
				my ($nounHecho) = $hecho->findnodes('NODE[@form="hecho"]');
				$hecho->removeChild($nounHecho);
				my ($deSP) = $hecho->findnodes('CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="de"] ]');
				$hecho->removeChild($deSP);
				
				my @children = $hecho->childNodes();
				foreach my $child (@children){
					unless($child == $verbChild){
						$verbChild->appendChild($child);
					}
				}
				
				$hechoParent->appendChild($verbChild);
				$hechoParent->removeChild($hecho);
				
				#print STDERR $hecho->getAttribute('ord')."\n";
				#print $verbChild->toString()."\n";
			}
		}

#		#iula		
#		my @hechos =  $sentence->findnodes('descendant::CHUNK[(@type="sn" or @type="coor-n") and NODE[@form="hecho"] and CHUNK[(@type="coor-v" or @type="grup-verb") and CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="de"]/NODE[@lem="que" and starts-with(@mi,"PR")] ] ]] ');		
#		
#		foreach my $hecho (@hechos)
#		{  print STDERR $hecho->toString()."\n";
#			unless($hecho->exists('parent::CHUNK[@type="grup-sp or @type="coor-sp"]'))
#			{
#			my $verbChild = @{$hecho->findnodes( 'CHUNK[(@type="coor-v" or @type="grup-verb") and CHUNK/NODE/NODE[@lem="que" and starts-with(@mi,"PR")]][1]' )}[0];
#			print STDERR $verbChild->toString()."\n";
#			my ($linker) = $verbChild->findnodes('CHUNK[@type="grup-sp"]/NODE/NODE[@lem="que"][1]');
#			if($linker)
#			{
#				$linker->setAttribute('lem', 'el_hecho_de_que');
#				$linker->setAttribute('form', 'el_hecho_de_que');
#				my $hechoParent = $hecho->parentNode();
#				
#				my ($nounHecho) = $hecho->findnodes('NODE[@form="hecho"]');
#				$hecho->removeChild($nounHecho);
#				my ($deSP) = $verbChild->findnodes('CHUNK[@type="grup-sp" and NODE[@lem="de"] ]');
#				$verbChild->removeChild($deSP);
#				
#				$hechoParent->appendChild($verbChild);
#				my @children = $hecho->childNodes();
#				foreach my $child (@children){
#					unless($child == $verbChild){
#						$verbChild->appendChild($child);
#					}
#				}
#				
#				
#				$hechoParent->removeChild($hecho);
#				
#				#print STDERR $hecho->getAttribute('ord')."\n";
#				#print $verbChild->toString()."\n";
#			}
#		}	
		
		# antes de que, después de que
		my @antes =  $sentence->findnodes('descendant::CHUNK[(@type="sadv" or @type="coor-sadv") and NODE[@lem="antes" or @lem="después"] and CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="de"] and CHUNK[@type="coor-v" or @type="grup-verb" ] and descendant::NODE[@lem="que" and @mi="CS"] ]] ');		

		foreach my $ante (@antes)
		{
			#print STDERR $ante->getAttribute('ord')."\n";
			my $verbChild = @{$ante->findnodes( 'CHUNK[(@type="grup-sp" or @tye="coor-sp") and NODE[@lem="de"]]/CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
			my ($linker) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"][1]');
			if($linker)
			{
				#print STDERR "lem:".$ante->getAttribute('lem')."\n";
				if($ante->findvalue('child::NODE/@lem') eq 'antes')
				{
					$linker->setAttribute('lem', 'antes_de_que');
					$linker->setAttribute('form', 'antes_de_que');
				}
				elsif($ante->findvalue('child::NODE/@lem') eq 'después'){
					$linker->setAttribute('lem', 'después_de_que');
					$linker->setAttribute('form', 'después_de_que')
				}
				my $anteParent = $ante->parentNode();
				
				my ($advAntes) = $ante->findnodes('NODE[@lem="antes" or @lem="después"]');
				$ante->removeChild($advAntes);
				my ($deSP) = $ante->findnodes('CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="de"] ]');
				$ante->removeChild($deSP);
				
				my @children = $ante->childNodes();
				foreach my $child (@children){
					unless($child == $verbChild){
						$verbChild->appendChild($child);
					}
				}
				
				$anteParent->appendChild($verbChild);
				$anteParent->removeChild($ante);
			}
		}
		
		# y cuando
		my @CoorV =  $sentence->findnodes('descendant::CHUNK[@type="coor-v" and NODE[NODE[@lem="y" and @mi="CC"] ] ] ');	
		
		foreach my $coV (@CoorV)
		{ #print STDERR $sentence->getAttribute('ord').": ".$coV->getAttribute('ord')."\n";
			my ($y) = $coV->findnodes('NODE/NODE[@lem="y"]');
			if($y)
			{  
				my $yOrd = $y->getAttribute('ord');
				my @possCuandos = $coV->findnodes('descendant::NODE[@lem="cuando" and @mi="CS"]');
				foreach my $cuando (@possCuandos)
				{
					if($cuando->getAttribute('ord') == $yOrd+1)
					{
						$cuando->setAttribute('lem', 'y_cuando');
						$cuando->setAttribute('form', 'y_cuando');
						my $yParent = $y->parentNode();
						$yParent->removeChild($y);
					}
				}
			}

			
			
		}	
		
		
		
}
my $docstring = $dom->toString(3);
#print $dom->actualEncoding();
print STDOUT $docstring;
