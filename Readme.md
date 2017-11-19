### Installation 

Note: this code is not maintained.

## FreeLing

`git clone https://github.com/TALP-UPC/freeling`

Installation (make sure to install from sources, headers are needed),  see: https://talp-upc.gitbooks.io/freeling-user-manual/content/installation.html

compile Freeling analyzer with crf output format for wapiti:
```
export FREELING_INSTALLATION_DIR= path to you installation of FreeLing
export SQUOIA_DIR= path to this package
g++ -c -o output_crf.o output_crf.cc -I$FREELING_INSTALLATION_DIR/include -I$SQUOIA_DIR/FreeLingModules/config_squoia
g++ -c -o analyzer_client.o analyzer_client.cc -I$FREELING_INSTALLATION_DIR/include -I$SQUOIA_DIR/FreeLingModules/config_squoia
g++ -std=gnu++11 -c  -o server_squoia.o server_squoia.cc -I$FREELING_INSTALLATION_DIR/include -I$SQUOIA_DIR/FreeLingModules/config_squoia
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$FREELING_INSTALLATION_DIR/lib
g++ -O3 -Wall -o server_squoia server_squoia.o output_crf.o -L$FREELING_INSTALLATION_DIR/lib -lfreeling -lboost_program_options -lboost_system -lboost_filesystem -lpthread
```

named entity classification:
```
g++ -std=gnu++11 -o nec nec.cc -I$FREELING_INSTALLATION_DIR/include -I$SQUOIA_DIR/FreeLingModules/config_squoia -L$FREELING_INSTALLATION_DIR/lib -lfreeling -lboost_program_options -lboost_system -lboost_filesystem -lpthread
```

analyzer_client:

```
g++ -O3 -Wall -o analyzer_client analyzer_client.o -L$FREELING_INSTALLATION_DIR/lib -lfreeling
export FREELINGSHARE=$FREELING_INSTALLATION_DIR/share/freeling
```

once compiled, you can test the server:
```
./server_squoia -f $SQUOIA_DIR/FreeLingModules/es_squoia.cfg  --server --port=$PORT 2> logtagging &
echo "eso es una prueba" |./analyzer_client $PORT
```

Link server_squoia, analyzer_client and nec to the /bin folder (optional, if you do not link them, change the paths in translate_example.cfg):

```
cd $SQUOIA_DIR/bin
ln -s ../FreeLingModules/server_squoia .
ln -s ../FreeLingModules/analyzer_client .
ln -s ../FreeLingModules/nec .
```

For system wide use, either link client and server to somewhere in your $PATH (e.g. in `/usr/local/bin`), or add their location to $PATH


## Wapiti

https://wapiti.limsi.fr/

follow installation instructions, then adapt path to wapiti in FreeLingModules/example.cfg


## MaltParser

http://www.maltparser.org/download.html

follow installation instructions, see http://www.maltparser.org/install.html

set maltPath in translate_example.cfg to your installation of maltparser

compile server-client modules ($MALTPARSER_DIR= path to your maltparser installtion):

```
cd $SQUOIA_DIR/maltparser_tools/src 
javac -cp $MALTPARSER_DIR/maltparser-1.8/maltparser-1.8.jar MPClient.java
javac -cp $MALTPARSER_DIR/maltparser-1.8/maltparser-1.8.jar MaltParserServer.java
```

move binaries to ../bin:
`mv MaltParserServer.class MPClient.class ../bin/`


## libsvm
https://www.csie.ntu.edu.tw/~cjlin/libsvm

## foma 
https://bitbucket.org/mhulden/foma

compile morphological generator:
```
cd $SQUOIA_DIR/MT_systems/squoia/esqu/morphgen_foma
foma -f unificadoTransfer.foma
```


## kenlm
https://kheafield.com/code/kenlm

compile squoia module for language model:

```
cd $SQUOIA_DIR/MT_systems/squoia/esqu
g++ -o outputSentences outputSentences.cpp -Ipath-to-your-kenlm/ -DKENLM_MAX_ORDER=6 -Lpath-to-your-kenlm/lib/ -lkenlm path-to-your-foma/libfoma.a -lz  -lboost_regex -pthread -lboost_thread -lboost_system
```

## Perl modules required: 
```
Getopt::Long;
Storable;
File::Basename;
File::Spec::Functions
XML::LibXML
List::MoreUtils
Algorithm::SVM
```

adapt paths in $SQUOIA_DIR/FreeLingModules/example.cfg
adapt paths in $SQUOIA_DIR/MT_systems/esqu/es_qu.cfg

use translate.pm to process text:

```
cd $SQUOIA_DIR/MT_systems
./translate.pm -f infile -i input-format -o output-format
```

use 
```
./translate.pm -h 
```
to get a list of options.


