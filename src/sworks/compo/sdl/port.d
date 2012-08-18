/**
 * Version:      0.0013(dmd2.060)
 * Date:         2012-Aug-18 21:27:11
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.sdl.port;

public import derelict.sdl2.sdl;

version(Windows)
{
	pragma( lib, "lib\\DerelictUtil.lib" );
	pragma( lib, "lib\\DerelictSDL2.lib" );
}
version(linux)
{ // 分割コンパイルする場合は、-L-ldl -L-lDerelictUtil -L-lDerelictSDL をdmdに渡す
	pragma( lib, "dl" );
	pragma( lib, "DerelictUtil");
	pragma( lib, "DerelictSDL2" );
}
