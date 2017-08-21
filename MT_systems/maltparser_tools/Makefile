# squoia/MT_systems/maltparser_tools/Makefile
# This makefile requires GNU Make.

# Path to MaltParser JAR file
MALTPARSER_JAR ?= /path/to/maltparser-1.9.0.jar

JAVAC = javac

sources = \
	src/MaltParserServer.java \
	src/MPClient.java

class = bin/MPClient.class

all: $(class)

$(class): $(MALTPARSER_JAR) $(sources)
	test -d bin || mkdir bin
	$(JAVAC) -cp $(MALTPARSER_JAR) -d bin $(sources)

clean:
	rm -rf bin

# end squoia/MT_systems/maltparser_tools/Makefile
