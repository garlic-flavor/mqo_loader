/**
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
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
