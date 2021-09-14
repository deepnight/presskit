import neko.Lib;

class Main {
	static var DEFAULT_SRC = "presskit.xml";
	static var DEFAULT_OUTPUT = "presskit";
	static var VERBOSE = false;
	static var LIST_REG = ~/^\s*-\s+(.+?)$/gi;

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
			// [ "-tpl" => 1 ]
		);
		var libDir = args.getLastSoloValue();

		// Inits
		var srcKeys : Map<String,String> = new Map();
		VERBOSE = args.hasArg("-v");

		// Read source file
		var srcPath = args.getFirstSoloValue();
		if( args.getAllSoloValues().length==1 )
			srcPath = DEFAULT_SRC;
		var srcFp = dn.FilePath.fromFile(srcPath);
		verbose('Reading source file: ${srcFp.full}...');
		if( !sys.FileSystem.exists(srcFp.full) ) {
			if( srcPath==DEFAULT_SRC )
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
		var tplPath = dn.FilePath.cleanUp( libDir+"/tpl/default.html", true );
		verbose('Reading HTML template: $tplPath...');
		var rawTpl = try sys.io.File.getContent(tplPath) catch(_) { error('Could not open: $tplPath'); null; }

		// List HTML keys
		var tplKeys : Map<String,String> = new Map();
		var keysReg = ~/%([a-z_ ]+[0-9]*)%/im;
		var tmp = rawTpl;
		while( keysReg.match(tmp) ) {
			var key = keysReg.matched(1);
			tplKeys.set(key,key);
			tmp = keysReg.matchedRight();
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

			var wrapTag : Null<String> = null;

			if( html.indexOf("\n")>=0 ) {
				// Create paragraphs or lists for multilines
				var lines = html.split("\n").map( line->dn.Lib.wtrim(line) ).filter( line->line.length>0 );
				if( lines.length>1 ) {
					html = "";
					for( line in lines )
						if( LIST_REG.match(line) ) {
							// List element
							wrapTag = "ul";
							html += '<li>${ formatLine( LIST_REG.matched(1) ) }</li>\n';
						}
						else
							html += '<p>${ formatLine(line) }</p>\n';

				}
				else
					html = formatLine( lines[0] );
			}
			else
				html = formatLine(html);

			// Optional parent wrapper
			if( wrapTag!=null )
				html = '<$wrapTag>$html</$wrapTag>';

			htmlOut = StringTools.replace(htmlOut, "%"+jk.key+"%", html);
		}

		// Save HTML
		var tplOutPath = dn.FilePath.fromFile(srcFp.full);
		tplOutPath.extension = "html";
		verbose('Saving HTML: ${tplOutPath.full}...');
		sys.io.File.saveContent(tplOutPath.full, htmlOut);
		if( !VERBOSE )
			Lib.println('Saved: ${tplOutPath.full}');

		// Copy dependencies (CSS etc.)
		// TODO

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
		str = simpleTag(str, "_", "u");
		str = simpleTag(str, "~", "strike");

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

	// static function hasParameter(id:String) {
	// 	for( p in Sys.args() )
	// 		if( p==id )
	// 			return true;
	// 	return false;
	// }

	// static function getParameter(id:String) : Null<String> {
	// 	var isNext = false;
	// 	for( p in Sys.args() )
	// 		if( p==id )
	// 			isNext = true;
	// 		else if( isNext )
	// 			return p;

	// 	return null;
	// }

	// static function getIsolatedParameters() : Array<String> {
	// 	var all = [];
	// 	var ignoreNext = false;
	// 	for( p in Sys.args() ) {
	// 		if( p.charAt(0)=="-" ) {
	// 			if( !SINGLE_PARAMETERS.exists(p) )
	// 				ignoreNext = true;
	// 		}
	// 		else if( !ignoreNext )
	// 			all.push(p);
	// 		else
	// 			ignoreNext = false;
	// 	}

	// 	return all;
	// }


	static function usage(exitCode=0) {
		Lib.println("");

		if( exitCode==0 ) {
			Lib.println("USAGE:");
			Lib.println("  haxelib run presskit [json_file] [-o <target_dir>");
			Lib.println("");
			Lib.println("EXAMPLES:");
			Lib.println("  haxelib run presskit");
			Lib.println("  haxelib run presskit myGamePresskit.xml -o docs/presskit");
			Lib.println("  haxelib run presskit myGamePresskit.json");
			Lib.println("");
			Lib.println("ARGUMENTS:");
			Lib.println('  source_file: path to your presskit XML or JSON (default is "./$DEFAULT_SRC")');
			Lib.println('  -o <target_dir>: change the default redistHelper output dir (default "./$DEFAULT_OUTPUT/")');
			Lib.println('  -v: enable verbose mode');
			Lib.println("");
			Lib.println('NOTES:');
			Lib.println('  Basic markdown style formatting is supported: bold (**), italic (*), underline (_), striked (~) and links ( [desc](url) ).');
			Lib.println('  See demo folder for some examples.');
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


