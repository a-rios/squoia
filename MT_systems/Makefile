# squoia/MT_systems/Makefile

all: maltparser.jar

# Create symlinks so that we can use static paths in translate_demo.cfg
maltparser.jar:
	ln -s $(FREELING_INSTALL_DIR)/share/freeling freeling-share
	ln -s $(MALTPARSER_JAR) maltparser.jar
	ln -s $(WAPITI_INSTALL_DIR) wapiti

clean:
	rm -f freeling-share maltparser.jar wapiti
	rm -rf tmp

# These can be easily regenerated
	rm -f storage/InterTransferRules
	rm -f storage/IntraTransferRules
	rm -f storage/LexSelRules
	rm -f storage/MorphSelRules
	rm -f storage/PrepSelRules
	rm -f storage/SemLex
	rm -f storage/child2siblingRules
	rm -f storage/config.bin
	rm -f storage/interchunkOrderRules
	rm -f storage/intrachunkOrderRules
	rm -f storage/nodes2chunksRules

.PHONY: all clean

# end squoia/MT_systems/Makefile
