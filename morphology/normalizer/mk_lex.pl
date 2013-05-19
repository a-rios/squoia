#/usr/bin/perl -w

#| [ {amaut'a} "[" "NRoot" "]" "["  "=amauta" "]" ] : {amaut'a}

use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

while (<>)
{
chomp();
print "| [ {".$_."} \"[\" \"NRootES\" \"]\"  ] : {".$_."}\n";
#print "| [ {".$_."} \"[\" \"VRootES\" \"]\"  ] : {".$_."}\n";
 }
