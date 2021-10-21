import dn.Lib;

class Main {
	static var DEFAULT_TPL = "tpl/default.html";
	static var DEFAULT_EMPTY_VALUE = "todo";
	static var LIST_REG = ~/^([ \t]*?)-\s+(.+?)$/gi;
	static var VAR_REG = ~/%([a-z0-9_]+)%/gi;
	static var DEPENDENCY_URI_REG = ~/["']([^"']*?(\.png|\.gif|\.jpeg|\.jpg|\.avi|\.mpg|\.mpeg|\.css))\??.*?["']/mi;


	static var isVerbose = false;
	static var zipping = false;
	static var args : dn.Args;
	static var srcFp : Null<dn.FilePath>;
	static var tplFp : dn.FilePath;
	static var zipFp : dn.FilePath;

	static function main() {
		haxe.Log.trace = function(m, ?pos) {
			if ( pos != null && pos.customParams == null )
				pos.customParams = ["debug"];

			Lib.println(Std.string(m));
		}
		Lib.println('');

		// Arguments
		if( Sys.args().length<=0 )
			usage();

		args = new dn.Args(
			Sys.args().join(" "),
			[]
		);
		isVerbose = args.hasArg("-v") || args.hasArg("-verbose");
		zipping = args.hasArg("-zip");

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
		var projectDir = dn.FilePath.cleanUp( args.getLastSoloValue(), false );
		tplFp = dn.FilePath.fromFile( argTpl!=null ? projectDir+"/"+argTpl : haxelibDir +"/"+ DEFAULT_TPL);
		srcFp = argSrc==null ? null : dn.FilePath.fromFile( projectDir+"/"+argSrc );

		// Detect mode
		if( args.hasArg("-extract") || args.hasArg("-x") ) {
			// XML extraction
			if( args.getAllSoloValues().length==0 )
				usage();

			// if( argTpl==null )
			// 	error('Missing HTML file path', true);

			if( argSrc==null )
				error('Missing output "source" file path (with ".xml" or ".json" extension)', true);

			if( !sys.FileSystem.exists(tplFp.full) )
				error('File not found: ${tplFp.full}');

			if( sys.FileSystem.exists(srcFp.full) && !args.hasArg("-force") ) {
				Lib.println('WARNING! File already exists and will be DELETED: ${srcFp.fileWithExt}');
				Lib.print("Overwrite (Y/N)? ");
				var k = Sys.getChar(true);
				switch k {
					case "y".code:
					case _: Sys.exit(0);
				}
				Lib.println('');
				Lib.println('');
			}

			switch srcFp.extension {
				case "xml", "json":
				case _:
					error('Output file extension should be either ".xml" or ".json"');
			}

			extractFromTemplate( srcFp.extension.toLowerCase()=="xml" );
		}
		else if( srcFp!=null ) {
			// HTML presskit builder
			// if( srcFp==null )
			// 	error('Missing presskit source file (XML or JSON)', true);

			if( !sys.FileSystem.exists(srcFp.full) && argSrc==null )
				usage();
			Lib.println('Source: $srcFp');
			Lib.println('Template: $tplFp');

			buildHtml();
		}
		else
			usage();
	}


	static inline function isKeyNameReserved(k:String) {
		return switch k {
			case "zip/status", "zip/path": true;
			case _: false;
		}
	}


