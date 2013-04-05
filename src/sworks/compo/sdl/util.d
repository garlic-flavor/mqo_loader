/**
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.sdl.util;

public import std.exception, std.conv, std.file, std.traits, std.algorithm;
public import sworks.compo.sdl.port;
debug public import std.stdio;

/*############################################################################*\
|*#                                Functions                                 #*|
\*############################################################################*/
SDLExtInitDel getGLInitializer(alias LOADER)( bool double_buffer, int depth_size, int red_size, int green_size
                                            , int blue_size, int alpha_size, int samples = 0 )
{
	return
	{
		LOADER.load();
		SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, double_buffer ? 1 : 0 );
		SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE, depth_size );
		SDL_GL_SetAttribute( SDL_GL_RED_SIZE, red_size );
		SDL_GL_SetAttribute( SDL_GL_GREEN_SIZE, green_size );
		SDL_GL_SetAttribute( SDL_GL_BLUE_SIZE, blue_size );
		SDL_GL_SetAttribute( SDL_GL_ALPHA_SIZE, alpha_size );

		if( 0 < samples )
		{
			SDL_GL_SetAttribute( SDL_GL_MULTISAMPLEBUFFERS, 1 );
			SDL_GL_SetAttribute( SDL_GL_MULTISAMPLESAMPLES, samples );
		}
		return {};
	};
}

/*############################################################################*\
|*#                                Constants                                 #*|
\*############################################################################*/
alias void delegate() SDLExtQuitDel;
alias SDLExtQuitDel delegate() SDLExtInitDel;

/*############################################################################*\
|*#                                Structures                                #*|
\*############################################################################*/
/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                   Size                                   |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
struct Size { int w, h; }

/*############################################################################*\
|*#                                Templates                                 #*|
\*############################################################################*/

