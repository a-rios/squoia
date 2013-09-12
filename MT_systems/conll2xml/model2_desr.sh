#!/bin/bash

export DESR_DIR="/home/clsquoia/parser/desr-1.3.2"
#export DESR_CONFIG=$DESR_DIR/spanishv2.conf
export DESR_MODEL=$DESR_DIR/spanish.MLP
#export DESR_MODEL=$DESR_DIR/spanish_es4.MLP
export DESR_PARAMS="-m $DESR_MODEL" # -c $DESR_CONFIG"

#$DESR_DIR/src/desr $DESR_PARAMS 
export DESR_PORT=1234	# model2 = spanish.MLP
# squoia desr binaries:
export DESR_BIN=/home/ozli/squoia/google_squoia/desrModules
$DESR_BIN/desr_client $DESR_PORT
