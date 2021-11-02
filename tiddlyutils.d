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
 */
import std.algorithm, std.array, std.datetime, std.exception, std.file, std.path;
import std.process, std.string;

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
