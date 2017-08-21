# squoia/Makefile
# This makefile requires GNU Make.

# Path to Algorithm::SVM install
export ALGORITHM_SVM_INSTALL_DIR = $(HOME)/opt/algorithm-svm

# Path to FreeLing install tree
export FREELING_INSTALL_DIR = $(HOME)/opt/freeling

# Path to FOMA install tree
# (a copy is helpfully included in FreeLing)
export FOMA_INSTALL_DIR = $(FREELING_INSTALL_DIR)

# Path to KenLM source/build trees (usually the same)
export KENLM_SRC_DIR = $(HOME)/src/kenlm
export KENLM_BUILD_DIR = $(KENLM_SRC_DIR)/build

# Path to LibXML2 install tree
# (usually available as a distro package under /usr)
export LIBXML2_INSTALL_DIR = /usr

# Path to Apertium lttoolbox install tree
# (may be available as a distro package under /usr)
export LTTOOLBOX_INSTALL_DIR = /usr

# Path to MaltParser JAR file
export MALTPARSER_JAR = $(HOME)/src/maltparser-1.9.0/maltparser-1.9.0.jar

# Path to Wapiti install tree
export WAPITI_INSTALL_DIR = $(HOME)/opt/wapiti

# TCP port numbers for the SQUOIA and MaltParser servers
# (note: if you change these, also edit MT_systems/translate_demo.cfg)
SQUOIA_PORT = 9001
MALTPARSER_PORT = 9002

# C++ compilation
CXX = g++
CXXFLAGS = -std=gnu++11 -Wall -O0 -g3

export LD_LIBRARY_PATH := $(LD_LIBRARY_PATH):$(FREELING_INSTALL_DIR)/lib

JAVA = java

all clean:
	cd FreeLingModules && $(MAKE) $@
	cd MT_systems && $(MAKE) $@
	cd MT_systems/maltparser_tools && $(MAKE) $@
	cd MT_systems/matxin-lex && $(MAKE) $@
	cd MT_systems/squoia/esqu && $(MAKE) $@

run-squoia:
	export FREELINGSHARE=$(FREELING_INSTALL_DIR)/share/freeling; \
	cd FreeLingModules && ./server_squoia -f es_demo.cfg --server --port=$(SQUOIA_PORT)

test-squoia:
	cd FreeLingModules && cat ../input-demo.txt | ./analyzer_client $(SQUOIA_PORT)

run-malt:
	$(JAVA) -cp $(MALTPARSER_JAR):MT_systems/maltparser_tools/bin MaltParserServer $(MALTPARSER_PORT) MT_systems/models/splitDatesModel.mco

run-translate: $(MALTPARSER_JAR)
	mkdir -p MT_systems/tmp
	export PATH=$(PWD)/FreeLingModules:$(PATH); \
	export PERL5LIB=$(ALGORITHM_SVM_INSTALL_DIR)/lib/perl5; \
	cd MT_systems && ./translate.pm \
		--config translate_demo.cfg \
		--file ../input-demo.txt

help-translate:
	export PERL5LIB=$(ALGORITHM_SVM_INSTALL_DIR)/lib/perl5; \
	cd MT_systems && ./translate.pm -h

.PHONY: all clean help-translate run-malt run-squoia run-translate test-squoia

# end squoia/Makefile
