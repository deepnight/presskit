import neko.Lib;

class Main {
	static var DEFAULT_SRC = "presskit.xml";
	static var DEFAULT_TPL = "tpl/default.html";
	static var DEFAULT_OUTPUT = "presskit";
	static var VERBOSE = false;
	static var LIST_REG = ~/^([ \t]*?)-\s+(.+?)$/gi;
	static var VAR_REG = ~/%([a-z0-9_]+)%/gi;
	static var DEPENDENCY_URI_REG = ~/["']([^"']*?(\.png|\.gif|\.jpeg|\.jpg|\.avi|\.mpg|\.mpeg|\.css))\??.*?["']/mi;

	static function main() {
		haxe.Log.trace = function(m, ?pos) {
			if ( pos != null && pos.customParams == null )
				pos.customParams = ["debug"];

			Lib.println(Std.string(m));
		}

		// Arguments
		if( Sys.args().length<=0 )
			usage();

		var args = new dn.Args(
			Sys.args().join(" "),
			[]
		);
		VERBOSE = args.hasArg("-v");

		var argSrc : Null<String> = null;
		var argTpl : Null<String> = null;

		for( a in args.getAllSoloValues() ) {
			if( a.toLowerCase().indexOf(".xml")>=0 )
				argSrc = dn.FilePath.cleanUp(a,true);
			else if( a.toLowerCase().indexOf(".json")>=0 )
				argSrc = dn.FilePath.cleanUp(a,true);
			else if( a.toLowerCase().indexOf(".html")>=0 )
				argTpl = dn.FilePath.cleanUp(a,true);
		}

		// Init dirs
		var haxelibDir = dn.FilePath.cleanUp( Sys.getCwd(), false );
		var tplFp = dn.FilePath.fromFile( argTpl!=null ? argTpl : haxelibDir +"/"+ DEFAULT_TPL);
		var projectDir = dn.FilePath.cleanUp( args.getLastSoloValue(), false );
		var srcFp = dn.FilePath.fromFile( argSrc!=null ? argSrc : projectDir+"/"+DEFAULT_SRC );
		verbose('Template: $tplFp');
		verbose('Source: $srcFp');

		var outputHtmlFile = srcFp.clone();
		outputHtmlFile.appendDirectory("output");
		outputHtmlFile.fileName = srcFp.fileName;
		outputHtmlFile.extension = "html";


		// Inits
		var srcKeys : Map<String,String> = new Map();
		var tplKeys : Map<String,String> = new Map();

		// Read source file
		Lib.println('Reading source file: ${srcFp.full}...');
		if( !sys.FileSystem.exists(srcFp.full) ) {
			if( argSrc==null )
				usage();
			else
				error('File not found: ${srcFp.full}', true);
		}
		var rawSrc = try sys.io.File.getContent(srcFp.full) catch(_) { error('Could not open: ${srcFp.full}'); null; }

		// Extract keys
		switch srcFp.extension.toLowerCase() {
			case "json":
				srcKeys = parseJson(rawSrc);

			case "xml":
				srcKeys = parseXml(rawSrc);

			case _:
				error("Unsupported source file extension: "+srcFp.extension);
		}

		// Parse HTML template
		verbose('Reading HTML template: ${tplFp.full}}...');
		var rawTpl = try sys.io.File.getContent(tplFp.full) catch(_) { error('Could not open: ${tplFp.full}'); null; }


		// List HTML keys
		var keysReg = ~/%([a-z_ ]+[0-9]*)%/im;
		var tmp = rawTpl;
		while( keysReg.match(tmp) ) {
			var key = keysReg.matched(1);
			tplKeys.set(key,key);
			tmp = keysReg.matchedRight();
		}
		if( VERBOSE ) {
			var n = 0;
			for(k in tplKeys) n++;
			verbose(' -> Found $n keys in HTML template.');
		}

		// Check missing JSON keys
		for( tplKey in tplKeys.keys() )
			if( !srcKeys.exists(tplKey) )
				warning('key "$tplKey" required by your HTML template isn\'t defined in ${srcFp.fileWithExt}!');

		// Check unused source keys
		for( jsonKey in srcKeys.keys() )
			if( !tplKeys.exists(jsonKey) )
				warning('key "$jsonKey" from your Source file isn\'t used in your HTML template.');


		// Build HTML
		verbose('Building HTML...');
		var htmlOut = rawTpl;
		for( jk in srcKeys.keyValueIterator() ) {
			var html = jk.value;

			if( html.indexOf("\n")>=0 ) {
				// Create paragraphs or lists for multilines
				var lines = html.split("\n").filter( line->dn.Lib.wtrim(line).length>0 );
				if( lines.length>1 ) {

					var inserts = [];
					var curWraps = [];
					function _wrapList(idx:Int, depth:Int) {
						if( curWraps.length==0 && depth<0 )
							return;
						else if( curWraps.length==0 || curWraps[curWraps.length-1].depth < depth ) {
							curWraps.push({ idx:idx, depth:depth });
						}
						else if( curWraps[curWraps.length-1].depth > depth ) {
							// Close last
							var startIdx = curWraps.pop().idx;
							inserts.push({ idx:startIdx, str:'<ul>' });
							inserts.push({ idx:idx, str:'</ul>' });
						}
					}


					for( i in 0...lines.length ) {
						var line = lines[i];
						if( LIST_REG.match(line) ) {
							// List element
							_wrapList(i, LIST_REG.matched(1).length);
							lines[i] = '<li>${ formatLine( LIST_REG.matched(2) ) }</li>\n';
						}
						else {
							// Normal paragraph
							while( curWraps.length>0 )
								_wrapList(i, -1);
							lines[i] = '<p>${ formatLine(line) }</p>\n';
						}
					}

					// Close remaining wraps
					while( curWraps.length>0 )
						_wrapList(lines.length, -1);

					inserts.sort( (a,b)->return -Reflect.compare(a.idx, b.idx) );
					for(i in inserts)
						lines.insert(i.idx, i.str);

					html = lines.join("\n");

				}
				else
					html = formatLine( lines[0] );
			}
			else
				html = formatLine(html);

			// Replace variables
			htmlOut = StringTools.replace(htmlOut, "%"+jk.key+"%", html);
		}


		// Save HTML
		verbose('Saving HTML: ${outputHtmlFile.full}...');
		sys.FileSystem.createDirectory(outputHtmlFile.directory);
		sys.io.File.saveContent(outputHtmlFile.full, htmlOut);
		if( !VERBOSE )
			Lib.println('Saved: ${outputHtmlFile.full}');


		// List template dependencies (CSS, images etc.)
		var dependencies = [];
		var tmp = htmlOut;
		while( DEPENDENCY_URI_REG.match(tmp) ) {
			dependencies.push( DEPENDENCY_URI_REG.matched(1) );
			tmp = DEPENDENCY_URI_REG.matchedRight();
		}

		// Copy dependencies
		verbose('Copying template dependencies (${dependencies.length})...');
		for( f in dependencies ) {
			var to = dn.FilePath.fromFile( outputHtmlFile.directory+"/"+f );

			// Try to guess if it's a template file or one near the presskit source file
			var from = dn.FilePath.cleanUp( tplFp.directory+"/"+f, true );
			if( !sys.FileSystem.exists(from) ) {
				from = dn.FilePath.cleanUp( srcFp.directory+"/"+f, true );
				if( !sys.FileSystem.exists(from) ) {
					warning('Skipped dependency (not found): $from');
					continue;
				}
			}

			// Copy
			verbose(' -> $from ...');
			sys.FileSystem.createDirectory(to.directory);
			sys.io.File.copy(from, to.full);
		}

		Lib.println("Done.");
	}

