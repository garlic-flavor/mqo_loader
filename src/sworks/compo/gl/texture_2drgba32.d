/**
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.gl.texture_2drgba32;

import sworks.compo.gl.port;

class Texture2DRGBA32
{
	GLuint id = 0;
	alias id this;
	this( GLsizei width, GLsizei height, const(GLvoid)* data)
	{
		GLenum type;
		version(BigEndian) type = GL_UNSIGNED_INT_8_8_8_8;
		version(LittleEndian) type = GL_UNSIGNED_INT_8_8_8_8_REV;
		glGenTextures(1,cast(uint*)&id);
		glBindTexture(GL_TEXTURE_2D,id);
		glPixelStorei(GL_UNPACK_ALIGNMENT,4);
		glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,width,height,0,GL_RGBA,type,cast(void*)data );
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glBindTexture(GL_TEXTURE_2D,0);
	}

	void clear() { glDeleteTextures(1,&id); }

	void bindScope( scope void delegate() prog)
	{
		glActiveTexture( GL_TEXTURE0 );
		glBindTexture(GL_TEXTURE_2D,id);
		prog();
		glBindTexture(GL_TEXTURE_2D,0);
	}

}

