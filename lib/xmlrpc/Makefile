VSN=1.13
PUB_VSN="{1, 13}"

all:
	(cd src;$(MAKE))

doc:
	(cd doc;$(MAKE))

clean:
	(cd src;$(MAKE) clean)
	(cd doc;$(MAKE) clean)

test: all
	(cd test;$(MAKE))

release: all
	rm -fr releases/xmlrpc-$(VSN)
	mkdir releases/xmlrpc-$(VSN)
	sed 's/%VSN%/'$(PUB_VSN)'/' xmlrpc.pub > releases/xmlrpc-$(VSN)/xmlrpc.pub
	install -m 644 CHANGES LICENSE README TODO releases/xmlrpc-$(VSN)
	mkdir releases/xmlrpc-$(VSN)/doc
	install -m 644 doc/xmlrpc.3 releases/xmlrpc-$(VSN)/doc
	install -m 644 doc/xmlrpc.txt releases/xmlrpc-$(VSN)/doc
	install -m 644 doc/xmlrpc.ps releases/xmlrpc-$(VSN)/doc
	install -m 644 doc/xmlrpc.pdf releases/xmlrpc-$(VSN)/doc
	mkdir releases/xmlrpc-$(VSN)/ebin
	mkdir releases/xmlrpc-$(VSN)/examples
	install -m 644 examples/*.erl examples/*.java examples/*.txt examples/README examples/Makefile releases/xmlrpc-$(VSN)/examples
	mkdir releases/xmlrpc-$(VSN)/src
	install -m 644 src/*.erl src/*.hrl releases/xmlrpc-$(VSN)/src
	install -m 644 src/Makefile releases/xmlrpc-$(VSN)/src
	(cd releases;tar zcvf xmlrpc-$(VSN).tgz xmlrpc-$(VSN))
