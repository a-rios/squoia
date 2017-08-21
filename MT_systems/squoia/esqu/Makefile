# squoia/MT_systems/squoia/esqu/Makefile
# This makefile requires GNU Make.

FOMA_INSTALL_DIR ?= /opt/foma

KENLM_SRC_DIR   ?= /tmp/kenlm
KENLM_BUILD_DIR ?= /tmp/kenlm/build

CXX      ?= g++
CXXFLAGS ?= -O0 -g3

CPPFLAGS = -I$(KENLM_SRC_DIR) -DKENLM_MAX_ORDER=6 -I$(FOMA_INSTALL_DIR)/include

# May need these if KenLM was compiled with compression support
COMPRESS_LIBS = -lbz2 -llzma

header_deps = \
	$(FOMA_INSTALL_DIR)/include/foma/fomalib.h \
	$(KENLM_SRC_DIR)/lm/model.hh

libs = \
	-L$(KENLM_BUILD_DIR)/lib -lkenlm -lkenlm_util \
	$(COMPRESS_LIBS) \
	-L$(FOMA_INSTALL_DIR)/lib -lfoma \
	-lboost_regex -lboost_thread -lboost_system \
	-lz -pthread

all: outputSentences

outputSentences: outputSentences.cpp $(header_deps)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) outputSentences.cpp -o $@ $(libs)

clean:
	rm -f *.o outputSentences

.PHONY: all clean

# end squoia/MT_systems/squoia/esqu/Makefile
