#/usr/bin/perl -w

# input: 
# Catalinacha	+?
# ,	+?
# llawlliwan	+?

# output: only the unknown tokens (followed by +?) but not the punctuation signs
# Catalinacha
# llawlliwan
# ...
use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

while (<>)
{
 if (/\+\?/) {
  ($w,$unk) = split /\t/;
 if ($w =~ /[A-Za-zÑÁÉÍÓÚÜñáéíóúü']/) {
   print "$w\n";  
  } 
  else {}
 }
}
