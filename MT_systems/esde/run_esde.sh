# bilingual dictionary
# MATXIN_DIR=/opt/matxin/local/
export PROJECT_DIR="/home/clsquoia/de_squoia"
export ESDE_DIR="$PROJECT_DIR/MT_systems/esde"
export ESDE_DICT="$ESDE_DIR/lexica/es-de"
export ESDE_CHUNKTYPE="$ESDE_DIR/grammar/chunktype_es-de.cfg"
export FREELING_CONFIG="$PROJECT_DIR/FreeLingModules/FL_es_desr.cfg"
export FREELING_PARAM="-f $FREELING_CONFIG"

export SQUOIAMATXIN="$PROJECT_DIR/MT_systems"
export ESDEMATXIN=$SQUOIAMATXIN/esde
export TESTOUTPUT="$ESDEMATXIN/tests/esdeout"
export CONFIGFILE="$ESDEMATXIN/es-de.cfg"

#export DESR_DIR="/home/clsquoia/parser/desr-1.2.6"
export DESR_DIR="/home/clsquoia/parser/desr-1.3.2"
export DESR_CONFIG=$DESR_DIR/spanishv2.conf
export DESR_MODEL=$DESR_DIR/spanish_es4.MLP
#export DESR_MODEL=$DESR_DIR/spanish.MLP
export DESR_PARAMS="-m $DESR_MODEL" # -c $DESR_CONFIG"

export TAGPORT=8866

# test if server already started listening
#server_running=`netstat -lnp --tcp 2> /dev/null | grep squoia_analy |grep -c $TAGPORT `
server_running=`lsof -a -i4TCP:$TAGPORT -c/squoia_analyzer/  2> /dev/null |grep -c $TAGPORT`
#echo "server state: $server_running"
if [ $server_running -eq 1 ]
then
 echo "squoia_analyzer server already started"
else
 echo "squoia_analyzer server not yet started"
 #echo "Please start server to tag for desr parser with the following command:"
 #echo "/opt/matxin/matxinFL3/squoia_analyzer $FREELING_PARAM --outf=desrtag --server --port=$TAGPORT 2> /opt/matxin/matxinFL3/logdesrtag &"
 #exit
 squoia_analyzer $FREELING_PARAM --outf=desrtag --server --port=$TAGPORT 2> logdesrtag &
 echo "squoia_analyzer started..."
 while ! echo "" | analyzer_client $TAGPORT 2> /dev/null
 do
  echo "please wait..."
  sleep 10
 done
 echo "squoia_analyzer now ready"
fi
#echo $1 | analyzer_client $TAGPORT
#exit

# compile dictionary after changes in .dix
lt-comp lr "$ESDE_DICT.dix" "$ESDE_DICT.bin"

export CONLL_BIN=$SQUOIAMATXIN/conll2xml/conll2xml.pl
export DESR_PORT=5678	# model1 = spanish_es4.MLP

# tag, parse and convert to "matxin" xml
#analyzer_client $TAGPORT | $DESR_DIR/src/desr $DESR_PARAMS 2>./junk | perl $CONLL_BIN  2>> ./junk | matxin-xfer-lex -c $ESDE_CHUNKTYPE $ESDE_DICT.bin > $TESTOUTPUT.desrparsed
analyzer_client $TAGPORT | desr_client $DESR_PORT 2>./junk | perl $CONLL_BIN 2> /dev/null | matxin-xfer-lex -c $ESDE_CHUNKTYPE $ESDE_DICT.bin > $TESTOUTPUT.desrparsed
#exit
xmllint --format $TESTOUTPUT.desrparsed

export PERL5LIB="$SQUOIAMATXIN:$ESDEMATXIN"

# new matxin pipe configuration
perl  $SQUOIAMATXIN/readConfig.pl $CONFIGFILE

# language model
export LM="$ESDE_DIR/lm/dewac10M_3g_lemma.bin.lm"
MAXALT=3

