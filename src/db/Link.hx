package db;

import sys.db.Types;

class Link extends sys.db.Object {
	public var id:SId;
	public var fromId:SInt;
	public var toId:SInt;

	public function new( _fromId, _toId ) {
		super();
		fromId = _fromId;
		toId = _toId;
		insert();
	}

	public static function get( _fromId:Int, _toId:Int ) {
		var link = manager.select( $fromId==_fromId && $toId==_toId );
		if ( link == null )
			link = new Link ( _fromId, _toId );
		return link;
	}
}
