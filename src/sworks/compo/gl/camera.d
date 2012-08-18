module sworks.compo.gl.camera;

/+
import sworks.compo.gl.port;
public import sworks.compo.util.matrix;
public import sworks.compo.gl.viewport_matrix;


class Camera
{
  Matrix4d projMat;
  Matrix4d inv_projMat;
  Matrix4d modelMat;
  ViewportMatrix viewMat;

  GLdouble fovy, zNear, zFar;
  Vector3d eye,center,up;
  Vector3d mouse;

  this(uint width, uint height, GLdouble fovy, GLdouble zNear, GLdouble zFar)
  {
    viewMat = new ViewportMatrix;

    this.fovy = fovy;
    this.zNear = zNear;
    this.zFar = zFar;

    updateView(width,height);
    updateProjection();

    modelMat.loadIdentity;
  }

  void updateView(uint width, uint height)
  {
    viewMat.apply(0,0,width,height);
  }

  void updateProjection()
  {
    projMat = Matrix4d.perspectiveMatrix(fovy, viewMat.aspect, zNear,zFar);
    inv_projMat = projMat.inverseMatrix();

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glLoadMatrixd(projMat.ptr);
    glMatrixMode(GL_MODELVIEW);
  }
  void updatePos()
  {
    modelMat = Matrix4d.lookAtMatrix(eye,center,up);
    glLoadMatrixd(modelMat.ptr);
  }

  Vector3d toMouse(double x, double y)
  {
    Matrix4d invMat = modelMat.inverseMatrix * inv_projMat;
    mouse = [ x, y, 0.0 ];
    viewMat.inverseApplyTo(mouse);
    mouse = invMat * mouse;
    mouse -= eye;
    return mouse.normalize;
  }

  double distanceFrom(Vector3d obj) { return distance(eye,obj); }
}
+/