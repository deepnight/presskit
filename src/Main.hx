import neko.Lib;

class Main {
	static var DEFAULT_JSON = "presskit.json";
	static var DEFAULT_OUTPUT = "presskit";
	static var VERBOSE = false;

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
			[ "-tpl" => 1 ]
		);
		var libDir = args.getLastSoloValue();
		var jsonPath = args.getFirstSoloValue();
		if( args.getAllSoloValues().length==1 )
			jsonPath = DEFAULT_JSON;

		VERBOSE = args.hasArg("-v");

		// Parse JSON
		verbose('Reading JSON: $jsonPath...');
		if( !sys.FileSystem.exists(jsonPath) )
			error('File not found: $jsonPath');
		var raw = try sys.io.File.getContent(jsonPath) catch(_) { error('Could not open: $jsonPath'); null; }
		var json = try haxe.Json.parse(raw) catch(_) { error('Could not parse JSON: $jsonPath'); null; }

		// List JSON keys
		var jsonKeys : Map<String,String> = new Map();
		iterateJson(json, jsonKeys);
		verbose("Found "+Lambda.count(jsonKeys)+" key(s) in JSON.");

		// Parse HTML template

		// Build HTML
	}

	static function verbose(str:String) {
		if( VERBOSE )
			Lib.println(str);
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

				case TClass(_), TBool, TFunction, TEnum(_), TUnknown:
					error("Unsupporter JSON value: "+field+" ("+Type.typeof(v)+")");
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
		Lib.println("USAGE:");
		Lib.println("  haxelib run presskit [json_file] [-o <target_dir>");
		Lib.println("");
		Lib.println("EXAMPLES:");
		Lib.println("  haxelib run presskit");
		Lib.println("  haxelib run presskit myGamePresskit.json");
		Lib.println("");
		Lib.println("ARGUMENTS:");
		Lib.println('  json_file: path to your presskit JSON (default is "./$DEFAULT_JSON")');
		Lib.println('  -o <target_dir>: change the default redistHelper output dir (default "./$DEFAULT_OUTPUT/")');
		Lib.println('  -v: enable verbose mode');
		Lib.println("");
		Sys.exit(exitCode);
	}

	static function error(msg:Dynamic) {
		Lib.println("");
		Lib.println("ERROR: "+Std.string(msg));
		usage(1);
	}
}


