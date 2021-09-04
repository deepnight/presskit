import neko.Lib;

class Main {
	static function main() {
		haxe.Log.trace = function(m, ?pos) {
			if ( pos != null && pos.customParams == null )
				pos.customParams = ["debug"];

			Lib.println(Std.string(m));
		}

		if( Sys.args().length==0 )
			usage();
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


	static function usage() {
		Lib.println("");
		Lib.println("USAGE:");
		Lib.println("  haxelib run presskit <json_file> [-o <target_dir>");
		Lib.println("");
		Lib.println("EXAMPLES:");
		Lib.println("  haxelib run presskit myGamePresskit.json");
		Lib.println("");
		Lib.println("OPTIONS:");
		Lib.println("  -o <target_dir>: change the default redistHelper output dir (default: \"redist/\")");
		Lib.println("");
		Sys.exit(0);
	}

	static function error(msg:Dynamic) {
		Lib.println("");
		Lib.println("ERROR - "+Std.string(msg));
		Sys.exit(1);
	}
}


