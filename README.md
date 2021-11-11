# tiddlyd2

## Overview

Converts individual markdown files and directories of markdown files into a TiddlyWiki file. The goal is to support multiple systems for creating markdown files (Obsidian, Dendron, Logseq, VS Code, Geany, Emacs, Vim, etc.) The TiddlyWiki file can be opened directly in a browser, without a running web server, and you'll have all the power of tags, backlinks, filters, search, and so on provided by TiddlyWiki.

## Motivation

An example to motivate this project:

```
tiddlyutils --tasks ~/taskdir --single ~/foo.html --single ~/bar.md
```

This creates a new TiddlyWiki file titled twsite.html holding three tiddlers. The first will be the open tasks from the 14 markdown files you created for some of your projects in directory `~/taskdir` using Emacs. The second tiddler will be a few tiddlers you created manually that you want included when you review your open tasks. The third tiddler will be a conversion of the contents of file `bar.md`. It's a markdown file you created in Obsidian with links to podcasts you're listening to each day as you eat lunch.

You open twsite.html in your browser and throughout the day you are able to review the things you have to do to stay on top of all of your active projects. At lunch time, you look at the podcast links to see which you're in the mood to listen to. At the end of the day, you review the remaining open tasks and decide your priorities for tomorrow.

This is helpful, but you realize you're looking at more than 100 open tasks every time you open your browser. You're burning through a lot of energy deciding which tasks are relevant and which aren't over and over again each day. There's no good reason to decide "Get Fluffy neutered" isn't relevant to your work at the office eight times a day. You can [specify a pattern](https://dlang.org/phobos/std_path.html#globMatch) to select the relevant files in `~/taskdir`. Since every file related to home ends with `- home.md` and every file related to work ends with `- work.md`, you can narrow the files you're pulling tasks from by appending a pattern to the directory name:

```
tiddlyutils --tasks '~/taskdir{*- work.md}' --single ~/foo.html --single ~/bar.md
```

Single quotes have been added to avoid problems caused by the space in the pattern. That's an improvement, but you're still seeing too much information in the task list. If you use David Allen's GTD method, you're thinking in terms of next actions (the ones you should be working on when you decide to work on that project), future actions (you need to work on them to complete the project, but you can't do them now), and someday/maybe actions (things you're considering doing for the project, but you haven't made a decision one way or the other). 

You have a tasks file that looks like this:

```
- [ ] Finish function bar for libfoo
- [ ] Finish function baz for libfoo
- [ ] Test libfoo
- [ ] Convert the entire codebase to libfoo if it's performant
```

There's no point seeing the last two tasks if the first two aren't done. You're definitely going to test the library, but you can't do that until you've written the last two functions, so that's a future task. The last one is conditional on information you don't currently have, so you can't decide if you're going to make a commitment to doing it. You add qualifiers (arbitrary text starting with `@` and not including newlines) to your tasks to facilitate a more fine-grained review:

```
- [ ] Finish function bar for libfoo @next
- [ ] Finish function baz for libfoo @next
- [ ] Test libfoo @future
- [ ] Convert the entire codebase to libfoo if it's performant @maybe
```

During work, you only want to see your next actions for work projects, so you modify the call to

```
tiddlyutils --tasks '~/taskdir@next{*- work.md}' --single ~/foo.html --single ~/bar.md
```

and you have a tiddler with only tasks qualified with `@next` in files that end with `- work.md`. When you're planning for the upcoming week on Sunday night, you want to view next actions and future tasks, so you use the call

```
tiddlyutils --tasks '~/taskdir@next@future@maybe{*- work.md}' --single ~/foo.html --single ~/bar.md
```

That gives you one tiddler with next actions for all work projects, another with future actions, and a third with someday/maybe items. Once you've reviewed all the tasks you've committed to doing, you can open up the someday/maybe items to see if you're ready to commit to doing or not doing some of them.

## Original (some parts may no longer be accurate)

This is an in-progress project to provide tools for working with TiddlyWiki using D rather than Javascript. The current goals are:

- Provide a server that separates the tiddler file from the several MB of other code that make up the main TiddlyWiki app. The vast majority of space taken by TiddlyWiki is allocated to the app itself rather than the user's content. That makes it a mess to put under version control. Not only is it difficult to work with large files that have extremely long lines (open it in a text editor and start scrolling if you aren't familiar with the inside of TiddlyWiki), it is inconvenient to view just the content of your files, which is normally all you want to do anyway.
- Provide an app that converts a directory of markdown files into a TiddlyWiki site. The generated site can include subdirectories if desired.
- Provide an app that scans a directory of markdown files for "tiddly blocks" and convert them into a TiddlyWiki site. The motivation for this is my use of daily pages in Obsidian. I love the convenience and organization provided by daily pages. Unfortunately, it's not the best experience to review important data (like tasks you have to do or links you encounter during the day) across all your daily pages. This allows me to enter data directy in my daily pages using templates, then automate the process of reviewing only the important stuff. IMO, TiddlyWiki is a weak option for entering content, but the best option for querying and reviewing it.
    - Note: Conversion of directories was motivated by my use of Obsidian. There's nothing specific to Obsidian. The same could be done using a system like Dendron or a simple text editor like Geany to create the markdown files.
- Support any recent (version 5.2 or later) TiddlyWiki file as a template for the generated site. That means you can make any customizations, install plugins, install themes, or whatever, and build your site with it.
