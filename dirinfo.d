module tu.dirinfo;
import tu.blocks, tu.common;
import std.algorithm, std.array, std.file, std.path, std.regex, std.string;

/* For processing a directory, with an optional pattern */
struct DirInfo {
	string action;
	string dir;
	string pattern = "*";
	bool qualified = false;
	string[] qualifiers;
	string[] blockTypes;
	
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
				auto tiddlyblocks = TiddlyBlocks(readText(f), re);
				blockTypes = tiddlyblocks.blockTypes();
				foreach(block; tiddlyblocks.blocks) {
					tiddlers ~= block.html() ~ "\n";
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
	//~ writeln("Inside file: ", f);
	//~ writeln("-------------------------");
	string content = readText(f);
	
	string result;
	bool insideTask = false;
	string thisTask;
	foreach(ii, line; content.split("\n")) {
		//~ writeln(ii, " ", insideTask);
		if (insideTask) {
			if (line.newTask) {
				if (thisTask.includesQualifier(qualifier)) {
					//~ writeln("+--------------+");
					//~ writeln("+ Contains qualifier " ~ qualifier);
					//~ writeln(thisTask);
					//~ writeln("----------------");
					result ~= thisTask;
					thisTask = line ~ "\n";
				}
				//~ writeln(ii, " Resetting task, currently equal to ", thisTask);
				thisTask = line ~ "\n";
			}
			
			if (line.leftTask) {
				if (thisTask.includesQualifier(qualifier)) {
					//~ writeln("+--------------+");
					//~ writeln("+ Contains qualifier " ~ qualifier);
					//~ writeln(thisTask);
					//~ writeln("----------------");
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
	return (line.strip == "") & (!line.startsWith("  "));
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

