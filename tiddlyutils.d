/*
 * Assumes the template is TW 5.2 or later. Will not work with old TW versions.
 * 
 * --stdout: Output the tiddlers to the screen.
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
bool stdout = false;
bool strip = false;
bool update = false;

void main(string[] args) {
	auto rslt = getopt(args,
		"tasks|t", tasksDoc, &tasks,
		"blocks|b", &blocks,
		"filter|f", &filters,
		"input|i", &input,
		"single|s", &singles,
		"markdown|m", &markdown,
		"path|p", &path,
		"output|o", &output,
		"tiddlers", tiddlersDoc, &tiddlersFile,
		"stdout", stdoutDoc, &stdout,
		"strip", &strip,
		"update", &update);
	if (rslt.helpWanted) {
		defaultGetoptPrinter(programDoc, rslt.options);
	}
	
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
	// This is the interesting part of the code
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
		foreach(a; actions) {
			writeln(a.qualifiers);
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
		} else if (stdout) {
			writeln(tiddlers);
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
	bool qualified = false;
	string[] qualifiers;
	
	this(string _action, string _dir) {
		action = _action;
		string[] ds = _dir.split("{");
		// No pattern
		if (ds.length == 1) {
			string[] ds2 = _dir.split("@");
			// No qualifiers
			if (ds2.length == 1) {
				dir = _dir;
				pattern = "*";
			// Qualifiers
			} else {
				dir = ds2[0];
				qualified = true;
				foreach(q; ds2[1..$]) {
					qualifiers ~= "@" ~ q;
				}
			}
		// Pattern
		} else {
			string[] ds2 = ds[0].split("@");
			// No qualifiers
			if (ds2.length == 1) {
				dir = ds[0];
				pattern = ds[1][0..$-1];
			// Qualifiers
			} else {
				dir = ds2[0];
				qualified = true;
				foreach(q; ds2[1..$]) {
					qualifiers ~= "@" ~ q;
				}
				pattern = ds[1][0..$-1];
			}
		}
	}
	
	string asTiddler() {
		if (action == "tasks") {
			string result;
			if (qualified) {
				foreach(q; qualifiers) {
					result ~= createTiddler(processTasks(q), "Open " ~ q ~ " tasks in " ~ dir);
				}
			} else {
				result = createTiddler(processTasks(), "Open tasks in " ~ dir);
			}
			return result;
		} else if (action == "blocks") {
			// Many tiddlers
			return processBlocks();
		} else if (action == "filter") {
			return createTiddler(`<<list-links filter:'` ~ dir ~ `'>>`, pattern);
		} else {
			return "Action " ~ action ~ " not supported";
		}
	}
	
	/* If dir ends with @foo, only capture those tasks */
	string processTasks(string qualifier="") {
		string mdfile;
		string[] files;
		foreach(f; std.file.dirEntries(expandTilde(dir), pattern, SpanMode.shallow).array.sort!"a > b") {
			if (f.isFile) {
				string tasks;
				if (qualified) {
					tasks = openTasks(f, qualifier);
				} else {
					tasks = openTasks(f);
				}
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
string openTasks(string f, string qualifier="") {
	writeln("Inside file: ", f);
	writeln("-------------------------");
	string content = readText(f);
	
	string result;
	bool insideTask = false;
	string thisTask;
	foreach(ii, line; content.split("\n")) {
		writeln(ii, " ", insideTask);
		if (insideTask) {
			if (line.newTask) {
				if (thisTask.includesQualifier(qualifier)) {
					writeln("+--------------+");
					writeln("+ Contains qualifier " ~ qualifier);
					writeln(thisTask);
					writeln("----------------");
					result ~= thisTask;
					thisTask = line ~ "\n";
				}
				writeln(ii, " Resetting task, currently equal to ", thisTask);
				thisTask = line ~ "\n";
			}
			
			if (line.leftTask) {
				if (thisTask.includesQualifier(qualifier)) {
					writeln("+--------------+");
					writeln("+ Contains qualifier " ~ qualifier);
					writeln(thisTask);
					writeln("----------------");
					result ~= thisTask;
				}
				insideTask = false;
				thisTask = "";
			}
		}
		
		// I know how to use else
		if (!insideTask) {
			if (line.startsWith("- [ ] ")) {
				thisTask = line ~ "\n";
				insideTask = true;
			}
		}
	}
	result ~= thisTask;
	return result;
}

/* Returns true if the task includes the qualifier OR if
 * there is no qualifier */
bool includesQualifier(string task, string qualifier) {
	if (qualifier == "") {
		return true;
	} else if (task.indexOf(qualifier) > 0) {
		return true;
	} else {
		return false;
	}
}

bool blankLine(string line) {
	return (line._strip == "") & (!line.startsWith("  "));
}

bool newBullet(string line) {
	return line.startsWith("- ");
}

bool newTask (string line) {
	return line.startsWith("- [ ] ");
}

bool leftTask(string line) {
	return blankLine(line) | (newBullet(line) & !newTask(line));
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

/* Documentation */
enum programDoc = `tiddlyutils is a program that converts the information in markdown files into a TiddlyWiki file that can be loaded in the browser and read, queried, and filtered.

Directories of markdown files are specified as dir{pattern}, where {pattern} is an optional pattern. For example, ~/dir1{z*.md} specifies all markdown files that start with z in ~/dir1.

Task qualifiers start with @, and go after the directory name.

Usage: tu [options]

where the options are
`;
enum tasksDoc = `Convert the open tasks from the markdown files in the specified directory into tiddlers`;
enum tiddlersDoc = `Save the created tiddlers in the file you've specified`;
enum stdoutDoc = `Print the created tiddlers to the screen`;
