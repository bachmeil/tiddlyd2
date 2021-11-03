import arsd.cgi;
import std.file, std.path, std.string;

void hello(Cgi cgi) {
  cgi.header("x-api-access-type: file");
  cgi.header("dav: tw5/put");

	string filename;
	string fn = "empty52";
	if (cgi.pathInfo == "/") {
		filename = "empty52.html";
	} else {
	  //filename = setExtension(cgi.pathInfo[1..$], "html");
	  filename = "empty52.html";
	}
	
  if (cgi.requestMethod.to!string == "PUT") {
    std.file.write("usercontent.html", removeApp(cgi.postBody));
  } else if (cgi.requestMethod.to!string == "GET") {
		if (filename.exists) {
			if (exists("usercontent.html")) {
				cgi.write(readText(fn ~ "_top.html") ~ readText("core.html") ~ readText("plugins.html") ~ readText("usercontent.html") ~ readText(fn ~ "_bottom.html"));
			} else {
				cgi.write("You need to run tiddlyutils strip to create your template file, core.html, and usercontent.html");
			}
		}
	}
}
mixin GenericMain!hello;

string removeApp(string htmlfile) {
	string txt1 = `<script class="tiddlywiki-tiddler-store" type="application/json">[
{`;
	string txt2 = `}
]</script><div id="storeArea" style="display:none;"></div>`;
	string[] tid1 = htmlfile.split(txt1);
	string[] tid2 = tid1[1].split(txt2);
	string currentContent = tid2[0];
	string strippedContent;
	foreach(line; currentContent.split("\n")) {
		if (line.startsWith(`"title":"$:/core",`) | line.startsWith(`{"title":"$:/plugins`)) {
		} else {
			if (line.length > 50) {
				writeln(line[0..50]);
			} else {
				writeln(line);
			}
			strippedContent ~= line ~ "\n";
		}
	}
	return strippedContent;
}
