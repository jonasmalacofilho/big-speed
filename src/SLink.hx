import vehjo.Vector;
import emmekit.Link;

class SLink {

	public var minPoint( get, null ): Vector; // point with the smallest coordinates
	public var absDelta( get, null ): Vector; // bounding box dimensions
	public var pos( default, null ): Vector; // midpoint vector
	public var dir( default, null ): Vector; // direction vector

	public inline function new( i: Vector, j: Vector ) {
		dir = j.sub( i );
		pos = i.sum( dir.scale( .5 ) );
	}

	inline function get_minPoint(): Vector {
		return pos.sub( get_absDelta().scale( .5 ) );
	}

	inline function get_absDelta(): Vector {
		return new Vector( Math.abs( dir.x ), Math.abs( dir.y ) );
	}

}
