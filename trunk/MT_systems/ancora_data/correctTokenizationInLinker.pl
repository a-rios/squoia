#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
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
		my @linkerSP  = $sentence->findnodes('descendant::CHUNK[(@type="grup-sp" or @type="coor-sp") and NODE[@lem="para"] and CHUNK[@type="coor-v" or @type="grup-verb" and NODE[@lem="que" and @mi="CS"]]  ] ');
		foreach my $linker (@linkerSP){
			
			my $linkerParent = $linker->parentNode();
			$linkerParent->removeChild($linkerParent);
			
			my $verbChild = @{$linker->findnodes( 'CHUNK[@type="coor-v" or @type="grup-verb" and NODE[@lem="que" and @mi="CS"]][1]' )}[0];
			my ($QUE) = $verbChild->findnodes('NODE/NODE[@lem="que" and @mi="CS"]');
			$QUE->setAttribute('lem', 'para_que');
			$QUE->setAttribute('form', 'para_que');
			
			my ($PARA) = $linker->findnodes('NODE[@lem="para"]');
			$linker->removeChild($PARA);
			my @children = $linker->childNodes();
			
			foreach my $child (@children){
				unless($child == $verbChild){
					$verbChild->appendChild($child);
				}
			}
			
			$linkerParent->appendChild($verbChild);
			print STDERR $linker->getAttribute('ord')."\n";
			print STDERR $verbChild->getAttribute('ord')."\n";
			print STDERR $verbChild->toString."\n";
		}
		
		#my @linkerADV  = $sentence->findnodes('descendant::CHUNK[(@type="sadv" or @type="coor-sadv") and NODE[@lem="mientras"] and CHUNK[@type="coor-v" or @type="grup-verb" and NODE[@lem="que" and @mi="CS"]]  ] ');
			
		my @linkerADV  = $sentence->findnodes('descendant::CHUNK[@type="sadv" or @type="coor-sadv"  ] ');
		
		foreach my $linker (@linkerADV)
		{
			print $linker->toString()."\n";
			my $linkerParent = $linker->parentNode();
			$linkerParent->removeChild($linkerParent);
			

			my $verbChild = @{$linker->findnodes( 'CHUNK[@type="coor-v" or @type="grup-verb" and NODE[@lem="que" and @mi="CS"]][1]' )}[0];
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
			
			print STDERR $linker->getAttribute('ord')."\n";
			print STDERR $verbChild->getAttribute('ord')."\n";
			print STDERR $verbChild->toString."\n";
		}
}
my $docstring = $dom->toString(3);
#print $dom->actualEncoding();
#print STDOUT $docstring;