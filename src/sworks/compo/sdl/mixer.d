module sworks.compo.sdl.mixer;
/+
public import std.exception;
public import derelict.sdl.mixer;
public import sworks.compo.sdl.util;
version( Windows )
{
	pragma( lib, "lib\\DerelictSDLMixer.lib" );
}
version( linux )
{ //分割コンパイルする場合は -L-lDerelictSDLMixer をdmdに渡す。
	pragma( lib, "DerelictSDLMixer" );
}

SDLExtInitDel getMixerInitializer( uint initFlags, int frequency = MIX_DEFAULT_FREQUENCY
                                 , ushort format = MIX_DEFAULT_FORMAT, int channels = 2, int chunksize = 4096 )
{
	return {
		DerelictSDLMixer.load();
		if( 0 != initFlags ) enforce( initFlags == Mix_Init( initFlags ), "init : failure in Mix_Init" );
		enforce( 0 == Mix_OpenAudio( frequency, format, channels, chunksize ), "init : failure in Mix_OpenAudio" );
		return { Mix_CloseAudio(); Mix_Quit(); };
	};
}
+/