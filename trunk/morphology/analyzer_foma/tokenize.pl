#/usr/bin/perl -w


use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

while (<>)
{
@words = split(/([\s+|,|\.|:|;|\-|\[|\]|\(|\)|\?|\"|\¡|\–|\¿|\!|\/|%|…])/);
foreach (@words) {
    if (m/^\s*$/) { next;}
    else {print $_."\n";}}
}