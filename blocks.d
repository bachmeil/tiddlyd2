module tu.blocks;
import tu.common;
import std.conv, std.file, std.regex, std.string;

struct Block {
	string title;
	string type = "no type given";
	string[] tags;
	string content;
	string filename;
  string wikiname;
	string[string] other;
	
	void add(string b, string _filename, string _wikiname) {
    filename = _filename;
    wikiname = _wikiname;
    
		void aux(string s) {
			auto ind = s.indexOf("\n");
			auto line = s[0..ind];
			if (line.strip == "---") {
				content = s[ind+1..$];
				return;
			} else {
				string[] data = line.split(":");
        // Allow blank lines
        if (data.length > 1) {
          data[0] = data[0].strip;
          data[1] = data[1].strip;
          switch(data[0]) {
            case "title":
              title = data[1];
              break;
            case "type":
              type = data[1];
              tags ~= data[1] ~ "_index";
              break;
            case "tags":
              tags ~= data[1];
              break;
            default:
              other[data[0]] = data[1];
              break;
          }
        }
			}
      return aux(s[ind+1..$]);
		}
    aux(b);
	}
	
	string html() {
		string ts = timestamp();
		string div = `<div gen="true" title="` ~ title 
      ~ `" type="` ~ type 
      ~ `" tags="` ~ tags.join(" ")
      ~ `" created="` ~ ts 
      ~ `" modified="` ~ ts ~ `">`;
		string editlink = `<a href="{edit}?wikiname=` ~ wikiname 
      ~ `&file=` ~ filename 
      ~ `&id=` ~ ts ~ `">Edit this tiddler</a>`;
    return div ~ `<pre>` 
      ~ (content ~ "<br><br>" ~ editlink).toHtml().deangle ~
			`</pre></div>`;
	}
}

struct TiddlyBlocks {
	Block[] blocks;
  string wikiname;
  
  alias blocks this;
	
	this(string fn, Regex!char re) {
		add(fn, re);
	}
  
  void add(string fn, Regex!char re) {
		string s = readText(fn);
    enum len1 = "<pre><tiddly>".length;
    enum len2 = "</pre></tiddly>".length;
		foreach(match; s.matchAll(re)) {
      Block bb;
      bb.add(match[0].to!string[len1..$-len2], fn, wikiname);
			blocks ~= bb;
		}
	}
  
  string tocTypes() {
    string result;
    foreach(type; blockTypes()) {
      string ts = timestamp();
      result ~= `<div gen="true" created="` ~ ts ~ `" modified="` ~ ts ~ 
        `" title="` ~ type ~ `_index" tags="TableOfContents">
<pre>
` ~ (`<<list-links filter:"[type[` ~ type ~ `]]">>`).deangle ~ `
</pre></div>
`;      
    }
    return result;
  }    

	string[] blockTypes() {
		int[string] result;
		foreach(b; blocks) {
			result[b.type] = 1;
		}
		return result.keys;
	}
}

string tocTiddler() {
	string ts = timestamp();
	return `<div created="` ~ ts ~ `" modified="` ~ ts ~ `" title="TableOfContents" tags="$:/tags/SideBar" caption="Contents" list-after="$:/core/ui/SideBar/Open">
<pre>
` ~ `<div class="tc-table-of-contents">

<<toc-selective-expandable 'TableOfContents'>>

</div>`.deangle ~ `
</pre></div>
`;
}
