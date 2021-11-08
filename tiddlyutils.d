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
 * 
 * Option 'multi' combines multiple queries into one TW file. The second
 * argument says what to do. action:dir{pattern} for actions tasks or blocks.
 * filter:f{t} to include a list of tiddlers that come up for that filter.
 * f is the filter and t is the title to give it. Example:
 * filter:[type[review]]{Review blocks}
 */
import std.algorithm, std.array, std.conv, std.datetime, std.exception;
import std.file, std.getopt, std.path;
import std.process, std.regex, std.stdio, std.string;
alias _strip = std.string.strip;

string[] tasks;
string[] blocks;
string[] filters;
string[] singles;
string[] markdown;
string input = "empty52.html";
string output = "twsite.html";
string tiddlersFile;
string path = "";
string type;
bool strip = false;
bool update = false;

void main(string[] args) {
	getopt(args,
		"tasks|t", &tasks,
		"blocks|b", &blocks,
		"filter|f", &filters,
		"input|i", &input,
		"single|s", &singles,
		"path|p", &path,
		"output|o", &output,
		"tiddlers", &tiddlersFile,
		"strip", &strip,
		"update", &update,
		"type", &type);
	
	input = expandTilde(setExtension(input, "html"));
	output = expandTilde(setExtension(output, "html"));

	if (strip) {
		enforce(!exists("usercontent.html"), "Cannot run tiddlyutils strip if usercontent.html already exists. Rename that file or delete it and rerun this command.");			
		enforce(output != input, "output and input cannot be the same file");
		string f = readText(input);
		string txt1 = `<script class="tiddlywiki-tiddler-store" type="application/json">[
{`;
		string txt2 = `}
]</script><div id="storeArea" style="display:none;"></div>`;
		string[] tid1 = f.split(txt1);
		string[] tid2 = tid1[1].split(txt2);
		std.file.write("top.html", tid1[0] ~ txt1);
		std.file.write("bottom.html", txt2 ~ tid2[1]);
		
		string currentContent = std.string.strip(tid2[0]);
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

	} else if (update) {
		string f = readText(input);
		string txt1 = `<script class="tiddlywiki-tiddler-store" type="application/json">[
{`;
		string txt2 = `}
]</script><div id="storeArea" style="display:none;"></div>`;
		string[] tid1 = f.split(txt1);
		string[] tid2 = tid1[1].split(txt2);
		std.file.write("top.html", tid1[0] ~ txt1);
		std.file.write("bottom.html", txt2 ~ tid2[1]);
		
		string currentContent = std.string.strip(tid2[0]);
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
	} else {
		DirInfo[] actions;
		foreach(dir; blocks) {
			actions ~= DirInfo("blocks", dir);
		}
		foreach(dir; tasks) {
			actions ~= DirInfo("tasks", dir);
		}
		foreach(f; filters) {
			actions ~= DirInfo("filter", f);
		}
		string tiddlers = actions.map!(a => a.asTiddler()).join("\n");
		foreach(f; singles) {
			if (extension(f) == ".html") {
				tiddlers ~= readText(f);
			} else {
				tiddlers ~= convertTiddler(expandTilde(path ~ "/" ~ f));
			}
		}
		foreach(dir; markdown) {
			foreach(f; std.file.dirEntries(dir, "*.md", SpanMode.shallow).array.sort!"a > b") {
				tiddlers ~= convertTiddler(f);
			}
		}
		if (tiddlersFile.length > 0) {
			std.file.write(setExtension(expandTilde(tiddlersFile), "html"), tiddlers);
			writeln("Created tiddlers file at " ~ tiddlersFile);
		} else {
			std.file.write(output, readText(input).replace(
				`<div id="storeArea" style="display:none;"></div>`,
				`<div id="storeArea" style="display:none;">`
				~ tiddlers ~ `</div>`));
			writeln("Created file " ~ output);
		}
	}
}

/* Create a tiddler out of a string */
string createTiddler(string s, string title) {
	string timestamp = Clock.currTime.toISOString().replace("T", "").replace(".", "");
	return `<div created="` ~ timestamp ~ `" modified="` ~ timestamp ~ `" title="` ~ title ~ `">
<pre>
` ~ s.toHtml.deangle ~ `
</pre></div>
`;
}

