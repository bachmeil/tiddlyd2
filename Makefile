utils:
	ldmd2 tiddlyutils.d blocks.d common.d dirinfo.d -oftiddlyutils.exe
	mv tiddlyutils.exe ~/bin/tu
	rm *.o

server:
	ldmd2 server.d cgi.d -oftiddly.exe -version=embedded_httpd
	mv tiddly.exe ~/bin/tiddly
	rm *.o

