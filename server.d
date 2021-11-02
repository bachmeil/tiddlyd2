import arsd.cgi;
import std.file, std.path, std.string;

void hello(Cgi cgi) {
  cgi.header("x-api-access-type: file");
  cgi.header("dav: tw5/put");

	string filename;
	if (cgi.pathInfo == "/") {
		filename = "empty.html";
	} else {
	  filename = setExtension(cgi.pathInfo[1..$], "html");
	}
	
  if (cgi.requestMethod.to!string == "PUT") {
		string tid = cgi.postBody;
		std.file.write("log.html", tid);
		string[] tid1 = tid.split("<!--~~ Ordinary tiddlers ~~-->");
		// Pull out the stuff on the inside and parse with std.json
		// Omit all tiddlers based on the configuration variable at the top
		string[] tid2 = tid1[1].split("<!--~~ Library modules ~~-->");
		ulong ind1 = tid2[0].indexOf(`<div author="JeremyRuston" core-version="&gt;=5.0.0" dependents="" description="Basic theme" `); 
		ulong ind2 = tid2[0].indexOf("<div created=\"", ind1);
    std.file.write("usercontent.html", tid2[0][ind2..$].strip[0..$-6].strip ~ "\n");
  } else if (cgi.requestMethod.to!string == "GET") {
		//~ if (filename.exists) {
			string htmlFile = readText("wikitop.html") ~ readText("usercontent.html") ~ readText("wikibottom.html");
			cgi.write(htmlFile);
		//~ } else {
			//~ cgi.write("There's no file named " ~ filename);
		//~ }
  }
}
mixin GenericMain!hello;