	static function simpleTag(str:String, tag:String, htmlOpen:String, ?htmlClose:String) {
		var parts = str.split(tag);
		if( parts.length%2==0 ) {
			if( parts.length>0 )
				error('Malformed "$tag" tag in source file');
			return str;
		}
		else {
			if( htmlClose==null )
				htmlClose = htmlOpen;
			str = "";
			var odd = false;
			for(p in parts) {
				if( odd )
					str += '<$htmlOpen>$p</$htmlClose>';
				else
					str += p;
				odd = !odd;
			}
			return str;
		}
	}

	static function formatLine(str:String) {
		str = dn.Lib.wtrim(str);
		str = simpleTag(str, "**", "strong");
		str = simpleTag(str, "*", "em");
		str = simpleTag(str, "~~", "strike");

		var linkReg = ~/\[(.*?)\]\((.*?)\)/gi;
		str = linkReg.replace(str, '<a href="$2">$1</a>');
		return str;
	}


	static function parseJson(raw:String) {
		// Parse
		var json = try haxe.Json.parse(raw) catch(e) { error('JSON parsing failed: $e'); null; }

		// Extract keys
		var srcKeys : Map<String,String> = new Map();
		iterateJson(json, srcKeys);
		if( VERBOSE ) {
			var n = 0;
			for(k in srcKeys) n++;
			verbose(" -> Found "+n+" key(s) in JSON.");
		}

		return srcKeys;
	}


