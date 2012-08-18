/**
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.gl.util;

public import sworks.compo.gl.port;

// prog shouldn't throw any Exception.
void enableScope( cap ... )( scope void delegate() prog)
{
  foreach(one ; cap) glEnable(one);
	prog();
  foreach_reverse(one ; cap ) glDisable(one);
}


T ennoerror( T, string file = __FILE__, size_t line = __LINE__ )( T value, lazy const(char)[] msg = null )
{
	checkNoError!( file, line )( msg );
	return value;
}
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