	/**
		Create an empty data source file using an existing HTML template
	**/
	static function extractFromTemplate(xml:Bool) {
		// Read HTML template
		verbose('Reading HTML template: ${tplFp.full}...');
		var rawTpl = try sys.io.File.getContent(tplFp.full) catch(_) { error('Could not open: ${tplFp.full}'); null; }

		// Extract HTML keys
		var tplKeys : Map<String,String> = new Map();
		var keysReg = ~/%([a-z0-9_\/]+)%/im;
		var tmp = rawTpl;
		while( keysReg.match(tmp) ) {
			var key = keysReg.matched(1);
			if( !isKeyNameReserved(key) )
				tplKeys.set(key,key);
			tmp = keysReg.matchedRight();
		}
		verbosePrintKeys(tplKeys);

		var outRaw : String = "";

		// Rebuild keys hierarchy
		var subKeyReg = ~/^([a-z_0-9]+)\/(.+$)/i;
		if( xml ) {
			// Build XML
			function _recXmlBuild(target:Xml, keyName:String) {
				if( subKeyReg.match(keyName) ) {
					// Found a key with child(ren)
					var firstName = subKeyReg.matched(1);
					var n = 0;
					var cur : Xml = null;
					for( e in target.elementsNamed(firstName) ) {
						cur = e;
						n++;
					}
					if( n==0) {
						cur = Xml.createElement(firstName);
						target.addChild( cur );
					}


					var remain = subKeyReg.matched(2);
					if( subKeyReg.match(remain) ) {
						// Contains more sub keys
						_recXmlBuild(cur,remain);
					}
					else {
						// Last child
						var e = Xml.createElement(remain);
						e.addChild( Xml.createPCData(DEFAULT_EMPTY_VALUE) );
						cur.addChild(e);
					}
				}
				else {
					// Key without child
					var e = Xml.createElement(keyName);
					e.addChild( Xml.createPCData(DEFAULT_EMPTY_VALUE) );
					target.addChild(e);
				}
			}

			verbose('Building XML...');
			var out = Xml.createDocument();
			for( k in tplKeys.keys() )
				_recXmlBuild(out, k);

			outRaw = haxe.xml.Printer.print(out, true);
		}
		else {
			// Build JSON
			function _recStructBuild(target:Dynamic, keyName:String) {
				if( subKeyReg.match(keyName) ) {
					// Found a key with child(ren)
					var firstName = subKeyReg.matched(1);
					var cur : Dynamic = null;
					cur =
						if( !Reflect.hasField(target,firstName) ) {
							var o = {}
							Reflect.setField(target, firstName, o);
							o;
						}
						else
							Reflect.field(target, firstName);

					var remain = subKeyReg.matched(2);
					if( subKeyReg.match(remain) ) {
						// Contains more sub keys
						_recStructBuild(cur,remain);
					}
					else {
						// Last child
						Reflect.setField(cur, remain, [DEFAULT_EMPTY_VALUE]);
					}
				}
				else {
					// Key without child
					Reflect.setField(target, keyName, [DEFAULT_EMPTY_VALUE]);
				}
			}

			verbose('Building JSON...');
			var out : Dynamic = {}
			for( k in tplKeys.keys() )
				_recStructBuild(out, k);

			// Create JSON
			outRaw = dn.JsonPretty.stringify(out);
		}

		// Save file
		var n = Lambda.count(tplKeys);
		Lib.println('Saving $n key(s) to presskit ${xml?"XML":"JSON"}: ${srcFp.full}');
		sys.io.File.saveContent(srcFp.full, outRaw);
}

	/**
		Create HTML presskit using a template and a data source (XML or JSON)
	**/
	static function buildHtml() {
		var srcKeys : Map<String,String> = new Map();
		var tplKeys : Map<String,String> = new Map();

		var outputHtmlFile = srcFp.clone();
		outputHtmlFile.appendDirectory(srcFp.fileName+"_html");
		outputHtmlFile.fileName = srcFp.fileName;
		outputHtmlFile.extension = "html";

		var zipFp = outputHtmlFile.clone();
		zipFp.extension = "zip";

		// Cleanup previous dir
		if( sys.FileSystem.exists(outputHtmlFile.directory) ) {
			verbose('Removing previous output dir: ${outputHtmlFile.directory}');
			retryIfFail( dn.FileTools.deleteDirectoryRec.bind(outputHtmlFile.directory) );
		}


		// Read source file
		if( !sys.FileSystem.exists(srcFp.full) )
			error('File not found: ${srcFp.full}', true);
		verbose('Reading source file: ${srcFp.fileWithExt}...');
		var rawSrc = try sys.io.File.getContent(srcFp.full) catch(_) { error('Could not open: ${srcFp.full}'); null; }


		// Extract source keys
		switch srcFp.extension.toLowerCase() {
			case "json":
				srcKeys = parseJson(rawSrc);

			case "xml":
				srcKeys = parseXml(rawSrc);

			case _:
				error("Unsupported source file extension: "+srcFp.extension);
		}

		if( zipping )
			srcKeys.set("zip/path", zipFp.fileWithExt);
		srcKeys.set("zip/status", zipping ? "on" : "off");


		// Read HTML template
		verbose('Reading HTML template: ${tplFp.full}...');
		var rawTpl = try sys.io.File.getContent(tplFp.full) catch(_) { error('Could not open: ${tplFp.full}'); null; }


		// Extract HTML keys
		var keysReg = ~/%([a-z0-9_\/]+)%/im;
		var tmp = rawTpl;
		while( keysReg.match(tmp) ) {
			var key = keysReg.matched(1);
			tplKeys.set(key,key);
			tmp = keysReg.matchedRight();
		}
		verbosePrintKeys(tplKeys);

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
		if( !isVerbose )
			Lib.println('HTML output: ${outputHtmlFile.full}');


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


		// Zipping
		if( zipping ) {
			Lib.print("Zipping: ");
			dn.FileTools.zipFolder(zipFp.full, outputHtmlFile.directory, (f,s)->Lib.print("*"));
			Lib.println(' -> ${zipFp.fileWithExt}');
		}


		// Create HTaccess
		var htaccessFp = outputHtmlFile.clone();
		htaccessFp.fileWithExt = ".htaccess";
		sys.io.File.saveContent(htaccessFp.full, "DirectoryIndex "+outputHtmlFile.fileWithExt);

		Lib.println("Done.");
	}