ALTERNATIVES=$1
if [ $ALTERNATIVES -eq 1 ]
then
cat $TESTOUTPUT.desrparsed | perl $SQUOIAMATXIN/insertSemanticTags.pl 2>> ./junk | perl $SQUOIAMATXIN/semanticDisamb.pl 2>> ./junk | perl  $SQUOIAMATXIN/statisticLexDisamb.pl $LM $MAXALT 2>> ./junk | perl $SQUOIAMATXIN/alternativeSentences.pl 2>> ./junk | perl $SQUOIAMATXIN/prepositionDisamb.pl 2>> ./junk | perl $SQUOIAMATXIN/verbPrepDisamb.pl 2>> ./junk | perl $SQUOIAMATXIN/splitNodes.pl 2>> ./junk | perl $ESDEMATXIN/addPronouns.pl 2>> ./junk | perl $ESDEMATXIN/addFutureAux.pl 2>> ./junk | perl $ESDEMATXIN/splitVerbPrefix.pl 2>> ./junk | perl $SQUOIAMATXIN/synTransferIntraChunk.pl 2>> ./junk | perl $SQUOIAMATXIN/STinterchunk.pl 2>> ./junk | perl $SQUOIAMATXIN/nodesToChunks.pl 2>> ./junk | perl $SQUOIAMATXIN/childToSiblingChunk.pl 2>> ./junk | perl $SQUOIAMATXIN/recursiveNumberChunks.pl 2>> ./junk | perl $SQUOIAMATXIN/interChunkOrder.pl 2>> ./junk | perl $SQUOIAMATXIN/linearOrderChunk.pl 2>> ./junk | perl $SQUOIAMATXIN/nodeOrderInChunk.pl 2>> ./junk > $TESTOUTPUT.xml
else
cat $TESTOUTPUT.desrparsed | perl $SQUOIAMATXIN/insertSemanticTags.pl 2>> ./junk | perl $SQUOIAMATXIN/semanticDisamb.pl 2>> ./junk | perl $SQUOIAMATXIN/countAlternativeSentences.pl 2>> ./junk  | perl $SQUOIAMATXIN/prepositionDisamb.pl  2>> ./junk | perl $SQUOIAMATXIN/verbPrepDisamb.pl 2>> ./junk | perl $SQUOIAMATXIN/splitNodes.pl 2>> ./junk | perl $ESDEMATXIN/addPronouns.pl 2>> ./junk | perl $ESDEMATXIN/addFutureAux.pl 2>> ./junk | perl $ESDEMATXIN/splitVerbPrefix.pl 2>> ./junk | perl $SQUOIAMATXIN/synTransferIntraChunk.pl 2>> ./junk | perl $SQUOIAMATXIN/STinterchunk.pl 2>> ./junk | perl $SQUOIAMATXIN/nodesToChunks.pl 2>> ./junk | perl $SQUOIAMATXIN/childToSiblingChunk.pl 2>> ./junk | perl $SQUOIAMATXIN/recursiveNumberChunks.pl 2>> ./junk| perl $SQUOIAMATXIN/interChunkOrder.pl 2>> ./junk | perl $SQUOIAMATXIN/linearOrderChunk.pl 2>> ./junk | perl $SQUOIAMATXIN/nodeOrderInChunk.pl 2>> ./junk > $TESTOUTPUT.xml 
fi
#exit


perl $SQUOIAMATXIN/myoutputOrderChunk.pl < $TESTOUTPUT.xml 2>> ./junk > $TESTOUTPUT.stts

MOLIFDE=/home/clmolif/molifde
flookup $MOLIFDE/fst/SttsGeneratorTool.fst < $TESTOUTPUT.stts > $TESTOUTPUT.fstout

perl  $ESDEMATXIN/cleanFstOutput.pl < $TESTOUTPUT.fstout > $TESTOUTPUT.gen 2>> ./junk
cat $TESTOUTPUT.gen

export LMSENT="$ESDE_DIR/lm/dewac100M_4g_word.bin.lm"
perl $ESDEMATXIN/queryBestSentences.pl $LMSENT < $TESTOUTPUT.gen 2>> ./junk

exit
echo
echo "Spanish:"
echo $1
echo "to German with FL/DeSR/CoNLL2XML:"
cat $TESTOUTPUT.gen
echo "--------------------"

