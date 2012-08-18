module sworks.compo.gl.texture_1drgba32;
/+
import sworks.compo.gl.port;


class Texture1DRGBA32
{
  GLuint id;
  this(const(uint)[] data)
  {
    GLenum type;
    version(BigEndian) type = GL_UNSIGNED_INT_8_8_8_8;
    version(LittleEndian) type = GL_UNSIGNED_INT_8_8_8_8_REV;
    glGenTextures(1,&id);
    glBindTexture(GL_TEXTURE_1D,id);
    glPixelStorei(GL_UNPACK_ALIGNMENT,4);
    glTexImage1D(GL_TEXTURE_1D,0,GL_RGBA,data.length,0,GL_RGBA,type,cast(void*)data.ptr );
    glBindTexture(GL_TEXTURE_1D,0);
  }

  void destroy() { glDeleteTextures(1,&id); }

  void bindScope(scope void delegate() prog)
  {
    glBindTexture(GL_TEXTURE_1D,id);
    prog();
    glBindTexture(GL_TEXTURE_1D,0);
  }

  void beginScope(GLenum mode,cap...)( scope void delegate() prog)
  {
    foreach( one ; cap ) glEnable(one);
    glBindTexture(GL_TEXTURE_1D,id);
    glEnable(GL_TEXTURE_1D);
    glBegin(mode);
    prog();
    glEnd();
    glDisable(GL_TEXTURE_1D);
    glBindTexture(GL_TEXTURE_1D,0);
    foreach_reverse( one ; cap ) glDisable(one);
  }

  void enableScope(cap...)( scope void delegate() prog)
  {
    foreach( one ; cap ) glEnable(one);
    glBindTexture(GL_TEXTURE_1D,id);
    glEnable(GL_TEXTURE_1D);
    prog();
    glDisable(GL_TEXTURE_1D);
    glBindTexture(GL_TEXTURE_1D,0);
    foreach_reverse( one ; cap ) glDisable(one);
  }
}
+/