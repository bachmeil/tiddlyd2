/*
 * Options
 * 
 * Assumes the template is TW 5.2 or later. Will not work with old TW versions.
 * 
 * tiddlyutils md dir file1 [file2]: Convert the directory dir to a TiddlyWiki
 *   site using file1 as the template. If given, outputs to file2, which may
 *   have a full path. If not, outputs to twsite.html in the current directory.
 *   This version does not convert subdirectories.
 * tiddlyutils deepmd dir file1 [file2]: Same as md, but also converts subdirectories.
 * tiddlyutils blocks dir file1 [file2]: Pulls tiddly blocks out of all
 *   markdown files in dir and converts each block to a tiddler. file1 is the
 *   template and file2, if supplied, is the output file. Outputs to twsite.html if
 *   file2 is not supplied.
 * tiddlyutils strip file1 [file2]: For the server, removes the core TW tiddler
 *   that is most of the size of the file. Creates file2 and core.html. file2 cannot
 *   be the same as file1. If not specified, file2 is set to file1_stripped.html.
 * tiddlyutils update file1 will update core, top, bottom, and plugins. usercontent.html is not affected.
 */
import std.algorithm, std.array, std.conv, std.datetime, std.exception;
import std.file, std.path;
import std.process, std.regex, std.stdio, std.string;

void main(string[] args) {
	enforce(args.length > 1, "You have to supply arguments to tiddlyutils");
	
	if ( (args[1] == "md") | (args[1] == "deepmd") ) {
		// args[2]: dir args[3]: template
		string tiddlers;
		if (args[1] == "md") {
			foreach(f; std.file.dirEntries(expandTilde(args[2]), SpanMode.shallow).array.sort!"a > b") {
				if (f.isFile & (extension(f) == ".md")) {
					tiddlers ~= convertTiddler(f);
				}
			}
		} else {
			foreach(f; std.file.dirEntries(expandTilde(args[2]), SpanMode.depth).array.sort!"a > b") {
				if (f.isFile & (extension(f) == ".md")) {
					tiddlers ~= convertTiddler(f);
				}
			}
		}
		string templateFile = setExtension(expandTilde(args[3]), "html");
		std.file.write("twsite.html", readText(templateFile).replace(
			`<div id="storeArea" style="display:none;"></div>`,
			`<div id="storeArea" style="display:none;">`
			~ tiddlers
			~ `</div>`));
	} else if (args[1] == "blocks") {
	  auto re = regex(`<pre><tiddly>.*?</tiddly></pre>`, "s");
		string tiddlers;
		foreach(f; std.file.dirEntries(expandTilde(args[2]), SpanMode.shallow)) {
			if (f.isFile) {
				foreach(tmp; convertTiddlers(tiddlyBlocks(readText(f), re))) {
					tiddlers ~= tmp ~ "\n";
				}
			}
		}
		string templateFile = setExtension(expandTilde(args[3]), "html");std.file.write("obsidiantiddly.html", readText(templateFile).replace(
			`<div id="storeArea" style="display:none;"></div>`,
			`<div id="storeArea" style="display:none;">`
			~ tiddlers
			~ `</div>`));
	} else if (args[1] == "strip") {
		enforce(!exists("usercontent.html"), "Cannot run tiddlyutils strip if usercontent.html already exists. Rename that file or delete it and rerun this command.");			
		if (args.length > 3) {
			enforce(setExtension(args[3].strip, "html") != setExtension(args[2].strip, "html"));
		}
		string f = readText(setExtension(expandTilde(args[2]), "html"));
		string txt1 = `<script class="tiddlywiki-tiddler-store" type="application/json">[
{`;
		string txt2 = `}
]</script><div id="storeArea" style="display:none;"></div>`;
		string[] tid1 = f.split(txt1);
		string[] tid2 = tid1[1].split(txt2);
		std.file.write("top.html", tid1[0] ~ txt1);
		std.file.write("bottom.html", txt2 ~ tid2[1]);
		
		string currentContent = tid2[0].strip;
		string other;
		string core;
		foreach(line; currentContent.split("\n")) {
			if (line.startsWith(`"title":"$:/core",`)) {
				core ~= line ~ "\n";
			} else if (line.startsWith(`"title":"$:/plugin`)) {
				core ~= line ~ "\n";
			} else {
				if (line.length > 50) {
					writeln(line[0..50]);
				} else {
					writeln(line);
				}
				other ~= line ~ "\n";
			}
		}
		// Themes and any other stuff
		std.file.write("other.html", other);
		std.file.write("usercontent.html", other);
		// Core app and plugins, not user data, very large
		std.file.write("core.html", core);
	} else if (args[1] == "update") {
		string f = readText(setExtension(expandTilde(args[2]), "html"));
		string txt1 = `<script class="tiddlywiki-tiddler-store" type="application/json">[
{`;
		string txt2 = `}
]</script><div id="storeArea" style="display:none;"></div>`;
		string[] tid1 = f.split(txt1);
		string[] tid2 = tid1[1].split(txt2);
		std.file.write("top.html", tid1[0] ~ txt1);
		std.file.write("bottom.html", txt2 ~ tid2[1]);
		
		string currentContent = tid2[0].strip;
		string core;
		// Ignore the user's data
		// For updating core and plugins
		foreach(line; currentContent.split("\n")) {
			if (line.startsWith(`"title":"$:/core",`)) {
				core ~= line ~ "\n";
			} else if (line.startsWith(`{"title":"$:/plugins`)) {
				core ~= line ~ "\n";
			}
		}
		std.file.write("core.html", core);
	}
}

string convertTiddler(string f) {
	string content = readText(f);
	string filename = stripExtension(baseName(f));
	string timestamp = Clock.currTime.toISOString().replace("T", "").replace(".", "");
	return `<div created="` ~ timestamp ~ `" modified="` ~ timestamp ~ `" title="` ~ filename ~ `">
<pre>
` ~ content.toHtml.deangle ~ `
</pre></div>
`;
}

string toHtml(string md) {
	string cmd = "echo " ~ md.sq ~ " | pandoc -f markdown-smart+task_lists -t html";
	return executeShell(cmd).output;
}

// Handle single quotes properly for the shell
string sq(string s) {
	return `'` ~ s.replace(`'`, `'"'"'`) ~ `'`;
}

// Replace all angle brackets
string deangle(string s) {
	return s.replace("<", "&lt;").replace(">", "&gt;");
}

string[] tiddlyBlocks(string s, Regex!char re) {
  string[] result;
  foreach(m; s.matchAll(re)) {
    result ~= m[0].to!string["<pre><tiddler>".length..$-"</pre></tiddler>".length];
  }
  return result;
}

string[] convertTiddlers(string[] tiddlers) {
	string aux(string s, string result="<div") {
		long ind = s.indexOf("\n");
		auto line = s[0..ind];
		if (line.startsWith("---")) {
			string content = s[ind+1..$];
			return result ~ "><pre>" ~ content.toHtml().deangle ~ "</pre></div>";
		} else {
			string[] data = line.split(":");
			string attr = data[0].strip ~ `="` ~ data[1].strip ~ `"`;
			if (data[0].strip == "created") {
				attr ~= ` modified="` ~ data[1].strip ~ `"`;
			}
			return aux(s[ind+1..$], result ~ " " ~ attr);
		}
	}
	
	string[] result;
	foreach(tiddler; tiddlers) {
		result ~= aux(tiddler);
	}
	return result;
}
