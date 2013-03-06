#/usr/bin/perl -w

use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

while (<>)
{
    chomp;
    @words = split(/([\s+|,|\.|:|;|\-|\[|\]|\(|\)|\?|\"|\¡|\–|\¿|\!|\/|%|…|“|”|«|»])/);
    foreach (@words)
    {
    if (m/^\s*$/) 
    { next;}
    if(  \$_ == \$words[-1] && $_ !~ /,|\.|:|;|\-|\[|\]|\(|\)|\?|\"|\¡|\–|\¿|\!|\/|%|…|“|”|«|»/ ) 
      {print $_."\n#EOS\n";}
    else
      {print $_."\n";}
    }
}