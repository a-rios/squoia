### VM
You can find an image of a virtual machine with a running installation of the MT system here: https://pub.cl.uzh.ch/projects/squoia/squoia_1_1.ova

In order to use it, you need to install VirtualBox: If you're running Linux, there is a good chance VirtualBox is available through your package management, otherwise see see https://www.virtualbox.org/wiki/Downloads

To use the squoia VM, go to File->Import Appliance in your virtualbox and select the squoia_1_1.ova file. 
Once installed, you can boot the virtual machine. 
User is `squoia`, password is `quechua` (also for root).
The source files of this repository are in `/home/squoia/squoia`, to use the translation, open a terminal (e.g. LXTerminal) and go to the MT folder:
`squoia@squoiavm:~$ cd squoia/MT_systems`

translate.pm is the perl script that handles the translation, for a detailed list of options use:
`squoia@squoiavm:~/squoia/MT_systems$ ./translate.pm --help`

test the system with a simple sentence, output should look like this: 
```
squoia@squoiavm:~/squoia/MT_systems$ echo "La casa azul es bonita." | ./translate.pm
using saved config file /home/squoia/squoia/MT_systems/storage/config.bin
start format 2
end format 25
no instance of server_squoia running on port 9001 with config ../FreeLingModules/vm.cfg
starting server_squoia on port 9001 with config ../FreeLingModules/vm.cfg, logging to /home/squoia/squoia/MT_systems/logs/logcrfmorf...
starting server_squoia, please wait...
server_squoia now ready
* TRANS-STEP 4) [-o tagged] tagging
* TRANS-STEP 5)  [-o conll] conll format
* Load model
* Label sequences
* Done
no instance of MaltParserServer running on port 9002 with model ./models/splitDatesModel.mco
starting MaltParserServer on port 9002 with model ./models/splitDatesModel.mco, logging to /home/squoia/squoia/MT_systems/logs/log.malt...
MaltParserServer with model = ./models/splitDatesModel.mco started on port 9002...
starting MaltParserServer, please wait...
starting MaltParserServer, please wait...
starting MaltParserServer, please wait...
MaltParserServer now ready
* TRANS-STEP 6)  [-o parsed] parsing
* TRANS-STEP 7)  [-o conll2xml] conll to xml format
Connecting to server...
Connection established
* TRANS-STEP 8)  [-o rdisamb] relative clause disambiguation
* TRANS-STEP 9)  [-o coref] subject coreference resolution
* TRANS-STEP 10)  [-o vdisamb] verb form disambiguation (rule-based)
* TRANS-STEP 11)  [-o svm] verb form disambiguation (svm)
* TRANS-STEP 12)  [-o lextrans] lexical transfer
* TRANS-STEP 13)  [-o semtags] insert semantic tags
* TRANS-STEP 14)  [-o lexdisamb] lexical disambiguation, rule-based
* TRANS-STEP 15)  [-o morphdisamb] morphological disambiguation, rule-based
* TRANS-STEP 16)  [-o prepdisamb] preposition disambiguation, rule-based
* TRANS-STEP 17)  [-o intraTrans] syntactic transfer, intra-chunks
* TRANS-STEP 18)  [-o interTrans] syntactic transfer, inter-chunks
* TRANS-STEP 19)  [-o node2chunk] promote nodes to chunks
* TRANS-STEP 20)  [-o child2sibling] promote child chunks to siblings
* TRANS-STEP 21)  [-o interOrder] reorder the chunks, inter-chunks
* TRANS-STEP 22)  [-o intraOrder] reorder the nodes, intra-chunks
* TRANS-STEP 23)  [-o morph] morphological generation
* TRANS-STEP 24)  [-o words] word forms
* TRANS-STEP 25)  [-o nbest] n-best translations

Q'umir wasiqa sumaqmi . p:-13.9964
Q'umir wasiqa munaycham . p:-17.5069
```
The config used is a binary form of translate_vm.cfg, if you change something in translate_vm.cfg, call translate.pm with the option `-c translate_vm.cfg` to read it in, otherwise changes will not take effect.

The first run will always take a bit longer because the tagging and parsing services need to be started. 

Input from a file instead of stdin can be passed with the option -f, check --help for more information about input and output formats. Encoding must be utf8.

IMPORTANT: RAM is currently set to 4 GB in the virtual machine, this can be too low. If you get an `out of memory` error during tagging, you can increase the RAM assigned to the VM in Settings->System->Motherboard->Base Memory (the virtual machine must be powered off to do so).

### Installation 

Note: this code is not maintained and the installation is cumbersome due to the large number of dependencies. 

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
cd $SQUOIA_DIR/MT_systems/maltparser_tools/src 
javac -cp $MALTPARSER_DIR/maltparser-1.8/maltparser-1.8.jar MPClient.java
javac -cp $MALTPARSER_DIR/maltparser-1.8/maltparser-1.8.jar MaltParserServer.java
```

move binaries to ../bin:
`mv MaltParserServer.class MPClient.class ../bin/`

## lttoolbox
http://wiki.apertium.org/wiki/Lttoolbox

If you're on Linux, lttoolbox may be part of your distribution, e.g. Debian, and can be installed through your package managment system (make sure to install the development package as well, something like lttoolbox-dev or lttoolbox-devel).
To compile the lexical transfer module in squoia: 
```
cd $SQUOIA_DIR/MT_systems/matxin-lex
make
```
To compile the bilingual dictionary, do (only necessary if you made changes to es-quz.dix):
```
cd $SQUOIA_DIR/MT_systems/squoia/esqu/lexica
lt-comp lr es-quz.dix es-quz.bin
```

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


