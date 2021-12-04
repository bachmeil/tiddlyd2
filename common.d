/* Utilities common to all modules */
module tu.common;
import std.datetime, std.file, std.path, std.process, std.string;

string toHtml(string md) {
	string cmd = "echo " ~ md.sq ~ " | pandoc -f markdown-smart+task_lists -t html";
	return executeShell(cmd).output;
}

// Replace all angle brackets
string deangle(string s) {
	return s.replace("<", "&lt;").replace(">", "&gt;");
}

// Handle single quotes properly for the shell
string sq(string s) {
	return `'` ~ s.replace(`'`, `'"'"'`) ~ `'`;
}

string timestamp() {
	return Clock.currTime.toISOString().replace("T", "").replace(".", "");
}

string defaultTab() {
  return createTiddler("$:/core/ui/SideBar/Contents", "$:/config/DefaultSidebarTab", false);
}

/* Create a tiddler out of a string
 * If you set convert to false, it will not convert s to html.
 * That's useful for things like setting the default tiddlers. */
string createTiddler(string s, string title, bool convert=true) {
	string bodyText = s;
	if (convert) {
		bodyText = s.toHtml.deangle;
	}
	string timestamp = Clock.currTime.toISOString().replace("T", "").replace(".", "");
	return `<div gen="true" created="` ~ timestamp ~ `" modified="` ~ timestamp ~ `" title="` ~ title ~ `">
<pre>
` ~ bodyText ~ `
</pre></div>
`;
}

/* Converts a markdown file to a tiddler 
 * f is the filename */
string convertTiddler(string f) {
	string content = readText(f);
	string filename = stripExtension(baseName(f));
	//~ string timestamp = Clock.currTime.toISOString().replace("T", "").replace(".", "");
	string timestamp = timestamp();
	return `<div gen="true" created="` ~ timestamp ~ `" modified="` ~ timestamp ~ `" title="` ~ filename ~ `">
<pre>
` ~ content.toHtml.deangle ~ `
</pre></div>
`;
}

