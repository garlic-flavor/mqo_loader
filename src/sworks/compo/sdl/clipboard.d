module sworks.compo.sdl.clipboard;
/*
public import sworks.compo.sdl.util;

private
{
	import derelict.util.system;
	import derelict.util.loader;

	version(Tango) import tango.stdc.stdio;
	else import std.c.stdio;

	version(darwin)
		version = MacOSX;
	version(OSX)
		version = MacOSX;

	version(MacOSX)
		import derelict.sdl.macinit.SDLMain;
}


alias const(char) SDLScrap_DataType;

string SDL_CLIPBOARD_TEXT_TYPE = "SDL_CLIPBOARD_TEXT_TYPE (This string may be different on each platform.)";
string SDL_CLIPBOARD_IMAGE_TYPE = "SDL_CLIPBOARD_IMAGE_TYPE (This string may be different on each platform.)";

extern(C)
{
	alias int function() da_SDLScrap_Init;
	alias void function( SDLScrap_DataType*, size_t, const(char)* ) da_SDLScrap_CopyToClipboard;
	alias void function( SDLScrap_DataType*, size_t*, char** ) da_SDLScrap_PasteFromClipboard;
	alias void function( char* ) da_SDLScrap_FreeBuffer;
}

mixin(gsharedString!() ~
"
da_SDLScrap_Init SDLScrap_Init;
da_SDLScrap_CopyToClipboard SDLScrap_CopyToClipboard;
da_SDLScrap_PasteFromClipboard SDLScrap_PasteFromClipboard;
da_SDLScrap_FreeBuffer SDLScrap_FreeBuffer;
" );


class SDLClipboardLoader : SharedLibLoader
{
public:
	this()
	{
		super(
			"libSDL_Clipboard.dll, SDL_Clipboard.dll",
			"libSDL_Clipboard.so, libSDL_Clipboard.so.0",
			"../Frameworks/SDL_Clipboard.framework/SDL_Clipboard"
		);
	}
protected:
	override void loadSymbols()
	{
		bindFunc(cast(void**)&SDLScrap_Init, "SDLScrap_Init" );
		bindFunc(cast(void**)&SDLScrap_CopyToClipboard, "SDLScrap_CopyToClipboard" );
		bindFunc(cast(void**)&SDLScrap_PasteFromClipboard, "SDLScrap_PasteFromClipboard" );
		bindFunc(cast(void**)&SDLScrap_FreeBuffer, "SDLScrap_FreeBuffer" );
	}
}

SDLClipboardLoader SDLClipboard;

static this()
{
	SDLClipboard = new SDLClipboardLoader();
}

static ~this()
{
	if( SharedLibLoader.isAutoUnloadEnabled() ) SDLClipboard.unload();
}

SDLExtInitDel getClipboardInitializer()
{
	return
	{
		SDLClipboard.load();
		enforce( 0 <= SDLScrap_Init(), "init : failure in SDLScrap_Init" );
		return { };
	};
}

string getClipboardText()
{
	size_t text_buffer_length = 0;
	char* text_buffer = null;

	SDLScrap_PasteFromClipboard( SDL_CLIPBOARD_TEXT_TYPE.ptr, &text_buffer_length, &text_buffer );
	scope( exit ) SDLScrap_FreeBuffer( text_buffer );
	return text_buffer[ 0 .. text_buffer_length ].idup;
}


debug(clipboard):

import win32.windows;
import std.stdio;

void main()
{
	SDLClipboard.load();

	writeln( getClipboardText() );
}
*/