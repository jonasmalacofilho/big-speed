import vehjo.macro.Debug;
import sys.FileSystem;

class LoadSpeedResultsFromEMR {

	static function main() {
		var args = Lambda.list( Sys.args() );

		var path = null;
		var dbOutPath = null;
		var valTable = null;
		var wgtTable = null;
		var cacheSize: Null<Int> = null;
		var unsafe = false;

		while ( !args.isEmpty() ) {
			switch ( args.pop() ) {
				case '--input-path': path = args.pop();
				case '--db-path': dbOutPath = args.pop();
				case '--val-table': valTable = args.pop();
				case '--wgt-table': wgtTable = args.pop();
				case '--cache-size': cacheSize = Std.parseInt( args.pop() );
				case '--unsafe': unsafe = true;
				case '--version': Sys.println( FossilTools.getCheckoutUuid() ); Sys.exit( 0 );
				case '--help': Sys.println( 'loadRes --input-path <path> --db-path <path> --val-table <table name> --wgt-table <table name> [--cache-size <pages|-Kib>] [--unsafe]\nloadRes --version\nloadRes --help' ); Sys.exit( 0 );
			}
		}

		vehjo.macro.Error.throwIf( path == null );
		vehjo.macro.Error.throwIf( dbOutPath == null );
		vehjo.macro.Error.throwIf( valTable == null );
		vehjo.macro.Error.throwIf( wgtTable == null );

		var now = Date.now();
		// connection
		var dbOut = sys.db.Sqlite.open( dbOutPath );
		if ( cacheSize != null )
			dbOut.request( "PRAGMA cache_size=$cacheSize" );
		if ( unsafe ) {
			dbOut.request( "PRAGMA synchronous=OFF" );
			dbOut.request( "PRAGMA jornal_mode=OFF" );
		}
		dbOut.startTransaction();

		// preparing tables
		dbOut.request( "CREATE TABLE IF NOT EXISTS \"${valTable}\" ( fromNode INT, toNode INT, weekday INT, t REAL, val REAL )" );
		dbOut.request( "CREATE TABLE IF NOT EXISTS \"${wgtTable}\" ( fromNode INT, toNode INT, weekday INT, t REAL, wgt REAL )" );

		dbOut.commit();
		var row = 0;
		for ( f in FileSystem.readDirectory( path ) ) {
			Debug.assert( f );
			if ( ~/^part-\d+/.match( f ) ) {
				var fileInp = sys.io.File.read( path + '/' + f, false );
				while ( true ) try {
					if ( ++row%1000000 == 0 )
						dbOut.commit();
					var line = fileInp.readLine();
					var r = ~/(\d+)-(\d+)-(\d+)-(\d+)-(val|wgt)\t([0-9.]+)/;
					if ( r.match( line ) )
						switch ( r.matched( 5 ) ) {
							case 'val': dbOut.request( "INSERT INTO \"${valTable}\" VALUES ( ${r.matched( 1 )}, ${r.matched( 2 )}, ${r.matched( 3 )}, ${r.matched( 4 )}, ${r.matched( 6 )} )" );
							case 'wgt': dbOut.request( "INSERT INTO \"${wgtTable}\" VALUES ( ${r.matched( 1 )}, ${r.matched( 2 )}, ${r.matched( 3 )}, ${r.matched( 4 )}, ${r.matched( 6 )} )" );
							default: Debug.assert( line );
						}
					else
						Debug.assert( line );
				}
				catch ( e: haxe.io.Eof ) {
					break;
				}
				// dbOut.commit();
				fileInp.close();
			}
		}
		dbOut.commit();
		// dbOut.request( 'VACUUM' );
		// dbOut.commit();
		dbOut.close();
	}

}
