# squoia/MT_systems/matxin-lex/Makefile
# This makefile requires GNU Make.

LIBXML2_INSTALL_DIR   ?= /usr
LTTOOLBOX_INSTALL_DIR ?= /usr

CXX      ?= g++
CXXFLAGS ?= -O0 -g3

CPPFLAGS = -I$(LTTOOLBOX_INSTALL_DIR)/include/lttoolbox-3.3 -I$(LIBXML2_INSTALL_DIR)/include/libxml2
LDFLAGS  = -L$(LTTOOLBOX_INSTALL_DIR)/lib -L$(LIBXML2_INSTALL_DIR)/lib

all: squoia-xfer-lex

squoia-xfer-lex:
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) squoia_xfer_lex.cc -o $@ $(LDFLAGS) -llttoolbox3 -lxml2

clean:
	rm -f *.o squoia-xfer-lex

.PHONY: all clean

# end squoia/MT_systems/matxin-lex/Makefile
