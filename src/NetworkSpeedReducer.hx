using Std;

class NetworkSpeedReducer {

	var nTimeIntervals: Int;
	var linkRes: Map<String,LinkResult>;

	function new( inp: haxe.io.Input, out: haxe.io.Output ) {
		nTimeIntervals = 24*4;
		linkRes = new Map();

		while ( true ) try {
			var r = inp.readLine().split( ',' );
			getResult( r[0] ).add( r[1].parseFloat(), r[2].parseFloat(), Std.parseFloat( r[3] ) );
		}
		catch ( e: haxe.io.Eof ) {
			break;
		}

		for ( link in linkRes.keys() )
			for ( partial in getResult( link ) )
				if ( partial.wgt > 0 )
					out.writeString( '$link,${partial.t},${partial.val},${partial.wgt}\n' );

	}

	inline function getResult( link: String ) {
		var x = linkRes.get( link );
		if ( x == null ) {
			x = new LinkResult( nTimeIntervals );
			linkRes.set( link, x );
		}
		return x;
	}

	static function main() {
		new NetworkSpeedReducer( Sys.stdin(), Sys.stdout() );
	}

}
