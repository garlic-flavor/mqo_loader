/** pmd サンプル
 */

import sworks.compo.util.matrix;
import sworks.compo.gl.util;
import sworks.compo.gl.glsl;
import sworks.compo.sdl.util;
import sworks.compo.sdl.gl;

import sworks.mqo.pmd;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 PMDTest                                  |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class PMDTest
{ mixin SDLIdleWindowMix!() SWM;

	enum WIDTH = 640;
	enum HEIGHT = 480;

	PMDFile pmdfile;
	MikuDrawer mdraw;

	this()
	{
		SWM.ctor( SDL_INIT_VIDEO, "SDL_app", WIDTH, HEIGHT, SDL_WINDOW_OPENGL, 30
		        , getGLInitializer( true, 16, 8, 8, 8, 8 ) );

		DerelictGL3.reload();

		glClearColor( 0, 0.7, 0.0, 1.0 );
		glClearDepth( 1.0 );

		glViewport( 0, 0, WIDTH, HEIGHT );

		glEnable( GL_DEPTH_TEST );
		glDepthFunc( GL_LESS );

//		glEnable( GL_CULL_FACE );
			glCullFace( GL_BACK );


		pmdfile = loadPMDFile( "pmd_sample\\Model\\初音ミク.pmd" );
		mdraw = new MikuDrawer( pmdfile );
	}

	void clear()
	{
		mdraw.clear();
		SWM.dtor;
	}

	void update( uint interval )
	{
		
	}

	void draw()
	{
		glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

		mdraw.draw();

		SDL_GL_SwapWindow( window );
	}

}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                                   main                                   |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
void main()
{
	auto wnd = new PMDTest;
	scope( exit ) wnd.clear();
	wnd.mainLoop;
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                MikuDrawer                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class MikuDrawer
{
     //--------------------------------------------------------------------
	string vertex_shader =
	q{#version 420
		uniform mat4 world;
		in vec3 pos;
		
		void main()
		{
			gl_Position = world * vec4( pos, 1.0 );
		}
	};

     //--------------------------------------------------------------------
	string fragment_shader =
	q{#version 420
		
		layout( location = 0 ) out vec4 colorOut;
		void main()
		{
			colorOut = vec4( 0.8, 0.8, 0.8, 1.0 );
		}
	};

     //--------------------------------------------------------------------
	Shader vs, fs;
	ShaderProgram prog;
	VertexArrayObject vao;

	Matrix4f world;
	void delegate() draw;

	this( PMDFile pmdfile )
	{
		vs = new Shader( GL_VERTEX_SHADER, vertex_shader );
		fs = new Shader( GL_FRAGMENT_SHADER, fragment_shader );
		prog = (new ShaderProgram( vs, fs )).link;
		vao = new VertexArrayObject( prog, pmdfile.data.vertex );
		draw = vao.getDrawer!GL_TRIANGLES( pmdfile.data.face );
	}

	void clear()
	{
		draw = null;
		vao.clear;
		prog.clear;
		vs.clear;
		fs.clear;
	}
}