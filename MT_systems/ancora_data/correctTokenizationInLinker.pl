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
		# para que, sin que
		my @linkerSP  = $sentence->findnodes('descendant::CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="para" or @lem="sin"] and CHUNK[(@type="coor-v" or @type="grup-verb") and ( NODE[NODE[@lem="que" and @mi="CS"]] or NODE[@lem="que" and @mi="CS"] ) ]  ] ');
		foreach my $linker (@linkerSP){
			
			my $linkerParent = $linker->parentNode();
			#$linkerParent->removeChild($linkerParent);
			$linkerParent->removeChild($linker);
			
			my $verbChild = @{$linker->findnodes( 'CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
			my ($QUE) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"]');
			if($linker->exists('NODE[@lem="para"]')){
				$QUE->setAttribute('lem', 'para_que');
				$QUE->setAttribute('form', 'para_que');
			}
		    elsif($linker->exists('NODE[@lem="sin"]')){
				$QUE->setAttribute('lem', 'sin_que');
				$QUE->setAttribute('form', 'sin_que');
			}
			
			my ($PARA) = $linker->findnodes('NODE[@lem="para" or @lem="sin"]');
			$linker->removeChild($PARA);
			my @children = $linker->childNodes();
			
			foreach my $child (@children){
				unless($child == $verbChild){
					$verbChild->appendChild($child);
				}
			}
			
			$linkerParent->appendChild($verbChild);
#			print STDERR $linker->getAttribute('ord')."\n";
#			print STDERR $verbChild->getAttribute('ord')."\n";
#			print STDERR $verbChild->toString."\n";
		}
		
		# mientras_que
		my @linkerADV  = $sentence->findnodes('descendant::CHUNK[(@type="sadv" or @type="coor-sadv") and NODE[@lem="mientras"] and CHUNK[(@type="coor-v" or @type="grup-verb") and ( NODE[NODE[@lem="que" and @mi="CS"]] or NODE[@lem="que" and @mi="CS"] ) ]] ');		
		foreach my $linker (@linkerADV)
		{
			#print $linker->toString()."\n";
			my $linkerParent = $linker->parentNode();
			#$linkerParent->removeChild($linkerParent);
			$linkerParent->removeChild($linker);
			

			my $verbChild = @{$linker->findnodes( 'CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
			my ($QUE) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"]');
			$QUE->setAttribute('lem', 'mientras_que');
			$QUE->setAttribute('form', 'mientras_que');
			
			my ($MIENTRAS) = $linker->findnodes('NODE[@lem="mientras"]');
			$linker->removeChild($MIENTRAS);
			my @children = $linker->childNodes();
			
			foreach my $child (@children){
				unless($child == $verbChild){
					$verbChild->appendChild($child);
				}
			}
			
			$linkerParent->appendChild($verbChild);
#			print STDERR $linker->getAttribute('ord')."\n";
#			print STDERR $verbChild->getAttribute('ord')."\n";
#			print STDERR $verbChild->toString."\n";
		}
		
		# el hecho de que
		my @hechos =  $sentence->findnodes('descendant::CHUNK[(@type="sn" or @type="coor-n") and NODE[@form="hecho"] and CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="de"] and CHUNK[@type="coor-v" or @type="grup-verb" ] and descendant::NODE[@lem="que" and @mi="CS"] ]] ');		
		
		foreach my $hecho (@hechos){
			my $verbChild = @{$hecho->findnodes( 'CHUNK[(@type="grup-sp" or @tye="coor-sp") and NODE[@lem="de"]]/CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
			my ($linker) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"][1]');
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
		
		# antes de que
		my @antes =  $sentence->findnodes('descendant::CHUNK[(@type="sadv" or @type="coor-sadv") and NODE[@lem="antes"] and CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="de"] and CHUNK[@type="coor-v" or @type="grup-verb" ] and descendant::NODE[@lem="que" and @mi="CS"] ]] ');		

		foreach my $ante (@antes){
			#print STDERR $ante->getAttribute('ord')."\n";
			my $verbChild = @{$ante->findnodes( 'CHUNK[(@type="grup-sp" or @tye="coor-sp") and NODE[@lem="de"]]/CHUNK[(@type="coor-v" or @type="grup-verb") and descendant::NODE[@lem="que" and @mi="CS"]][1]' )}[0];
			my ($linker) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"][1]');
			$linker->setAttribute('lem', 'antes_de_que');
			$linker->setAttribute('form', 'antes_de_que');
			my $anteParent = $ante->parentNode();
			
			my ($advAntes) = $ante->findnodes('NODE[@lem="antes"]');
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
