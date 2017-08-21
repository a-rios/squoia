# squoia/FreeLingModules/Makefile
# This makefile requires GNU Make.

FREELING_INSTALL_DIR ?= /opt/freeling

CXX      ?= g++
CXXFLAGS ?= -std=gnu++11 -Wall -O0 -g3

CPPFLAGS = -Iconfig_squoia -I$(FREELING_INSTALL_DIR)/include
LDFLAGS  = -L$(FREELING_INSTALL_DIR)/lib

analyzer_sources = analyzer_client.cc
analyzer_objects = $(analyzer_sources:.cc=.o)

nec_sources = nec.cc
nec_objects = $(nec_sources:.cc=.o)

server_sources = server_squoia.cc output_crf.cc
server_objects = $(server_sources:.cc=.o)

all: analyzer_client nec server_squoia

.cc.o:
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $<

analyzer_client: $(analyzer_objects)
	$(CXX) $(CXXFLAGS) -o $@ $(analyzer_objects) $(LDFLAGS) -lfreeling

nec: $(nec_objects)
	$(CXX) $(CXXFLAGS) -o $@ $(nec_objects) $(LDFLAGS) \
		-lfreeling -lboost_system -lpthread

server_squoia: $(server_objects)
	$(CXX) $(CXXFLAGS) -o $@ $(server_objects) $(LDFLAGS) \
		-lfreeling -lboost_program_options -lboost_system -lpthread

clean:
	rm -f *.o analyzer_client nec server_squoia

# end squoia/FreeLingModules/Makefile