	static function retryIfFail( cb:Void->Void, maxTries=5 ) {
		var t = 1;
		try cb()
		catch(e) {
			if( maxTries<=0 )
				throw e;
			Lib.println(' > Failed, retrying in ${t}s...');
			var l = new sys.thread.Lock();
			l.wait(t);
			retryIfFail(cb, maxTries-1);
		}
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
		verbosePrintKeys(srcKeys);

		return srcKeys;
	}


	static function parseXml(raw:String) {
		// Parse
		var doc = try Xml.parse(raw) catch(e) { error('XML parsing failed: $e'); null; }
		var xml = new haxe.xml.Access(doc);

		// Extract keys
		var srcKeys : Map<String,String> = new Map();
		iterateXml(xml, srcKeys);
		verbosePrintKeys(srcKeys);

		return srcKeys;
	}


	static function verbose(str:String) {
		if( isVerbose )
			Lib.println(str);
	}

	static function verbosePrintKeys(keys:Map<String,String>) {
		if( isVerbose ) {
			var all = [];
			for(k in keys.keys())
				all.push(k);
			verbose(' -> Found ${all.length} key(s): ${all.join(", ")}');
		}
	}


	static var HTML_TAGS = [
		"p", "div", "span", "pre", "a", "q", "quote", "blockquote","iframe",
		"ul", "dl", "ol", "li", "dt", "dd",
		"table", "form", "img","video",
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
			var key = parentKey==null ? c.name : parentKey+"/"+c.name;

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
			var key = ( parentKey==null ? "" : parentKey+"/" ) + field;
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

		// if( exitCode==0 ) {
			Lib.println("NORMAL USAGE:");
			Lib.println('  In this mode, an HTML static page is generated using a HTML template + a presskit source file (xml or json)');
			Lib.println("");
			Lib.println("    haxelib run presskit <xml_or_json_presskit> [<html_template>] [-zip] [-v]");
			Lib.println("");
			Lib.println('  <xml_or_json_presskit>: path to your presskit XML or JSON');
			Lib.println('  <html_template>: optional path to your own custom HTML template (default is "./$DEFAULT_TPL", from the Presskit lib folder)');
			Lib.println("");
			Lib.println('  Note: basic markdown style formatting is supported in your source file: bold (**), italic (*), striked (~~), lists, nested lists and links ( [desc](url) ).');
			Lib.println('  See "demo" folder for some examples.');

			Lib.println('');
			Lib.println("EXTRACTION MODE:");
			Lib.println('  Build a XML or a JSON presskit file using keys found in an existing HTML template.');
			Lib.println("");
			Lib.println("    haxelib run presskit -extract [<html_to_extract>] <output_presskit_file> [-v]");
			Lib.println("");
			Lib.println('  <html_to_extract>: HTML file to parse and to extract keys from (default is "./$DEFAULT_TPL", from the Presskit lib folder)');
			Lib.println('  <output_presskit_file>: output presskit file to generated (with either ".xml" or ".json" extension)');
			Lib.println('');
			Lib.println('ARGUMENTS:');
			Lib.println('    -extract | -x: use Extraction mode');
			Lib.println('    -zip: create a ZIP archive (and a link to it in the template if it supports that. See default template for an example)');
			Lib.println('    -force: bypass confirmations and overwrite everything');
			Lib.println('    -verbose | -v: enable Verbose mode');
			Lib.println('');
			Lib.println('EXAMPLES:');
			Lib.println('    haxelib run presskit -x emptyPresskit.xml');
			Lib.println('    haxelib run presskit emptyPresskit.xml -zip');
			Lib.println('');
			Lib.println('Full manual: https://github.com/deepnight/presskit');
		// }
		// else
		// 	Lib.println("For help, just run:  haxelib run presskit");

		Lib.println("");
		Sys.exit(exitCode);
	}


	static function warning(msg:Dynamic) {
		Lib.println(" -> WARNING: "+Std.string(msg));
	}


	static function error(msg:Dynamic, showUsage=false) {
		Lib.println("");
		Lib.println("------------------------------------------------------------------------------");
		Lib.println("ERROR: "+Std.string(msg));
		Lib.println("------------------------------------------------------------------------------");
		if( showUsage )
			usage(1);
		else
			Sys.exit(1);
	}
}


