module sworks.compo.sdl.ttf;
/+
public import std.exception, std.conv, std.utf;
public import derelict.sdl.ttf;
public import sworks.compo.util.readz;
public import sworks.compo.sdl.util;

version( Windows )
{
	pragma( lib, "lib\\DerelictSDLttf.lib" );
}
version( linux )
{ // 分割コンパイルする場合は、-L-lDerelictSDLttf をdmdに渡す。
	pragma( lib, "DerelictSDLttf" );
}

/*############################################################################*\
|*#                                Functions                                 #*|
\*############################################################################*/
/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                            getTTFInitializer                             |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
SDLExtInitDel getTTFInitializer() { return { DerelictSDLttf.load; TTF_Init(); return { TTF_Quit(); }; }; }

/*############################################################################*\
|*#                                 Classes                                  #*|
\*############################################################################*/
/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                   Font                                   |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class Font
{
	TTF_Font* font;
	alias font this;

    //----------------------------------------------------------------------
    // ctor dtor
	this( const(char)* fontfile, int ptsize )
	{
		font = enforce( TTF_OpenFont( fontfile, ptsize )
		              , "Font.ctor : failure in TTF_OpenFont( \"" ~ to!string(fontfile) ~ "\" );" );
	}

	~this(){ if( null !is font ) TTF_CloseFont( font ); }

    //----------------------------------------------------------------------
    // property
	int style() @property { return TTF_GetFontStyle( font ); }
	void style( int s ) @property { return TTF_SetFontStyle( font, s ); }
	int outline() @property { return TTF_GetFontOutline( font ); }
	void outline( int o ) @property { TTF_SetFontOutline( font, o ); }
	int hinting() @property { return TTF_GetFontHinting( font ); }
	void hinting( int h ) @property { TTF_SetFontHinting( font, h ); }
	bool kerning() @property { return 0 != TTF_GetFontKerning( font ); }
	void kerning( bool k ) @property { TTF_SetFontKerning( font, k ? 1 : 0 ); }
	int height() @property { return TTF_FontHeight( font ); }
	int ascent() @property { return TTF_FontAscent( font ); }
	int descent() @property { return TTF_FontDescent( font ); }
	int lineskip() @property { return TTF_FontLineSkip( font ); }
	int fontfaces() @property { return TTF_FontFaces( font ); }
	bool isFixedWidth() @property { return 0 < TTF_FontFaceIsFixedWidth( font ); }
	Readz familyName() @property { return Readz( TTF_FontFaceFamilyName( font ) ); }
	Readz styleName() @property { return Readz( TTF_FontFaceStyleName( font ) ); }

    //----------------------------------------------------------------------
    //
	bool provide( wchar wc ) { return 0 != TTF_GlyphIsProvided( font, wc ); }
    //
	Size textSize( const(char)* s )
	{
		Size size;
		enforce( 0 == TTF_SizeUTF8( font, s, &(size.w), &(size.h ) )
		       , "Font.textSize : failure in TTF_SizeUTF8( \"" ~ ReadzA(s)[] ~ "\" );" );
		return size;
	}
    //
	Size textSize( const(wchar)* s )
	{
		Size size;
		enforce( 0 == TTF_SizeUNICODE( font, cast(ushort*)s, &(size.w), &(size.h ) )
		       , "Font.textSize : failure in TTF_SizeUNICODE( \"" ~ ReadzA(s)[] ~ "\" );" );
		return size;
	}

    //----------------------------------------------------------------------
    // rendering
	SDL_Surface* render( const(char)* text, SDL_Color fg )
	{
		return enforce( TTF_RenderUTF8_Solid( font, text, fg )
		              , "Font.render : failure in TTF_RenderUTF8_Solid( \"" ~ ReadzA(text)[] ~ "\" ); " );
	}
    //
	SDL_Surface* render( const(wchar)* text, SDL_Color fg )
	{
		return enforce( TTF_RenderUNICODE_Solid( font, cast(ushort*)text, fg )
		              , "Font.render : failure in TTF_RenderUNICODE_Solid( \"" ~ ReadzA(text)[] ~ "\" ); " );
	}

    //
	SDL_Surface* render( wchar c, SDL_Color fg )
	{
		return enforce( TTF_RenderGlyph_Solid( font, cast(wchar)c, fg )
		              , "Font.render : failure in TTF_RenderGlyph_Solid( '" ~ ReadzA([c])[] ~ "' );" );
	}

    //
	void render( SDL_Surface* dest, short x, short y, const(char)* text, SDL_Color fg )
	{
		auto ch = render( text, fg );
		scope( exit ) SDL_FreeSurface( ch );
		SDL_Rect r = SDL_Rect( x, y, 0, 0 );
		enforce( 0 == SDL_BlitSurface( ch, null, dest, &r )
		       , "Font.render : failure in SDL_BlitSurface( \"" ~ to!string(text) ~ "\" );" );
	}

    //
	void render( SDL_Surface* dest, short x, short y, const(wchar)* text, SDL_Color fg )
	{
		auto ch = render( text, fg );
		scope( exit ) SDL_FreeSurface( ch );
		SDL_Rect r = SDL_Rect( x, y, 0, 0 );
		enforce( 0 == SDL_BlitSurface( ch, null, dest, &r )
		       , "Font.render : failure in SDL_BlitSurface( \"" ~ ReadzA(text)[] ~ "\" );" );
	}

    //
	void render( SDL_Surface* dest, short x, short y, wchar c, SDL_Color fg )
	{
		auto ch = render( c, fg );
		scope( exit ) SDL_FreeSurface( ch );
		SDL_Rect r = SDL_Rect( x, y, 0, 0 );
		enforce( 0 == SDL_BlitSurface( ch, null, dest, &r )
		       , "Font.render : failure in SDL_BlitSurface( \"" ~ to!string(c) ~ "\" );" );
	}
}
/+
class ASCIIFont : Font
{
protected:
	int _width;
	int _height;
	SDL_Surface* surface;

public:
    //----------------------------------------------------------------------
	this( const(char)* fontfile, int ptsize )
	{
		super( fontfile, ptsize );
		hinting = TTF_HINTING_MONO;
		_height = lineskip;
		TTF_GlyphMetrics( font, cast(ushort)'X', null, null, null, null, &_width );
	}

    //----------------------------------------------------------------------
    // properties
	int width() @property { return _width; }
	override int height() @property { return _height; }

}
+/
////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(ttf):
import sworks.compo.sdl.util;
import std.stdio;

scope class SDLMain
{ mixin SDLWindowMix!() SWM;

	Font font;
	this()
	{
		SWM.ctor( SDL_INIT_VIDEO, 640, 480, 8, SDL_HWPALETTE, getTTFInitializer );
		font = new Font( "C:\\Windows\\fonts\\meiryo.ttc", 16 );
		font.render( screen, 0, 0, ("hello \U0002000B"w).ptr, SDL_Color( 0xff, 0xff, 0xff ) );

		auto r = SDL_Rect( 10, 50, 100, 100 );
		SDL_FillRect( screen, &r, 1 );
		
		SDL_UpdateRect( screen, 0, 0, 0, 0 );
	}
	~this() { delete font; SWM.dtor(); }
}

void main()
{
	scope auto wnd = new SDLMain();
	wnd.mainLoop();
}
+/