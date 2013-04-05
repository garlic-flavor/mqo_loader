/**
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.compo.gl.util;

public import sworks.compo.gl.port;

/// $(D_PARAM prog) を glEnable(cap) と glDisable(cap) で挟んだもの。
/// Bugs:
///   $(D_PARAM prog) が例外を投げると glDisable(cap) が実行されない。
void enableScope( cap ... )( scope void delegate() prog)
{
  foreach(one ; cap) glEnable(one);
	prog();
  foreach_reverse(one ; cap ) glDisable(one);
}

/// glGetError() が GL_NO_ERROR を返さなかったら例外を投げる。
T ennoerror( T, string file = __FILE__, size_t line = __LINE__ )( T value, lazy const(char)[] msg = null )
{
	checkNoError!( file, line )( msg );
	return value;
}
/// ditto
void checkNoError( string file = __FILE__, size_t line = __LINE__ )( lazy const(char)[] msg = null )
{
	auto err_code = glGetError();
	if     ( GL_NO_ERROR == err_code ) return;
	else if( GL_INVALID_ENUM == err_code ) throw new Exception( "GL_INVALID_ENUM", file, line );
	else if( GL_INVALID_VALUE == err_code ) throw new Exception( "GL_INVALID_VALUE", file, line );
	else if( GL_INVALID_OPERATION == err_code ) throw new Exception( "GL_INVALID_OPERATION", file, line );
	else if( GL_INVALID_FRAMEBUFFER_OPERATION == err_code )
		throw new Exception( "GL_INVALID_FRAMEBUFFER_OPERATION", file, line );
	else if( GL_OUT_OF_MEMORY == err_code ) throw new Exception( "GL_OUT_OF_MEMORY", file, line );
	else throw new Exception( "UNDEFINED ERROR", file, line );
}