/*TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT*\
|*|                               SDLWindowMix                               |*|
\*TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT*/
template SDLWindowMix( CASES ... )
{
	static void logout( string msg )
	{
		debug writeln( msg );
		else append( "log-out.txt", msg );
	}

    //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

	SDL_Window* window;
	SDL_Renderer* renderer;

	SDL_GLContext context;
	
	SDLExtQuitDel[] _SDLQuits;

	void ctor( uint initFlag, const char* title, int width, int height, uint videoFlag, SDLExtInitDel[] inits ... )
	{
		// init SDL
		DerelictSDL2.load();
		enforce( 0 <= SDL_Init( initFlag ), typeof(this).stringof ~ ".SDLWindowMix.ctor : failure in SDL_Init" );

		// init ext
		_SDLQuits.length = inits.length;
		for( int i=0 ; i < inits.length ; ++i ) _SDLQuits[i] = inits[i]();

		// create window
		window = enforce( SDL_CreateWindow( title, SDL_WINDOWPOS_UNDEFINED_MASK, SDL_WINDOWPOS_UNDEFINED_MASK
		                                   , width, height, videoFlag  )
		                , typeof(this).stringof ~ "SDLWindowMix.ctor : failure in SDL_SetVideoMode" );


		if( SDL_WINDOW_OPENGL & videoFlag )
		{
			context = SDL_GL_CreateContext( window );
			SDL_GL_MakeCurrent( window, context );
			SDL_GL_SwapWindow( window );
		}
		else
		{
			renderer = SDL_CreateRenderer( window, -1, SDL_RENDERER_ACCELERATED );
			SDL_UpdateWindowSurface( window );
		}
	}

	void dtor()
	{
		if( null !is context ) SDL_GL_DeleteContext( context );
		if( null !is renderer ) SDL_DestroyRenderer( renderer );
		if( null !is window ) SDL_DestroyWindow( window );

		foreach_reverse( one ; _SDLQuits ) one();
		SDL_Quit();
		DerelictSDL2.unload;
	}

	void sdl_quit( ref SDL_QuitEvent ){}
	void sdl_window( ref SDL_WindowEvent ){}
	void sdl_syswm( ref SDL_SysWMEvent ){}
	void sdl_keydown( ref SDL_KeyboardEvent ){}
	void sdl_keyup( ref SDL_KeyboardEvent ){}
	void sdl_textediting( ref SDL_TextEditingEvent ){}
	void sdl_textinput( ref SDL_TextInputEvent ){}
	void sdl_mousemotion( ref SDL_MouseMotionEvent ){}
	void sdl_mousebuttondown( ref SDL_MouseButtonEvent ){}
	void sdl_mousebuttonup( ref SDL_MouseButtonEvent ){}
	void sdl_mousewheel( ref SDL_MouseWheelEvent ){}
	void sdl_joyaxismotion( ref SDL_JoyAxisEvent ){}
	void sdl_joyhatmotion( ref SDL_JoyHatEvent ){}
	void sdl_joybuttondown( ref SDL_JoyButtonEvent ){}
	void sdl_joybuttonup( ref SDL_JoyButtonEvent ){}
	void sdl_userevent( ref SDL_UserEvent ){}

	void mainLoop()
	{
		SDL_Event event;
		loop:while(1)
		{
			try while( 0 <= SDL_WaitEvent( &event ) )
			{
				final switch( event.type )
				{
					case        SDL_FIRSTEVENT:
					break; case SDL_QUIT: this.sdl_quit( event.quit ); break loop;
					break; case SDL_WINDOWEVENT: this.sdl_window( event.window );
					break; case SDL_SYSWMEVENT: this.sdl_syswm( event.syswm );
					break; case SDL_KEYDOWN: this.sdl_keydown( event.key );
					break; case SDL_KEYUP: this.sdl_keyup( event.key );
					break; case SDL_TEXTEDITING: this.sdl_textediting( event.edit );
					break; case SDL_TEXTINPUT: this.sdl_textinput( event.text );
					break; case SDL_MOUSEMOTION: this.sdl_mousemotion( event.motion );
					break; case SDL_MOUSEBUTTONDOWN: this.sdl_mousebuttondown( event.button );
					break; case SDL_MOUSEBUTTONUP: this.sdl_mousebuttonup( event.button );
					break; case SDL_MOUSEWHEEL: this.sdl_mousewheel( event.wheel );
					break; case SDL_INPUTMOTION:
					break; case SDL_INPUTBUTTONDOWN:
					break; case SDL_INPUTBUTTONUP:
					break; case SDL_INPUTWHEEL:
					break; case SDL_INPUTPROXIMITYIN:
					break; case SDL_INPUTPROXIMITYOUT:
					break; case SDL_JOYAXISMOTION: this.sdl_joyaxismotion( event.jaxis );
					break; case SDL_JOYBALLMOTION:
					break; case SDL_JOYHATMOTION: this.sdl_joyhatmotion( event.jhat );
					break; case SDL_JOYBUTTONDOWN: this.sdl_joybuttondown( event.jbutton );
					break; case SDL_JOYBUTTONUP: this.sdl_joybuttonup( event.jbutton );
					break; case SDL_FINGERDOWN:
					break; case SDL_FINGERUP:
					break; case SDL_FINGERMOTION:
					break; case SDL_TOUCHBUTTONDOWN:
					break; case SDL_TOUCHBUTTONUP:
					break; case SDL_DOLLARGESTURE:
					break; case SDL_DOLLARRECORD:
					break; case SDL_MULTIGESTURE:
					break; case SDL_CLIPBOARDUPDATE:
					break; case SDL_DROPFILE:
					break; case SDL_USEREVENT: this.sdl_userevent( event.user );
					break; case SDL_LASTEVENT:
					break;
				}
			}
			catch( Throwable t ) logout( t.toString );
		}
	}
}


