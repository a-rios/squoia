#!/usr/bin/perl

# use with perl -CS, else unicode chars wont match

use strict;
use utf8;
binmode ':utf8';

my $count_word=1;
my $count_sent=1;
my %headdix = ();
my %sents_ancora =();

my %mapMonths = ( 
	'enero' => '01',
	'febrero' => '02',
	'marzo' => '03',
	'abril' => '04',
	'mayo' => '05',
	'junio' => '06',
	'julio' => '07',
	'agosto' => '08',
	'septiembre' => '09',
	'octubre' => '10',
	'noviembre' => '11',
	'diciembre' => '12'
);


while(<>){
	
	if($_ =~ /^$/){
		$count_sent++;
		$count_word =1;
	}
	else{
			my ($linenr,$word,$lem,$cpos,$pos,$morphs,$head,$dep,$x,$y) = split('\t',$_);
			
				#save original tokid with word -> tokid of word will be the acutal id
				my $headkey = "s".$count_sent.":".$linenr;
				my $originallinenr = $linenr;			
				
				my %word = ( tokid => $linenr,
							 word => $word,
							 lem => $lem,
							 cpos => $cpos,
							 pos => $pos,
							 morphs => $morphs,
							 head => $head,
							 dep => $dep,
							 originaltokid=> $originallinenr
				);
				
				#print STDERR "saved: $word_a, tokid: $linenr, with head $head, linenr was $linenr, prev elliptic was $prevelliptic with key $headkey\n";
				
				$headdix{$headkey} = \%word;
				$sents_ancora{$count_sent}{$count_word} = \%word;
				$count_word++;
	}
}

print STDERR "read $count_sent sentences\n";

