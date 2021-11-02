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
 */
import std.algorithm, std.array, std.datetime, std.exception, std.file, std.path;
import std.process, std.stdio, std.string;

void main(string[] args) {
	enforce(args.length > 1, "You have to supply arguments to tiddlyutils");
	
	if ( (args[1] == "md") | (args[1] == "deepmd") ) {
		// args[2]: dir args[3]: template args[4]: outputfile
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
		string outputFile = "twsite.html";
		if (args.length > 4) {
			outputFile = setExtension(expandTilde(args[4]), "html");
		}
		string templateFile = setExtension(expandTilde(args[3]), "html");
		std.file.write(outputFile, readText(templateFile).replace(
			`<div id="storeArea" style="display:none;"></div>`,
			`<div id="storeArea" style="display:none;">`
			~ tiddlers
			~ `</div>`));
	} else if (args[1] == "blocks") {
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
		std.file.write(args[2] ~ "_top.html", tid1[0] ~ txt1);
		std.file.write(args[2] ~ "_bottom.html", txt2 ~ tid2[1]);
		
		string currentContent = tid2[0].strip;
		string strippedContent;
		foreach(line; currentContent.split("\n")) {
			if (line.startsWith(`"title":"$:/core",`)) {
				std.file.write("core.html", line);
			} else {
				if (line.length > 50) {
					writeln(line[0..50]);
				} else {
					writeln(line);
				}
				strippedContent ~= line ~ "\n";
			}
		}
		std.file.write("usercontent.html", strippedContent);
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
