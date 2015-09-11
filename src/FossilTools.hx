import haxe.macro.Context;
import haxe.macro.Expr;

class FossilTools {
	@:macro public static function getCheckoutUuid( ?path: String = '.', ?fossilExec: String = 'fossil' ): ExprOf<String> {
		Sys.setCwd( path );
		var uuid = '';

		var p = new sys.io.Process( fossilExec, [ 'status' ] );
		vehjo.macro.Error.throwIf( p.exitCode() != 0 );
		// Sys.println( p.stderr.readAll().toString() );
		var data = p.stdout.readAll().toString();
		p.close();
		var r = ~/^checkout:[\t ]+([^\t ]+)/m;
		if ( r.match( data ) )
			uuid = r.matched( 1 );

		var p = new sys.io.Process( fossilExec, [ 'changes' ] );
		vehjo.macro.Error.throwIf( p.exitCode() != 0 );
		// Sys.println( p.stderr.readAll().toString() );
		var i = 0;
		while ( true ) try {
			p.stdout.readLine();
			i++;
		}
		catch ( e: haxe.io.Eof ) {
			break;
		}
		p.close();
		if ( i > 0 )
			uuid += '+';

		// Sys.println( uuid );
		return { expr: EConst( CString( uuid ) ), pos: Context.currentPos() };
	}
	@:macro static function resolve( e: Expr ): Expr {
		return e;
	}
}
