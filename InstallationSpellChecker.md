How to install the spell checker for Unified Southern Quechua


  1. download spellChecker.tar from http://code.google.com/p/squoia/downloads/list
  1. unpack the archive:
```
$ tar xf spellChecker.tar
```
  1. get foma:
    * either the newest version from here:
> > > http://code.google.com/p/foma/downloads/list
    * or per svn checkout:
```
$ svn co http://foma.googlecode.com/svn/trunk/foma/ foma
```
  1. compile and install foma:
```
$ cd path-to-your-foma-sources
$ make
$ make install
```
  1. compile spellcheck.c:
```
$ cd path-to-your-spellchecker-source/foma_files
$ gcc -o spellcheck spellcheck.c  /usr/local/lib/libfoma.a  -lz 
```

> > or do (depending on where your libfoma.a is):
```
$ gcc -o spellcheck spellcheck.c /usr/lib/libfoma.a  -lz 
```
  1. copy spellcheck to some place in your PATH (note: you probably have to be root to do this. If that's not possible, adapt the PATH variable in your ~/.bashrc to include the folder /foma\_files):
```
$ cp spellcheck /usr/local/bin
```
  1. compile the finite state transducers (compiling the normalizers will take a while due to large lexica):
```
$ cd path-to-spellChecker/analyzer
$ foma -f compile.foma  
$ cd ../normalizer
$ foma -f chain.foma
```
  1. you should now have the binary files
    * analyzer/analyzeUnificado.bin
    * analyzer/spellcheckUnificado.bin
    * normalizer/chain.bin
  1. NOTE: 'spellcheck' expects the input text to be tokenized (one word per line), you can use the tokenizer included in this package: tokenizer/tokenize.pl.
    * tokenize.pl needs the Uplug::PreProcess::Tokenizer perl module:
    * get it from http://search.cpan.org/~tiedemann/uplug-main-0.3.8/lib/Uplug/PreProcess/Tokenizer.pm
    * or install it through cpan:
```
$ cpan Uplug::PreProcess::Tokenizer
```
  1. you can now call 'spellcheck', indicating the paths to analyzer.bin, chain.bin and spellcheckUnificado.bin (in this order!), and remember, input has to be tokenized:
```
$ cat tokenized.txt | spellcheck path-to-your-spellChecker/analyzer/analyzer.bin path-to-your-spellChecker/normalizer/chain.bin path-to-your-spellChecker/analyzer/spellcheckUnificado.bin 
```
  1. Example: for a file containing the the words:
```
wasita
wasiyki
wasitan
wsaita
wasiq
takeqta
```
    * output will look like this:
```
wasita:
        --
wasiyki:
        --
wasitan:
        wasitam
wsaita
        Usanta
        wsaita
        Cost[f]: 6

        Usaqta
        wsaita
        Cost[f]: 6

        Usapta
        wsaita
        Cost[f]: 6

wasiq:
        wasip
takeqta:
        takiqta

```
    * correctly written words are marked with '--' (wasita, wasiyki)
    * for normalized words, the normalized form is printed out (wasitan: wasitam, wasiq: wasip, takeqta: takiqta)
    * for words that need spell checking with minimun edit distance, the suggestions are listed and the edit distance is indicated (`Cost[f]`).


  1. alternatively, you can use the included shell script (but note that this is slower than calling 'spellcheck'!)
    1. you have to adapt the paths in spellcheck-axample.sh, save as spellcheck.sh, and make it executable:
```
$ chmod +x spellcheck.sh
```
    1. you have to compile fmed.c (allows to call med (minimum edit distance search) from the shell:
```
$ cd path-to-your-spellchecker-source/foma_files
$ gcc -o fmed fmed.c  /usr/local/lib/libfoma.a  -lz 
```
> > > or do (depending on where your libfoma.a is):
```
$ gcc -o fmed fmed.c /usr/lib/libfoma.a  -lz 
```
    1. copy fmed to some place in your PATH (note: you probably have to be root to do this. If that's not possible, adapt the PATH variable in your ~/.bashrc to include the folder /foma\_files):
```
$ cp fmed /usr/local/bin
```
    1. then run spellcheck.sh, pass the text you want to spell check as argument
```
$ ./spellcheck.sh file-you-want-to-spell-check
```

> the script will output a list of misspelled words with their corrections, or 'no spelling errors found' if the text is written according to the Unified Southern orthography. The list is also printed to tmp/text.out. NOTE: this is slower than using the C executable 'spellcheck' as described above.