my $printedSents =1;
foreach my $s (sort { $a <=> $b } keys %sents_ancora){
	my $ancora_sentence = $sents_ancora{$s};
	my $prevInserted=0;
	my $new_sentence;
	foreach my $linenr (sort {$a <=> $b} keys %{$ancora_sentence}){

		my $word = $ancora_sentence->{$linenr};

		if($word->{'pos'} eq 'W' && $word->{'word'} =~  /\_/){
			my @tokens = split(/\_/,$word->{'word'});
			my $length = scalar(@tokens);
			$linenr += $prevInserted;
			$word->{'tokid'} = $linenr;
			
			my $printedNormally=0;
			#print STDERR "tokens @tokens, $length\n";
			# case: digit+horas 12:30_horas
			if($length==2 && @tokens[0] =~ /[\d\:\.]+/ && lc(@tokens[1]) eq 'horas')
			{
				my %numberword = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => @tokens[0],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $word->{'tokid'}+1,
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %horas = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'hora',
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=f|num=p|postype=common|eagles=NCFP000',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
				# set possible dependents to 'horas', not number
				my $headkey1 = "s".$s.":".$word->{'tokid'};
				$headdix{$headkey1} = \%horas;
				$new_sentence->{$linenr} = \%numberword;
				$new_sentence->{$linenr+1} = \%horas;
			
				
			}
			# case: year_number, año_2003, año_1792, año_93, año_2.003
			# and case: day_number, día_12
			# and case: años_90
			elsif($length==2 &&   lc(@tokens[0]) =~ /^año|años|día$/ && @tokens[1] =~ /[\d\.]+|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa/)
			{
				my %anio = (tokid => $word->{'tokid'},
								 word => @tokens[0],
								 cpos => 'n',
								 pos => 'NC',
								 head => $word->{'head'},
								 dep => $word->{'dep'},
								 originaltokid=> $word->{'tokid'},
					);
				
				if(lc(@tokens[0]) =~ /^año$/){
					$anio{'lem'} = 'año';
					$anio{'morphs'} = 'gen=m|num=s|postype=common|eagles=NCMS000';
				}
				elsif(lc(@tokens[0]) =~ /^años$/){
					$anio{'lem'} = 'año';
					$anio{'morphs'} = 'gen=m|num=s|postype=common|eagles=NCMP000';
				}
				else{
					$anio{'lem'} = 'día';
					$anio{'morphs'} = 'gen=m|num=p|postype=common|eagles=NCMP000';
				}
				my %numberword = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => lc(@tokens[1]),
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $anio{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				$new_sentence->{$linenr} = \%anio;
				$new_sentence->{$linenr+1} = \%numberword;

			}
			# case day, month, year: 10_de_agosto_de_1998, 
			elsif($length==5 && @tokens[0] =~ /^[\d]+|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|veinte|treinta$/ && lc(@tokens[1]) eq 'de' && lc(@tokens[2]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/ && lc(@tokens[3]) =~ /^de|del$/  && @tokens[4] =~ /\d\d\d\d/)
			{ 
		 		my $de2morph = (lc(@tokens[3]) eq 'de') ? 'postype=preposition|eagles=SPS00' :  'gen=c|num=m|postype=preposition|contracted=yes|eagles=SPCMS';
		 		
				my %numberword = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => lc(@tokens[0]),
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $word->{'head'},
							 dep => $word->{'dep'},,
							 originaltokid=> $word->{'tokid'}
				);
				my %de = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %month = ( tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => "[??:??/".$mapMonths{lc(@tokens[2])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %de2 = (tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => $de2morph,
							 head => $month{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %year = ( tokid => $word->{'tokid'}+4,
							 word => @tokens[4],
							 lem => "[??:??/??/".@tokens[4].":??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de2{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%numberword;
				$new_sentence->{$linenr+1} = \%de;
				$new_sentence->{$linenr+2} = \%month;
				$new_sentence->{$linenr+3} = \%de2;
				$new_sentence->{$linenr+4} = \%year;
				
				#print STDERR "tokens: @tokens, number: ".$numberword{'word'}." inserted at ".$numberword{'tokid'}."\n";
				#print STDERR "inserted at $linenr +2".$new_sentence->{$linenr+2}->{'word'}."\n";
				
			}
			# case day, month, del año year: 10_de_agosto_del_año_1998
			elsif($length==6 && @tokens[0] =~ /[\d]+/ && lc(@tokens[1]) eq 'de' && lc(@tokens[2]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/ && lc(@tokens[3]) eq 'del' && @tokens[4] =~ /año/ && @tokens[5] =~ /\d\d\d\d/)
			{
		 		my %numberword = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => @tokens[0],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $word->{'head'},
							 dep => $word->{'dep'},,
							 originaltokid=> $word->{'tokid'}
				);
				my %de = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %month = ( tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => "[??:??/".$mapMonths{lc(@tokens[2])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %del = (tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'gen=c|num=m|postype=preposition|contracted=yes|eagles=SPCMS',
							 head => $month{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %anio = (tokid => $word->{'tokid'}+4,
							 word => @tokens[4],
							 lem => 'año',
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=m|num=s|postype=common|eagles=NCMS000',
							 head => $del{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %year = ( tokid => $word->{'tokid'}+5,
							 word => @tokens[5],
							 lem => "[??:??/??/".@tokens[5].":??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $anio{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%numberword;
				$new_sentence->{$linenr+1} = \%de;
				$new_sentence->{$linenr+2} = \%month;
				$new_sentence->{$linenr+3} = \%del;
				$new_sentence->{$linenr+4} = \%anio;
				$new_sentence->{$linenr+5} = \%year;
			}
			
			# case: día+mes 12 de febrero
			elsif($length==3 && @tokens[0] =~ /[\d]+|/ && lc(@tokens[1] eq 'de') && lc(@tokens[2]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/)
			{ 
		
				my %numberword = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => @tokens[0],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $word->{'head'},
							 dep => $word->{'dep'},,
							 originaltokid=> $word->{'tokid'}
				);
				my %de = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %month = ( tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => "[??:??/".$mapMonths{lc(@tokens[2])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%numberword;
				$new_sentence->{$linenr+1} = \%de;
				$new_sentence->{$linenr+2} = \%month;
		
				
			}
			# case: día+mes el día_12_de_febrero
			elsif($length==4 && lc(@tokens[0]) eq 'día' && @tokens[1] =~ /[\d]+/ && lc(@tokens[2]) eq 'de' && lc(@tokens[3]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/)
			{
		
				my %dia = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => @tokens[0],
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=m|num=s|postype=common|eagles=NCMS000',
							 head => $word->{'head'},
							 dep => $word->{'dep'},,
							 originaltokid=> $word->{'tokid'}
				);
				
				my %numberword = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => @tokens[1],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $dia{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %de = (tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %month = ( tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => "[??:??/".$mapMonths{lc(@tokens[3])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%dia;
				$new_sentence->{$linenr+1} = \%numberword;
				$new_sentence->{$linenr+2} = \%de;
				$new_sentence->{$linenr+3} = \%month;
				
				
			}
			#case: diciembre_de_1983 ------------------------
			elsif($length==3 &&  lc(@tokens[0]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/  && lc(@tokens[1]) =~ /^de|del$/ && @tokens[2] =~ /[\d]+/)
			{# print STDERR "@tokens, line nr: $linenr\n";
				my %month = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => "[??:??/".$mapMonths{lc(@tokens[0])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
		
				my $demorph = (lc(@tokens[1]) eq 'de') ? 'postype=preposition|eagles=SPS00' :  'gen=c|num=m|postype=preposition|contracted=yes|eagles=SPCMS';
		 		
				my %de = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => $demorph,
							 head => $month{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %numberword = ( tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => @tokens[2],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
			
				
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%month;
				$new_sentence->{$linenr+1} = \%de;
				$new_sentence->{$linenr+2} = \%numberword;
				#print STDERR "@tokens, inserted ".$month{'word'}." at $linenr\n";
	
			}
			#case: diciembre_del_año_1983
			elsif($length==4 &&  lc(@tokens[0]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/  && lc(@tokens[1]) eq 'del'  && lc(@tokens[2]) eq 'año' && @tokens[3] =~ /[\d]+/)
			{
		
				my %month = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => "[??:??/".$mapMonths{lc(@tokens[0])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'},
				);
		
				my %del = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'gen=c|num=m|postype=preposition|contracted=yes|eagles=SPCMS',
							 head => $month{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %anio = (tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => 'año',
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=m|num=s|postype=common|eagles=NCMS000',
							 head => $del{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %numberword = ( tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => @tokens[3],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $anio{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
			
				
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%month;
				$new_sentence->{$linenr+1} = \%del;
				$new_sentence->{$linenr+2} = \%anio;
				$new_sentence->{$linenr+3} = \%numberword;
	
			}
			#cases: cinco_de_la_tarde, 1.30_de_la_madrugada
			elsif($length==4  && @tokens[0] =~ /[\d\.\:]+|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce/  && lc(@tokens[1]) eq 'de'  && lc(@tokens[2]) eq 'la' && lc(@tokens[3]) =~ /noche|tarde|madrugada|mañana/ )
			{
				my %numberword = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => @tokens[0],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $word->{'head'},
							 dep => $word->{'dep'},,
							 originaltokid=> $word->{'tokid'}
				);
				my %de = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %daytime = (tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => lc(@tokens[3]),
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=f|num=s|postype=common|eagles=NCFS000',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %la = (tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => 'el',
							 cpos => 'd',
							 pos => 'DA',
							 morphs => 'gen=f|num=s|postype=article|eagles=DA0FS0',
							 head => $daytime{'tokid'},
							 dep => 'spec',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%numberword;
				$new_sentence->{$linenr+1} = \%de;
				$new_sentence->{$linenr+2} = \%la;
				$new_sentence->{$linenr+3} = \%daytime;
				
			}
			#case: once_del_mediodía
			elsif($length==3  && @tokens[0] =~ /[\d\.\:]+|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce/  && lc(@tokens[1]) eq 'del'  && lc(@tokens[2]) eq 'mediodía' )
			{
				#print STDERR "tokens @tokens, $length\n";
				my %numberword = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => @tokens[0],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $word->{'head'},
							 dep => $word->{'dep'},,
							 originaltokid=> $word->{'tokid'}
				);
				my %del = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'gen=c|num=m|postype=preposition|contracted=yes|eagles=SPCMS',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %daytime = (tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => lc(@tokens[2]),
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=m|num=s|postype=common|eagles=NCMS000',
							 head => $del{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%numberword;
				$new_sentence->{$linenr+1} = \%del;
				$new_sentence->{$linenr+2} = \%daytime;
			}
			#case: jueves_26_de_mayo
			elsif($length==4  && lc(@tokens[0]) =~ /lunes|martes|miércoles|jueves|viernes|sábado|domingo/ && @tokens[1]=~ /\d+/ && lc(@tokens[2]) eq 'de'  && lc(@tokens[3]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/  )
			{
			#	print STDERR "tokens @tokens, $length\n";
				
				my %day = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => "[".lc(@tokens[0]).":??/??/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
				
				my %numberword = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => @tokens[1],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $day{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
							 
				);
				my %de = (tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				my %month = ( tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => "[??:??/".$mapMonths{lc(@tokens[3])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				# set possible dependents go to number, so we can just leave that and insert new words
				$new_sentence->{$linenr} = \%day;
				$new_sentence->{$linenr+1} = \%numberword;
				$new_sentence->{$linenr+2} = \%de;
				$new_sentence->{$linenr+3} = \%month;
			}
			#case: mes_de_agosto, mes_de_agosto_del_2000, mes_de_agosto_de_1998
			elsif($length==5 && lc(@tokens[0]) eq 'mes' && lc(@tokens[1]) eq 'de' && lc(@tokens[2]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/  && lc(@tokens[3]) =~ /^de|del$/ && @tokens[4] =~ /[\d]+/)
			{
		
				my %mes = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => 'mes',
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=m|num=s|postype=common|eagles=NCMS000',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'},
				);
				
				my %de = (tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $mes{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %month = ( tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => "[??:??/".$mapMonths{lc(@tokens[2])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
		
				my $de2morph = (lc(@tokens[3]) eq 'de') ? 'postype=preposition|eagles=SPS00' :  'gen=c|num=m|postype=preposition|contracted=yes|eagles=SPCMS';
		 		
				my %de2 = (tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => $de2morph,
							 head => $month{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %numberword = ( tokid => $word->{'tokid'}+4,
							 word => @tokens[4],
							 lem => @tokens[4],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $de2{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				$new_sentence->{$linenr} = \%mes;
				$new_sentence->{$linenr+1} = \%de;
				$new_sentence->{$linenr+2} = \%month;
				$new_sentence->{$linenr+3} = \%de2;
				$new_sentence->{$linenr+4} = \%numberword;
	
			}
			#case: pasado_26_de_mayo, próximo_13_de_junio
			elsif($length==4 && lc(@tokens[0]) =~ /^pasado|próximo$/ && lc(@tokens[1]) =~ /\d+/ && lc(@tokens[2]) eq 'de' && lc(@tokens[3]) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/)
			{
				
				my %numberword = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => @tokens[1],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
				my %adj = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => lc(@tokens[0]),
							 cpos => 'a',
							 pos => 'AQ',
							 morphs => 'gen=m|num=s|postype=qualificative|eagles=AQ0MSP',
							 head => $numberword{'tokid'},
							 dep => 'S',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %de = (tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $numberword{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				
				my %month = ( tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => "[??:??/".$mapMonths{lc(@tokens[3])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
		
				# set possible dependents go to number, not pasado/próximo
				my $headkey1 = "s".$s.":".$word->{'tokid'};
				$headdix{$headkey1} = \%numberword;
				
				$new_sentence->{$linenr} = \%adj;
				$new_sentence->{$linenr+1} = \%numberword;
				$new_sentence->{$linenr+2} = \%de;
				$new_sentence->{$linenr+3} = \%month;
				
			}
			# case:   pasado_jueves, próximo_domingo, pasado_abril
			elsif($length==2 && @tokens[0] =~  /^pasado|próximo$/ && lc(@tokens[1]) =~ /lunes|martes|miércoles|jueves|viernes|sábado|domingo|enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/ )
			{
				my $daymonthlem = (lc(@tokens[1] =~ /lunes|martes|miércoles|jueves|viernes|sábado|domingo/) )? "[".lc(@tokens[1]).":??/??/??:??.??]" :  "[??:??/".$mapMonths{lc(@tokens[1])}."/??:??.??]";
				my %day = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => $daymonthlem,
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
				
				my %adj = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => lc(@tokens[0]),
							 cpos => 'a',
							 pos => 'AQ',
							 morphs => 'gen=m|num=s|postype=qualificative|eagles=AQ0MSP',
							 head => $day{'tokid'},
							 dep => 'S',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				# set possible dependents to 'horas', not number
				my $headkey1 = "s".$s.":".$word->{'tokid'};
				$headdix{$headkey1} = \%day;
				$new_sentence->{$linenr} = \%adj;
				$new_sentence->{$linenr+1} = \%day;
			}
			# case: lunes_pasado, mayo_pasado
			elsif($length==2 && lc(@tokens[0]) =~ /lunes|martes|miércoles|jueves|viernes|sábado|domingo|enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/ && @tokens[1] =~  /^pasado|próximo$/ )
			{
				my $daymonthlem = (lc(@tokens[0] =~ /lunes|martes|miércoles|jueves|viernes|sábado|domingo/) )? "[".lc(@tokens[0]).":??/??/??:??.??]" :  "[??:??/".$mapMonths{lc(@tokens[0])}."/??:??.??]";
				
				my %daymonth = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => $daymonthlem,
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
				
				my %adj = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => lc(@tokens[1]),
							 cpos => 'a',
							 pos => 'AQ',
							 morphs => 'gen=m|num=s|postype=qualificative|eagles=AQ0MSP',
							 head => $daymonth{'tokid'},
							 dep => 'S',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				$new_sentence->{$linenr} = \%daymonth;
				$new_sentence->{$linenr+1} = \%adj;
			}
			# case:   año_pasado, año_próximo, mes_pasado
			elsif($length==2 && lc(@tokens[0]) =~ /^año|mes/ && @tokens[1] =~  /^pasado|próximo$/  )
			{
				my %yearmonth = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => @tokens[0],
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=m|num=s|postype=common|eagles=NCMS000',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
				
				my %adj = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => lc(@tokens[1]),
							 cpos => 'a',
							 pos => 'AQ',
							 morphs => 'gen=m|num=s|postype=qualificative|eagles=AQ0MSP',
							 head => $yearmonth{'tokid'},
							 dep => 'S',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				$new_sentence->{$linenr} = \%yearmonth;
				$new_sentence->{$linenr+1} = \%adj;
			
				
			}
			# case: próximo_mes_de_octubre, pasado_mes_de_marzo
			elsif($length==4 && @tokens[0] =~  /^pasado|próximo$/ && lc(@tokens[1]) eq 'mes' && @tokens[2] eq 'de' && @tokens[3] =~  /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/)
			{
				my %mes = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => 'mes',
							 cpos => 'n',
							 pos => 'NC',
							 morphs => 'gen=m|num=s|postype=common|eagles=NCMS000',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'},
				);
				
				
				my %adj = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => lc(@tokens[0]),
							 cpos => 'a',
							 pos => 'AQ',
							 morphs => 'gen=m|num=s|postype=qualificative|eagles=AQ0MSP',
							 head => $mes{'tokid'},
							 dep => 'S',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				my %de = (tokid => $word->{'tokid'}+2,
							 word => @tokens[2],
							 lem => 'de',
							 cpos => 's',
							 pos => 'SP',
							 morphs => 'postype=preposition|eagles=SPS00',
							 head => $mes{'tokid'},
							 dep => 'sp',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				
				my %month = ( tokid => $word->{'tokid'}+3,
							 word => @tokens[3],
							 lem => "[??:??/".$mapMonths{lc(@tokens[3])}."/??:??.??]",
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $de{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				# set possible dependents to 'mes', not adj
				my $headkey1 = "s".$s.":".$word->{'tokid'};
				$headdix{$headkey1} = \%mes;
				$new_sentence->{$linenr} = \%adj;
				$new_sentence->{$linenr+1} = \%mes;
				$new_sentence->{$linenr+2} = \%de;
				$new_sentence->{$linenr+3} = \%month;
			}
			#case: jueves_17, martes_24
			elsif($length==2 &&  lc(@tokens[0]) =~ /lunes|martes|miércoles|jueves|viernes|sábado|domingo/ && @tokens[1] =~ /\d+/)
			{
				my %day = ( tokid => $word->{'tokid'},
							 word => @tokens[0],
							 lem => "[".lc(@tokens[0]).":??/??/??:??.??]",,
							 cpos => 'w',
							 pos => 'W',
							 morphs => 'ne=date|eagles=W',
							 head => $word->{'head'},
							 dep => $word->{'dep'},
							 originaltokid=> $word->{'tokid'}
				);
				
				my %numberword = ( tokid => $word->{'tokid'}+1,
							 word => @tokens[1],
							 lem => @tokens[1],
							 cpos => 'z',
							 pos => 'Z',
							 morphs => 'ne=number|eagles=Z',
							 head => $day{'tokid'},
							 dep => 'sn',
							 originaltokid=> $word->{'tokid'},
							 dontchangehead => 1
				);
				
				$new_sentence->{$linenr} = \%day;
				$new_sentence->{$linenr+1} = \%numberword;
			}
			# no such case, just print, need to adjust manually
			else{
				$printedNormally=1;
				$new_sentence->{$linenr} = $word;
			}
			unless($printedNormally){
				$prevInserted += ($length-1);
				#print STDERR "prev inserted now= $prevInserted\n";
				#$printedNormally=0;
			}
		}
		elsif($prevInserted > 0){
			$new_sentence->{$linenr+$prevInserted} = $word;
			# shift this token (tokid and in new_sentence and in headdix)
			#print STDERR "shifted ".$word->{'word'}." from ".$word->{'tokid'}." to ";
			my $newtokid = $linenr+$prevInserted;
			$word->{'tokid'} = $newtokid;
			#print STDERR $word->{'tokid'}."\n";
		}
		else{
			$new_sentence->{$linenr} = $word;
		}
	

	}
	foreach my $newlinenr (sort {$a <=> $b} keys %{$new_sentence}){
		my $new_token = $new_sentence->{$newlinenr};
			my $headid = $new_token->{head};
			unless($headid eq '0' or $new_token->{'dontchangehead'} ==1){
		#		#get acutal head, in case there was an elliptic token
				my $headkey = "s".$s.":".$headid;
				my $headword = $headdix{$headkey};
				$headid = $headword->{tokid};
			}
			print $new_token->{tokid}."\t".$new_token->{word}."\t".$new_token->{lem}."\t".$new_token->{cpos}."\t".$new_token->{'pos'}."\t".$new_token->{morphs}."\t".$headid."\t".$new_token->{dep}."\t_\t_"."\n";
		}
		print "\n";
		$printedSents++;
}
 print STDERR "printed $printedSents sentences\n";

#foreach my $key (sort {$a <=> $b} keys %sents_ancora){
#		#print STDERR "key: $key\n";
#		my $new_sent = $sents_ancora{$key};
#		
#		foreach my $linenr (sort {$a <=> $b} keys %{$new_sent}){
#			my $new_token = $new_sent->{$linenr};
#			my $headid = $new_token->{head};
#			unless($headid eq '0'){
#		#		#get acutal head, in case there was an elliptic token
#				my $headkey = "s".$key.":".$headid;
#				my $headword = $headdix{$headkey};
#				$headid = $headword->{tokid};
#				#my $test = $headdix{"s1:19"};
#			    #print STDERR "prep a tokid: ".$test->{tokid}." word: ".$test->{word}."\n";
#				#print STDERR "word: ".$merged_token->{word}." has head with headkey $headkey id from dix ".$headid."\n";
#			}
#			print $new_token->{tokid}."\t".$new_token->{word}."\t".$new_token->{lem}."\t".$new_token->{cpos}."\t".$new_token->{'pos'}."\t".$new_token->{morphs}."\t".$headid."\t".$new_token->{dep}."\t_\t_"."\n";
#
#		}
#		print "\n";
#}

sub id_sort {
	my ($sentence_id_a,$original_ancora_line_a) = split(':', $a);
	my ($sentence_id_b,$original_ancora_line_b) = split(':', $b);
	
	if($original_ancora_line_a> $original_ancora_line_b){
		return 1;
	}
	elsif($original_ancora_line_b > $original_ancora_line_a){
		return -1;
	}
	return 0;
}



#foreach my $s (keys %sents_ancora){
#	my $ancora_sentence = $sents_ancora{$s};
#	foreach my $linenr (sort {$a <=> $b} keys %{$ancora_sentence}){
#		my $word = $ancora_sentence->{$linenr};
#		if($word->{pos} eq 'W' && $word->{'word'} =~  /\_/){
#			print "word: ".$word->{word}.", lem: ".$word->{'lem'}."\n";
#		}
#	}
#}