	static function parseXml(raw:String) {
		// Parse
		var doc = try Xml.parse(raw) catch(e) { error('XML parsing failed: $e'); null; }
		var xml = new haxe.xml.Access(doc);

		// Extract keys
		var srcKeys : Map<String,String> = new Map();
		iterateXml(xml, srcKeys);
		if( VERBOSE ) {
			var n = 0;
			for(k in srcKeys) n++;
			verbose(" -> Found "+n+" key(s) in XML.");
		}

		return srcKeys;
	}


	static function verbose(str:String) {
		if( VERBOSE )
			Lib.println(str);
	}


	static var HTML_TAGS = [
		"p", "div", "span", "pre", "a", "q", "quote", "blockquote",
		"ul", "dl", "ol", "li", "dt", "dd",
		"table", "form", "img",
		"h1", "h2", "h3", "h4", "h5", "h6",
		"em", "i", "strong", "b",
		"br", "hr",
	];
	static var IGNORED_HTML_TAGS = {
		var m = new Map();
		for(t in HTML_TAGS)
			m.set(t,t);
		m;
	}


	static function iterateXml(node:haxe.xml.Access, allKeys:Map<String,String>, ?parentKey:String) {
		var containsSubNodes = false;

		for(c in node.elements) {
			if( IGNORED_HTML_TAGS.exists(c.name.toLowerCase()) )
				continue;

			containsSubNodes = true;
			var key = parentKey==null ? c.name : parentKey+"_"+c.name;

			// Duplicates
			if( allKeys.exists(key) )
				warning('Duplicate key $key in Source file');

			if( !iterateXml(c, allKeys, key) ) {
				// Only register HTML block if there's no key inside of it
				allKeys.set(key, c.innerHTML);
			}
		}

		return containsSubNodes;
	}



	static function iterateJson(o:Dynamic, allKeys:Map<String,String>, ?parentKey:String) {
		for(field in Reflect.fields(o)) {
			var v : Dynamic = Reflect.field(o,field);
			var key = ( parentKey==null ? "" : parentKey+"_" ) + field;
			switch Type.typeof(v) {
				case TNull:

				case TInt, TFloat, TClass(String):
					allKeys.set( key, Std.string(v) );

				case TObject:
					iterateJson( Reflect.field(o,field), allKeys, key );

				case TClass(Array):
					var arr : Array<Dynamic> = cast v;
					for(e in arr)
						switch Type.typeof(e) {
							case TClass(String):
							case _:
								error("Unsupported array type in JSON value: "+field);
						}
					allKeys.set( key, arr.join("\n") );

				case TClass(_), TBool, TFunction, TEnum(_), TUnknown:
					error("Unsupported JSON value: "+field+" ("+Type.typeof(v)+")");
			}
		}
	}




	static function iterateHtml(node:haxe.xml.Access, cb:haxe.xml.Access->Void) {
		for(c in node.elements) {
			cb(c);
			iterateHtml(c, cb);
		}
	}



	static function usage(exitCode=0) {
		Lib.println("");

		if( exitCode==0 ) {
			Lib.println("USAGE:");
			Lib.println("  haxelib run presskit [<presskit_file>] [<html_template>] [-v]");
			// Lib.println("  haxelib run presskit [presskit_file] [-o <target_dir>");
			Lib.println("");
			Lib.println("ARGUMENTS:");
			Lib.println('  <presskit_file>: optional path to your presskit XML or JSON (default is "./$DEFAULT_SRC")');
			Lib.println('  <html_template>: optional path to your own custom HTML template (default is "./$DEFAULT_TPL", from the Presskit lib folder)');
			Lib.println('  -v: enable Verbose mode');
			Lib.println("");
			Lib.println('NOTES:');
			Lib.println('  Basic markdown style formatting is supported: bold (**), italic (*), striked (~~), lists, nested lists and links ( [desc](url) ).');
			Lib.println('  See "demo" folder for some examples.');
		}
		else
			Lib.println("For help, just run:  haxelib run presskit");

		Lib.println("");
		Sys.exit(exitCode);
	}


	static function warning(msg:Dynamic) {
		Lib.println(" -> WARNING: "+Std.string(msg));
	}


	static function error(msg:Dynamic, showUsage=false) {
		Lib.println("");
		Lib.println("--------------------------------------------------------------");
		Lib.println("ERROR: "+Std.string(msg));
		Lib.println("--------------------------------------------------------------");
		if( showUsage )
			usage(1);
		else
			Sys.exit(1);
	}
}


