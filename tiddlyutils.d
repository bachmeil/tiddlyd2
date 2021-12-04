/*
 * Assumes the template is TW 5.2 or later. Will not work with old TW versions.
 * 
 * --stdout: Output the tiddlers to the screen.
 */
import tu.blocks, tu.common, tu.dirinfo;
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
string defaults = "";
string wikiname = "";
bool stdout = false;
bool strip = false;
bool update = false;

void main(string[] args) {
	auto rslt = getopt(args,
		"tasks|t", tasksDoc, &tasks,
		"blocks|b", blocksDoc, &blocks,
		"filter|f", filterDoc, &filters,
		"input|i", inputDoc, &input,
		"single|s", singleDoc, &singles,
		"markdown|m", markdownDoc, &markdown,
		"path|p", pathDoc, &path,
		"defaults", defaultsDoc, &defaults,
    "wikiname", wikinameDoc, &wikiname,
		"output|o", outputDoc, &output,
		"tiddlers", tiddlersDoc, &tiddlersFile,
		"stdout", stdoutDoc, &stdout,
		"strip", stripDoc, &strip,
		"update", updateDoc, &update);
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
		foreach(dir; tasks) {
			actions ~= DirInfo("tasks", dir);
		}
		foreach(f; filters) {
			actions ~= DirInfo("filter", f);
		}
		string tiddlers;
		if (blocks.length > 0) {
      auto re = regex(`<pre><tiddly>.*?</tiddly></pre>`, "s");
      // Set up TOC
			tiddlers ~= tocTiddler();
      TiddlyBlocks tb;
      tb.wikiname = wikiname;
      foreach(dir; blocks) {
        foreach(f; std.file.dirEntries(expandTilde(dir), "*.md", SpanMode.shallow)) {
          tb.add(f, re);
        }
      }
      string[] types = tb.blockTypes;
      foreach(type; types) {
        string ts = timestamp();
        tiddlers ~= `<div gen="true" created="` ~ ts ~ `" modified="` ~ ts ~ 
        `" title="` ~ type ~ ` index" tags="TableOfContents">
<pre>
` ~ (`<<list-links filter:"[type[` ~ type ~ `]]">>`).deangle ~ `
</pre></div>
`;      
      }
      foreach(block; tb.blocks) {
        tiddlers ~= block.html ~ "\n";
      }
      tiddlers ~= defaultTab();
		}
		tiddlers ~= actions.map!(a => a.asTiddler()).join("\n");
		foreach(f; singles) {
			if (exists(f)) {
				if (extension(f) == ".html") {
					tiddlers ~= readText(f);
				} else {
					tiddlers ~= convertTiddler(expandTilde(path ~ "/" ~ f));
				}
			}
		}
		foreach(dir; markdown) {
			foreach(f; std.file.dirEntries(dir, "*.md", SpanMode.shallow).array.sort!"a > b") {
				tiddlers ~= convertTiddler(f);
			}
		}
		if (defaults != "") {
			tiddlers ~= createTiddler(defaults, "$:/DefaultTiddlers", false);
		}
		if (tiddlersFile.length > 0) {
			std.file.write(setExtension(expandTilde(tiddlersFile), "html"), tiddlers);
		} else if (stdout) {
			writeln(tiddlers);
		} else {
			std.file.write(output, readText(input).replace(
				`<div id="storeArea" style="display:none;"></div>`,
				`<div id="storeArea" style="display:none;">`
				~ tiddlers ~ `</div>`));
		}
	}
}

/* Returns all the tiddly blocks in a markdown file as an array */
//~ string[] tiddlyBlocks(string s, Regex!char re) {
  //~ string[] result;
  //~ foreach(m; s.matchAll(re)) {
    //~ result ~= m[0].to!string["<pre><tiddler>".length..$-"</pre></tiddler>".length];
  //~ }
  //~ return result;
//~ }

/* Converts an array of tiddly blocks to tiddlers */
//~ string[] convertTiddlers(string[] tiddlers, string f, string wikiname) {
  //~ string id;
	//~ string aux(string s, string result=`<div gen="true" `) {
		//~ long ind = s.indexOf("\n");
		//~ auto line = s[0..ind];
		//~ if (line.startsWith("---")) {
			//~ string content = s[ind+1..$] ~ `<br><br><a href="{edit}?wikiname=` ~ wikiname ~ `&file=` ~ f ~ `&id=` ~ id ~ `">Edit this tiddler</a>`;
			//~ return result ~ "><pre>" ~ content.toHtml().deangle ~ "</pre></div>";
		//~ } else {
			//~ string[] data = line.split(":");
			//~ string attr = data[0]._strip ~ `="` ~ data[1]._strip ~ `"`;
			//~ if (data[0]._strip == "created") {
				//~ attr ~= ` modified="` ~ data[1]._strip ~ `"`;
        //~ id = data[1]._strip;
			//~ }
			//~ return aux(s[ind+1..$], result ~ " " ~ attr);
		//~ }
	//~ }
	
	//~ string[] result;
	//~ foreach(tiddler; tiddlers) {
		//~ result ~= aux(tiddler);
	//~ }
	//~ return result;
//~ }

/* Documentation */
enum programDoc = `tiddlyutils is a program that converts the information in markdown files into a TiddlyWiki file that can be loaded in the browser and read, queried, and filtered.

Directories of markdown files are specified as dir{pattern}, where {pattern} is an optional pattern. For example, ~/dir1{z*.md} specifies all markdown files that start with z in ~/dir1.

Task qualifiers start with @, and go after the directory name.

Usage: tu [options]

where the options are
`;
enum tasksDoc = `Convert the open tasks from the markdown files in the specified directory into tiddlers`;
enum blocksDoc = `Convert the tiddly blocks in the markdown files in this directory to individual tiddlers`;
enum filterDoc = `Add this filter as a tiddler using the list-links macro`;
enum inputDoc = `The name of a TiddlyWiki file to use as the template for your TiddlyWiki. Cannot be the same as parameter output.`;
enum singleDoc = `If an html file, will be treated as a group of tiddlers and added directly to your wiki. Normally this will be the output of a previous run of tiddlyutils with option tiddlers. If a markdown file, will be converted to its own tiddler.`;
enum markdownDoc = `The name of a directory. All markdown files in that directory will be converted into individual tiddlers.`;
enum outputDoc = `The name of the output file for your TiddlyWiki`;
enum tiddlersDoc = `Save the created tiddlers in the file you've specified`;
enum stdoutDoc = `Print the created tiddlers to the screen`;
enum pathDoc = `If specified, this path is appended to all markdown files specified using the single option.`;
enum stripDoc = `Not currently used`;
enum updateDoc = `Not currently used`;
enum defaultsDoc = `Space-separated list of tiddlers to show when the wiki is first opened. If the name has spaces, use brackets: 'tiddler1 [[Tiddler with spaces in the name]] [[Another tiddler with spaces in the name]] tiddler 4'`;
enum wikinameDoc = `Name of the wiki. Optional. Can be used to add info to edit links.`;
