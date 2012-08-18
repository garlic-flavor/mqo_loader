module sworks.compo.sdl.ft;
/+

public import std.conv, std.exception;
public import derelict.freetype.ft;
public import sworks.compo.util.readz;
public import sworks.compo.sdl.util;

/*############################################################################*\
|*#                                Functions                                 #*|
\*############################################################################*/

/*############################################################################*\
|*#                                Interfaces                                #*|
\*############################################################################*/
/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                  IFont                                   |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
interface IFont
{
	bool provide( dchar );
	short width() @property;
	short height() @property;
	SDL_Color color() @property;
	void color( SDL_Color ) @property;
	SDL_Color backColor() @property;
	void backColor( SDL_Color ) @property;
	SDL_Color[2] colorset() @property;
	void colorset( SDL_Color[2] ) @property;
	void invertColor();
	void render( SDL_Surface*, short, short, dchar );
}
/*############################################################################*\
|*#                                 Classes                                  #*|
\*############################################################################*/
/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                             FreeTypeLibrary                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class FreeTypeLibrary
{
	FT_Library library;
	alias library this;

	SDLExtInitDel getInitializer()
	{
		return
		{
			DerelictFT.load();
			enforce( 0 == FT_Init_FreeType( &library ), "getFTInitializer : failure in FT_InitFreeType." );
			return { FT_Done_FreeType( library ); };
		};
	}
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                   Font                                   |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class Font : IFont
{
	FT_Face face;
	alias face this;
	enum BOLD_SHIFT = 6;

	SDL_Color[2] _c;

    //----------------------------------------------------------------------
    // ctor dtor
	this() { enforce(face); }

	this( FT_Library library, const(char)* fontpath, int width, int height, int idx = 0 )
	{
		auto error = FT_New_Face( library, fontpath, idx, &face );
		enforce( error != FT_Err_Unknown_File_Format
		       , "Face.this : FT_Err_Unknown_File_Format( \"" ~ ReadzA(fontpath)[] ~ "\");" );
		enforce( 0 == error, "Face.this : failure in FT_New_Face( \"" ~ ReadzA(fontpath)[] ~ "\" );" );

		enforce( 0 == FT_Set_Pixel_Sizes( face, width, height )
		       , "Face.this : failure in FT_Set_Pixel_Sizes( \"" ~ ReadzA(fontpath)[] ~ "\" );" );
	}

	~this() { FT_Done_Face( face ); }

    //----------------------------------------------------------------------
	bool provide( dchar c ) { return 0 != FT_Get_Char_Index( face, c ); }
	short baseline() @property { return cast(short)( face.size.metrics.ascender >> 6 ); }
	short width() @property { return cast(short)( face.size.metrics.max_advance >> 6 ); }
	short height() @property { return cast(short)( face.size.metrics.height >> 6 ); }
	SDL_Color color() @property { return _c[1]; }
	void color( SDL_Color c ) @property { _c[1] = c; }
	SDL_Color backColor() @property { return _c[0]; }
	void backColor( SDL_Color c ) @property { _c[0] = c; }
	SDL_Color[2] colorset() @property { return _c; }
	void colorset( SDL_Color[2] c ) @property { _c[] = c; }
	void invertColor() @property { auto t = _c[0]; _c[0] = _c[1]; _c[1] = t; }

    //----------------------------------------------------------------------
    // rendering
	void render( SDL_Surface* target, short x, short bl, dchar c )
	{
		auto glyph_idx = FT_Get_Char_Index( face, c );
		enforce( 0 == FT_Load_Glyph( face, glyph_idx, FT_LOAD_RENDER | FT_LOAD_TARGET_MONO )
		       , "Face.render : failure in FT_Load_Glyph( \"" ~ to!string(c) ~ "\" )" );

		auto bmp = face.glyph.bitmap;
		auto src = enforce( SDL_CreateRGBSurfaceFrom( bmp.buffer, bmp.width, bmp.rows, 1, bmp.pitch, 0, 0, 0, 0 )
		                  , "Face.render : failure in SDL_CreateRGBSurfaceFrom( \"" ~ to!string(c) ~ "\")" );
		scope( exit ) SDL_FreeSurface( src );
		SDL_SetPalette( src, SDL_LOGPAL, _c.ptr, 0, _c.length );
		auto r = SDL_Rect( cast(short)( x + face.glyph.bitmap_left )
		                 , cast(short)( bl - face.glyph.bitmap_top ), 0, 0 );
		SDL_BlitSurface( src, null, target, &r );
	}

    // enbold
	void renderB( SDL_Surface* target, short x, short bl, dchar c )
	{
		auto glyph_idx = FT_Get_Char_Index( face, c );
		enforce( 0 == FT_Load_Glyph( face, glyph_idx, FT_LOAD_DEFAULT | FT_LOAD_NO_BITMAP )
		       , "Face.render : failure in FT_Load_Glyph( \"" ~ to!string(c) ~ "\" )" );
		assert( FT_Glyph_Format.FT_GLYPH_FORMAT_OUTLINE == face.glyph.format );
		FT_Outline_Embolden( &(face.glyph.outline), 1 << BOLD_SHIFT );
		FT_Render_Glyph( face.glyph, FT_Render_Mode.FT_RENDER_MODE_MONO );

		auto bmp = face.glyph.bitmap;
		auto src = enforce( SDL_CreateRGBSurfaceFrom( bmp.buffer, bmp.width, bmp.rows, 1, bmp.pitch, 0, 0, 0, 0 )
		                  , "Face.render : failure in SDL_CreateRGBSurfaceFrom( \"" ~ to!string(c) ~ "\")" );
		scope( exit ) SDL_FreeSurface( src );
		SDL_SetPalette( src, SDL_LOGPAL, _c.ptr, 0, _c.length );
		auto r = SDL_Rect( cast(short)( x + face.glyph.bitmap_left )
		                 , cast(short)( bl - face.glyph.bitmap_top ), 0, 0 );
		SDL_BlitSurface( src, null, target, &r );
	}

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                ASCIIFont                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class ASCIIFont : IFont
{
protected:
	SDL_Surface* surface;
	short _width;
	short _height;

	short getX( dchar c ){ return '\0' == c ? 0 : cast(short)(((c-0x20) & 0xf) * _width); }
	short getY( dchar c ){ return '\0' == c ? 0 : cast(short)((((c-0x20) >> 4) & 0xf) * _height); }

public:
    //----------------------------------------------------------------------
	this( FT_Library library, const(char)* fontfile, short width, short height, int idx = 0 )
	{
		scope auto font = new Font( library, fontfile, width, height, idx );
		font.color = SDL_Color( 0, 0, 0 );
		font.backColor = SDL_Color( 0xff, 0xff, 0xff );
		this._width = font.width;
		this._height = font.height;
		surface = enforce( SDL_CreateRGBSurface( SDL_HWSURFACE, _width * 16, _height * 6 , 8, 0, 0, 0, 0 )
		                 , "ASCIIFont.ctor : failure in SDL_CreateRGBSurface" );
		surface.format.palette.ncolors = 2;
		SDL_SetPalette( surface, SDL_LOGPAL, [ SDL_Color( 0xff, 0xff, 0xff ), SDL_Color( 0, 0, 0 ) ].ptr, 0, 2 );

		auto baseline = font.baseline;
		for( dchar c = 0x20 ; c < 0x7f ; c++ )
			font.render( surface, getX(c), cast(short)(getY(c) + baseline ), c );
	}

	~this() { SDL_FreeSurface( surface ); }

    //----------------------------------------------------------------------
    // properties
	bool provide( dchar c ) { return '\0' == c || ( 0x20 <= c && c <= 0x7f ); }
	short width() @property { return _width; }
	short height() @property { return _height; }
	SDL_Color color() @property
	{
		SDL_Color c;
		SDL_GetRGB( 1, surface.format, &(c.r), &(c.g), &(c.b) );
		return c;
	}
	void color( SDL_Color c ) @property { SDL_SetPalette( surface, SDL_LOGPAL, &c, 1, 1 ); }
	SDL_Color backColor() @property
	{
		SDL_Color c;
		SDL_GetRGB( 0, surface.format, &(c.r), &(c.g), &(c.b) );
		return c;
	}
	void backColor( SDL_Color c ) @property { SDL_SetPalette( surface, SDL_LOGPAL, &c, 0, 1 ); }

	SDL_Color[2] colorset() @property
	{
		SDL_Color[2] c;
		SDL_GetRGB( 0, surface.format, &(c[0].r), &(c[0].g), &(c[0].b) );
		SDL_GetRGB( 1, surface.format, &(c[1].r), &(c[1].g), &(c[1].b) );
		return c;
	}
	void colorset( SDL_Color[2] c ) @property { SDL_SetPalette( surface, SDL_LOGPAL, c.ptr, 0, c.length ); }

	void invertColor()
	{
		SDL_Color[2] c;
		SDL_GetRGB( 0, surface.format, &(c[1].r), &(c[1].g), &(c[1].b) );
		SDL_GetRGB( 1, surface.format, &(c[0].r), &(c[0].g), &(c[0].b) );
		SDL_SetPalette( surface, SDL_LOGPAL, c.ptr, 0, c.length );
	}
    //----------------------------------------------------------------------
    // renderling
	void render( SDL_Surface* target, short x, short y, dchar c )
	{
		auto src_rect = SDL_Rect( getX(c), getY(c), _width, _height );
		auto dst_rect = SDL_Rect( x, y, 0, 0 );
		SDL_BlitSurface( surface, &src_rect, target, &dst_rect );
	}
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                CacheFont                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class CacheFont : IFont
{
	extern(C) static FT_Error face_requester( FTC_FaceID faceID, FT_Library library, FT_Pointer data
	                                        , FT_Face* face )
	{
		return FT_New_Face( library, cast(const(char)*)faceID, 0, face );
	}

	FTC_Manager manager;
	FTC_CMapCache cache;
	ReadzA fontpath;
	FT_Size size;
	FTC_SBitCache bitmap;
	FTC_ImageTypeRec font_type;
	int cmap_idx;
	SDL_Color[2] _c;

	this( FT_Library library, const(char)* fp, int w, int h )
	{
		this.fontpath = ReadzA( fp );
		enforce( 0 == FTC_Manager_New( library, 0, 0, 0, &face_requester, null, &manager )
		       , "CacheFont.ctor : failure in FTC_Manager_New( \"" ~ ReadzA(fp)[] ~ "\" )" );
		enforce( 0 == FTC_CMapCache_New( manager, &cache )
		       , "CacheFont.ctor : failure in FTC_CMapCache_New( \"" ~ ReadzA(fp)[] ~ "\" )" );
		enforce( 0 == FTC_SBitCache_New( manager, &bitmap )
		       , "CacheFont.ctor : failure in FTC_SBitCache_New( \"" ~ ReadzA(fp)[] ~ "\" )" );

		FT_Face face;
		enforce( 0 == FTC_Manager_LookupFace( manager, cast(FTC_FaceID)fontpath.ptr, &face )
		       , "CacheFont.ctor : failure in FTC_Manager_LookupFace( \"" ~ ReadzA(fp)[] ~ "\" )" );

		cmap_idx = FT_Get_Charmap_Index( face.charmap );
		enforce( 0 <= cmap_idx, "CacheFont.ctor : failure in FT_GetCharmap_Index with \"" ~ ReadzA(fp)[] ~ "\"." );

		FTC_ScalerRec scaler;
		with( scaler )
		{
			face_id = cast(FTC_FaceID)fontpath.ptr;
			width = w;
			height = h;
			pixel = 1;
		}
		enforce( 0 == FTC_Manager_LookupSize( manager, &scaler, &size )
		       , "CacheFont.ctor : failure in FTC_Manager_LookupSize with \"" ~ ReadzA(fp)[] ~ "\"." );

		with( font_type )
		{
			face_id = cast(FTC_FaceID)fontpath.ptr;
			width = scaler.width;
			height = scaler.height;
			flags = FT_LOAD_RENDER | FT_LOAD_TARGET_MONO;
		}
	}

	~this()
	{
		FTC_Manager_RemoveFaceID( manager, cast(FTC_FaceID)fontpath.ptr );
		FTC_Manager_Done( manager );
	}

    //----------------------------------------------------------------------
    // getter
	bool provide( dchar c )
	{
		FT_Face face;
		enforce( 0 == FTC_Manager_LookupFace( manager, cast(FTC_FaceID)fontpath.ptr, &face ) );
		return 0 != FT_Get_Char_Index( face, c );
	}
	short baseline() @property { return cast(short)( size.metrics.ascender >> 6 ); }
	short width() @property { return cast(short)font_type.width; }
	short height() @property { return cast(short)font_type.height; }
	SDL_Color color() @property { return _c[1]; }
	void color( SDL_Color c ) @property { _c[1] = c; }
	SDL_Color backColor() @property { return _c[0]; }
	void backColor( SDL_Color c ) @property { _c[0] = c; }
	SDL_Color[2] colorset() @property { return _c; }
	void colorset( SDL_Color[2] c ) @property { _c[] = c; }
	void invertColor() { auto t = _c[0]; _c[0] = _c[1]; _c[1] = t; }

    //----------------------------------------------------------------------
    // rendering
	void render( SDL_Surface* target, short x, short bl, dchar d )
	{
		auto glyph_idx = FTC_CMapCache_Lookup( cache, cast(FTC_FaceID)fontpath.ptr, cmap_idx, d );
		FTC_SBit bits;
		FTC_SBitCache_Lookup( bitmap, &font_type, glyph_idx, &bits, null );
		auto src = SDL_CreateRGBSurfaceFrom( bits.buffer, bits.width, bits.height, 1, bits.pitch, 0, 0, 0, 0 );
		scope( exit ) SDL_FreeSurface( src );
		SDL_SetPalette( src, SDL_LOGPAL, _c.ptr, 0, _c.length );
		auto r = SDL_Rect( cast(short)( x + bits.left ), cast(short)( bl - bits.top ), 0, 0 );
		SDL_BlitSurface( src, null, target, &r );
	}

}



////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(ft):

scope class FTMain
{ mixin SDLWindowMix!() SWM;

	FreeTypeLibrary ftl;
	ASCIIFont font;

    //----------------------------------------------------------------------
    // ctor dtor
	this()
	{
		ftl = new FreeTypeLibrary;
		SWM.ctor( SDL_INIT_VIDEO, 640, 480, 8, SDL_HWPALETTE, ftl.getInitializer() );
		font = new ASCIIFont( ftl, "C:\\Windows\\Fonts\\LiberationMono-Regular.ttf", 0, 20 );
		font.color = SDL_Color( 0xff, 0, 0 );
		font.backColor = SDL_Color( 0xff, 0xff, 0 );
		font.render( screen, 10, 10, 'x' );
		font.render( screen, 20, 10, '#' );

		scope auto f2 = new CacheFont( ftl, "C:\\Windows\\Fonts\\meiryo.ttc", 20, 20 );
		f2.color = SDL_Color( 0xff, 0xff, 0xff );
		f2.backColor = SDL_Color( 0, 0, 0 );
		f2.render( screen, 200, 100, '\U00020213' );
		f2.render( screen, cast(short)(200 + f2.width), 100, 'a' );

		SDL_UpdateRect( screen, 0, 0, 0, 0 );
	}

	~this() { delete font; SWM.dtor; }
}


void main()
{
	scope auto ftmain = new FTMain();
	ftmain.mainLoop();
}
+/