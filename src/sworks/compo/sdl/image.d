/**
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.sdl.image;

public import std.exception;
public import derelict.sdl2.image;
public import sworks.compo.sdl.util;


SDLExtInitDel getImageInitializer( uint initFlags )
{
	return {
		DerelictSDL2Image.load();
		enforce( initFlags == IMG_Init( initFlags ), "init : failure in IMG_Init" );
		return { IMG_Quit(); };
	};
}

SDL_Surface* loadImageRGBA32( const(char)* filename)
{
	uint[4] mask;
	version(BigEndian) mask = [0xff000000, 0x00ff0000, 0x0000ff00, 0x000000ff];
	version(LittleEndian) mask = [0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000];

	// load image
	auto image = enforce(IMG_Load(filename),"fail at IMG_Load.");
	scope(exit) SDL_FreeSurface(image);
	//  SDL_SetAlpha(image,0,0);

	//adjust its format to RGBA32
	auto adj = SDL_CreateRGBSurface( 0,image.w,image.h,32,mask[0],mask[1],mask[2],mask[3]);
	SDL_BlitSurface(image,null,adj,null);

	return adj;
}

////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(sdl_image):


scope class SDLTest
{ mixin SDLWindowMix!() SWM;

	SDL_Surface* surface;
	SDL_Texture* texture;

	this()
	{
		SWM.ctor( SDL_INIT_VIDEO, "hello SDL",  640, 480, 0, getImageInitializer( IMG_INIT_JPG ) );

		surface = enforce( IMG_Load( "img\\tex1.jpg" ) );
		texture = SDL_CreateTextureFromSurface( renderer, surface );
		
		SDL_SetRenderDrawColor( renderer, 0, 200, 0, 255 );
		SDL_RenderClear( renderer );

		SDL_RenderCopy( renderer, texture, null, null );

		SDL_RenderPresent( renderer );
	}

	~this()
	{
		SDL_DestroyTexture( texture );
		SDL_FreeSurface( surface );
		SWM.dtor;
	}
}


void main()
{
	scope auto sdltest = new SDLTest();
	sdltest.mainLoop;
}
