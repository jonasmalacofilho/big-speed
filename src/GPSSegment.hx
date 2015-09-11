using Std;

class GPSSegment {
	
	// From point
	public var t0( default, null ): Float; // s
	public var x0( default, null ): Float;
	public var y0( default, null ): Float;
	
	// To point
	public var t1( default, null ): Float; // s
	public var x1( default, null ): Float;
	public var y1( default, null ): Float;

	public function new( t0, t1, x0, x1, y0, y1 ) {
		this.t0 = t0;
		this.t1 = t1;
		this.x0 = x0;
		this.x1 = x1;
		this.y0 = y0;
		this.y1 = y1;
	}

	public function toString(): String {
		return [ t0, t1, x0, x1, y0, y1 ].toString();
	}

	public static function fromStringArray( x: Array<String> ): GPSSegment {
		// Assumes veh, t0 [mili], x0, y0, t1 [mili], x1, y1
		return new GPSSegment( x[1].parseFloat()/1000, x[4].parseFloat()/1000, x[2].parseFloat(), x[5].parseFloat(), x[3].parseFloat(), x[6].parseFloat() );
	}


}