/*TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT*\
|*|                            SDLTimerWindowMix                             |*|
\*TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT*/
template SDLIdleWindowMix( CASES ... )
{ mixin SDLWindowMix!CASES SWM;

	protected uint _spf;
	protected uint _prevTime;

    //----------------------------------------------------------------------
    // ctor
	void ctor( uint initFlag, const(char)* title, int width, int height, uint videoFlag, uint spf
	         , SDLExtInitDel[] inits ... )
	{
		SWM.ctor( initFlag, title, width, height, videoFlag, inits );
		this._spf = spf;
		_prevTime = SDL_GetTicks();
	}

	void update(uint){}
	void draw(){}
	
	void idle( )
	{
		uint time = SDL_GetTicks();
		if( time < _prevTime + _spf )
		{
			SDL_Delay( _prevTime + _spf - time );
			time = _prevTime + _spf;
		}

		this.update( time - _prevTime );
		this.draw();
		_prevTime = time;
	}

	void mainLoop()
	{
		SDL_Event event;
		loop:while(1)
		{
			try while( SDL_PollEvent( &event ) )
			{
				final switch( event.type )
				{
					case        SDL_FIRSTEVENT:
					break; case SDL_QUIT: this.sdl_quit( event.quit ); break loop;
					break; case SDL_WINDOWEVENT: this.sdl_window( event.window );
					break; case SDL_SYSWMEVENT: this.sdl_syswm( event.syswm );
					break; case SDL_KEYDOWN: this.sdl_keydown( event.key );
					break; case SDL_KEYUP: this.sdl_keyup( event.key );
					break; case SDL_TEXTEDITING: this.sdl_textediting( event.edit );
					break; case SDL_TEXTINPUT: this.sdl_textinput( event.text );
					break; case SDL_MOUSEMOTION: this.sdl_mousemotion( event.motion );
					break; case SDL_MOUSEBUTTONDOWN: this.sdl_mousebuttondown( event.button );
					break; case SDL_MOUSEBUTTONUP: this.sdl_mousebuttonup( event.button );
					break; case SDL_MOUSEWHEEL: this.sdl_mousewheel( event.wheel );
					break; case SDL_INPUTMOTION:
					break; case SDL_INPUTBUTTONDOWN:
					break; case SDL_INPUTBUTTONUP:
					break; case SDL_INPUTWHEEL:
					break; case SDL_INPUTPROXIMITYIN:
					break; case SDL_INPUTPROXIMITYOUT:
					break; case SDL_JOYAXISMOTION: this.sdl_joyaxismotion( event.jaxis );
					break; case SDL_JOYBALLMOTION:
					break; case SDL_JOYHATMOTION: this.sdl_joyhatmotion( event.jhat );
					break; case SDL_JOYBUTTONDOWN: this.sdl_joybuttondown( event.jbutton );
					break; case SDL_JOYBUTTONUP: this.sdl_joybuttonup( event.jbutton );
					break; case SDL_FINGERDOWN:
					break; case SDL_FINGERUP:
					break; case SDL_FINGERMOTION:
					break; case SDL_TOUCHBUTTONDOWN:
					break; case SDL_TOUCHBUTTONUP:
					break; case SDL_DOLLARGESTURE:
					break; case SDL_DOLLARRECORD:
					break; case SDL_MULTIGESTURE:
					break; case SDL_CLIPBOARDUPDATE:
					break; case SDL_DROPFILE:
					break; case SDL_USEREVENT: this.sdl_userevent( event.user );
					break; case SDL_LASTEVENT:
					break;
				}
			}
			catch( Throwable t ) logout( t.toString );
			this.idle();
		}
	}
}

////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug( sdl_util ) :

scope class SDLTest
{ mixin SDLWindowMix!() SWM;

	this()
	{
		SWM.ctor( SDL_INIT_VIDEO, "hello SDL",  640, 480, 0 );
	}

	~this() { SWM.dtor; }
}


void main()
{
	scope auto sdltest = new SDLTest();
	sdltest.mainLoop;
}
