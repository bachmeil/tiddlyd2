server:
	ldmd2 server.d cgi.d -oftiddly.exe -version=embedded_httpd
	mv tiddly.exe ~/bin/tiddly
	rm *.o

utils:
	ldmd2 tiddlyutils.d -oftiddlyutils.exe
	mv tiddlyutils.exe ~/bin/tiddlyutils
	rm *.o
