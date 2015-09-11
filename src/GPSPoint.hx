import vehjo.Vector;
using Std;

class GPSPoint extends Vector {

	public var veh( default, null ): Int;
	public var time( default, null ): Float; // in seconds

	public function new( veh, time, x, y ) {
		this.veh = veh;
		this.time = time;
		super( x, y );
	}

	public static function fromStringArray( x: Array<String> ): GPSPoint {
		return new GPSPoint( x[0].parseInt(), x[1].parseFloat()/1000, x[2].parseFloat(), x[3].parseFloat() );
	}

}