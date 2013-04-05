/** SDL のポーティング DerelictSDL2 を読み込む。
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
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
