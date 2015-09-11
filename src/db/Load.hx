package db;

class Load {
	static function main() {
		var r = ~/^(\d+)-(\d+)-(\d+)-(\d+)-(val|wgt)\t([0-9.E-]+)$/;
		var stdin = Sys.stdin();
		var stdout = Sys.stdout();
		var stderr = Sys.stderr();

		#if !fake
		sys.db.Manager.initialize();
		sys.db.Manager.cnx = sys.db.Sqlite.open( 'linkSpeed.db3' );

		if ( !sys.db.TableCreate.exists( Link.manager ) )
			sys.db.TableCreate.create( Link.manager );
		if ( !sys.db.TableCreate.exists( TimeInterval.manager ) )
			sys.db.TableCreate.create( TimeInterval.manager );
		if ( !sys.db.TableCreate.exists( LinkSpeed.manager ) )
			sys.db.TableCreate.create( LinkSpeed.manager );
		#end

		while ( true ) try {
			var line = stdin.readLine();
			if ( r.match( line ) ) {
				#if fake
				stdout.writeString( r.matched( 1 )+','+r.matched( 2 )+','+r.matched( 3 )+','+r.matched( 4 )+','
				+( r.matched( 5 )=='val'? 1: 2 )+','+r.matched( 6 )+'\n' );
				#else
				var link = Link.get( Std.parseInt( r.matched( 1 ) ), Std.parseInt( r.matched( 2 ) ) );
				var ti = TimeInterval.get( Std.parseInt( r.matched( 3 ) ), Std.parseInt( r.matched( 4 ) ) );
				switch ( r.matched( 5 ) ) {
					case 'val': LinkSpeed.absorbValue( link, ti, Std.parseFloat( r.matched( 6 ) ) );
					case 'wgt': LinkSpeed.absorbWeight( link, ti, Std.parseFloat( r.matched( 6 ) ) );
				}
				#end
			}
			else
				stderr.writeString( line+'\n' );
		}
		catch ( e:haxe.io.Eof ) {
			break;
		}

	}
}
