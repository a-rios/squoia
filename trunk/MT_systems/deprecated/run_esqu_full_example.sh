#!/bin/bash

# adapt paths to your installation
export MATXIN_BIN="/opt/matxin/local/bin"
export PROJECT_DIR="/home/clsquoia/google_squoia"
export FREELINGSHARE=$PROJECT_DIR/FreeLingModules
export ESQU_DIR=$PROJECT_DIR/MT_systems/esqu
export GRAMMAR_DIR=$ESQU_DIR/grammar
export OUTPUT_DIR=$GRAMMAR_DIR/output

export FREELING_CONFIG=$FREELINGSHARE/es_desr.cfg
#export FREELING_CONFIG=$FREELINGSHARE/es_desrHMM.cfg
export FREELING_PARAM="-f $FREELING_CONFIG $*"
#export FREELING_PORT="8866"
export FREELING_PORT="8866"
export MATXIN_DIX=$ESQU_DIR/lexica/es-quz.bin
export MATXIN_CONFIG=$ESQU_DIR/es-qu.cfg

# path to desr parser & its model
#export DESR_DIR_OLD="/home/clsquoia/parser/desr-1.2.6"
export DESR_DIR="/home/clsquoia/parser/desr-1.3.2"
export DESR_CONFIG=$DESR_DIR/spanishv2.conf
export DESR_MODEL=$DESR_DIR/spanish_es4.MLP
#export DESR_MODEL=$DESR_DIR/spanish.MLP
# squoia desr binaries:
export DESR_BIN=$PROJECT_DIR/desrModules
export DESR_PARAMS="-m $DESR_MODEL -c $DESR_CONFIG"
# model1 = spanish_es4.MLP
export DESR_PORT=5678
# how many translation should be printed if more than one possible
N_BEST=$1

# #test if squoia_analyzer is already listening
if ps ax | grep -v grep | grep "squoia_analyzer.*port=$FREELING_PORT"  > /dev/null
then
 echo "squoia_analyzer server already started" >&2
else
 echo "squoia_analyzer server not yet started" >&2
 squoia_analyzer -f $FREELING_CONFIG --outf=crfmorf --server --port=8844 2> logcrfmorf &
 echo "squoia_analyzer started..." >&2

while ! echo "" | analyzer_client $FREELING_PORT 2> /dev/null 
 do
  echo "please wait..." >&2
  sleep 10
 done
 
 echo "squoia_analyzer now ready" >&2
fi

# test if desr server already started listening, model 1
if ps ax | grep -v grep | grep "desr_server.*--port $DESR_PORT" > /dev/null
then
 echo "desr_server server with model 1 already started" >&2
else
 echo "desr_server server with model 1 not yet started" >&2
 desr_server -m $DESR_DIR/spanish_es4.MLP --port $DESR_PORT 2> logdesr_es4 &
 echo "desr_server with model 1 started..." >&2
 echo "please wait..." >&2
 sleep 1
 
 echo "desr_server with model 1 now ready" >&2
fi

# test if desr server already started listening, model 2
if ps ax | grep -v grep | grep 'desr_server.*--port 1234' > /dev/null
then
 echo "desr_server server with model 2 already started" >&2
else
 echo "desr_server server with model 2 not yet started" >&2
 desr_server -m $DESR_DIR/spanish.MLP --port 1234 2> logdesr_MLP &
 echo "desr_server with model 2 started..." >&2
 echo "please wait..." >&2
 sleep 1
 echo "desr_server with model 2 now ready" >&2
fi





#perl readConfig.pl $MATXIN_CONFIG;


# server-client mode, new desr parser client
./tagWapiti.sh |desr_client $DESR_PORT | perl conll2xml/conll2xml.pl |perl esqu/disambRelClauses_desr.pl | perl esqu/corefSubj_desr.pl  | perl esqu/disambVerbFormsRules.pl $EVID |perl esqu/svm.pl |$MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX   | perl splitNodes.pl  | perl insertSemanticTags.pl  | perl semanticDisamb.pl | perl morphDisamb.pl  | perl prepositionDisamb.pl  | perl  synTransferIntraChunk.pl | perl STinterchunk.pl | perl nodesToChunks.pl | perl childToSiblingChunk.pl  | perl recursiveNumberChunks.pl | perl interChunkOrder.pl | perl linearOrderChunk.pl | perl nodeOrderInChunk.pl | perl esqu/getSentencesForGenerationWithAlternatives.pl | lookup -flags xcKv29TT $PROJECT_DIR/morphology/transfer_generator/unificadoTransfer.fst | esqu/outputSentences -m esqu/test.binary -n $N_BEST