/* Converts a markdown file to a tiddler 
 * f is the filename */
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

/* For processing a directory, with an optional pattern */
struct DirInfo {
	string action;
	string dir;
	string pattern = "*";
	
	this(string s) {
		auto ind1 = s.indexOf(":");
		enforce(ind1 > 0, "In " ~ s ~ ": You have to specify the action on a directory in the form action:dir");
		action = s[0..ind1]._strip;
		auto ind2 = s.indexOf("{", ind1);
		if (ind2 > 0) {
			auto ind3 = s.indexOf("}", ind2);
			enforce(ind3 > 0, "Missing closing } in " ~ s);
			dir = s[ind1+1..ind2]._strip;
			pattern = s[ind2+1..ind3]._strip;
		} else {
			dir = s[ind1+1..$]._strip;
		}
	}
	
	this(string _action, string _dir) {
		action = _action;
		string[] ds = _dir.split("{");
		if (ds.length == 1) {
			dir = _dir;
			pattern = "*";
		} else {
			dir = ds[0];
			pattern = ds[1][0..$-1];
		}
	}		
	
	string asTiddler() {
		if (action == "tasks") {
			// One tiddler holding all tasks
			return createTiddler(processTasks(), "Open tasks in " ~ dir);
		} else if (action == "blocks") {
			// Many tiddlers
			return processBlocks();
		} else if (action == "filter") {
			return createTiddler(`<<list-links filter:'` ~ dir ~ `'>>`, pattern);
		} else {
			return "Action " ~ action ~ " not supported";
		}
	}
	
	string processTasks() {
		string mdfile;
		string[] files;
		foreach(f; std.file.dirEntries(expandTilde(dir), pattern, SpanMode.shallow).array.sort!"a > b") {
			if (f.isFile) {
				string tasks = openTasks(f);
				if (tasks.length > 0) {
					mdfile ~= "# " ~ stripExtension(baseName(f)) ~ "\n\n" ~ tasks ~ "\n\n";
				}
			}
		}
		return mdfile;
	}
	
	string processBlocks() {
		auto re = regex(`<pre><tiddly>.*?</tiddly></pre>`, "s");
		string tiddlers;
		foreach(f; std.file.dirEntries(expandTilde(dir), pattern, SpanMode.shallow).array.sort!"a > b") {
			if (f.isFile) {
				foreach(tmp; convertTiddlers(tiddlyBlocks(readText(f), re))) {
					tiddlers ~= tmp ~ "\n";
				}
			}
		}
		return tiddlers;
	}
}

/* Find all open tasks in a markdown file 
 * Return a markdown list holding them
 * f is the filename */
string openTasks(string f) {
	string content = readText(f);
	
	string result;
	bool insideTask = false;
	foreach(line; content.split("\n")) {
		if (insideTask) {
			/* No longer inside a task AND don't add to the list if
			 * blank line not indented four spaces or a new list item that's
			 * not a task */
			if (((line._strip == "") & (!line.startsWith("    "))) | (line.startsWith("- ") & !line.startsWith("- [ ] "))) {
				insideTask = false;
			} else {
				result ~= line ~ "\n";
			}
		} else {
			if (line.startsWith("- [ ] ")) {
				result ~= line ~ "\n";
				insideTask = true;
			}
		}
	}
	return result;
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

/* Returns all the tiddly blocks in a markdown file as an array */
string[] tiddlyBlocks(string s, Regex!char re) {
  string[] result;
  foreach(m; s.matchAll(re)) {
    result ~= m[0].to!string["<pre><tiddler>".length..$-"</pre></tiddler>".length];
  }
  return result;
}

/* Converts an array of tiddly blocks to tiddlers */
string[] convertTiddlers(string[] tiddlers) {
	string aux(string s, string result="<div") {
		long ind = s.indexOf("\n");
		auto line = s[0..ind];
		if (line.startsWith("---")) {
			string content = s[ind+1..$];
			return result ~ "><pre>" ~ content.toHtml().deangle ~ "</pre></div>";
		} else {
			string[] data = line.split(":");
			string attr = data[0]._strip ~ `="` ~ data[1]._strip ~ `"`;
			if (data[0]._strip == "created") {
				attr ~= ` modified="` ~ data[1]._strip ~ `"`;
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
