module sworks.compo.gl.viewport_matrix;
/+
import sworks.compo.gl.port;
public import sworks.compo.util.matrix;



class ViewportMatrix
{
	union
	{
		GLint[4] v;
		struct
		{
			GLint x,y,width,height;
		}
	}
	real inv_width,inv_height;// these are used in inverseApplyTo().

	GLint* ptr() nothrow @property { return v.ptr; }
	real aspect() @property { return cast(real)width/cast(real)height; }

	void apply(GLint x, GLint y, GLint width, GLint height)
	{
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
		inv_width = 2.0L / cast(real)width;
		inv_height = 2.0L / cast(real)height;// inverse Y-axis direction.
		glViewport(x,y,width,height);
	}

	Vector3!(PRECISION) applyTo(PRECISION)(Vector3!(PRECISION) v) const
	{
		v.x = (v.x + 1) * width  * 0.5  + x;
		v.y = (1 - v.y) * height * 0.5  + y;
		v.z = (v.z + 1) * 2;
		return v;
	}

	Vector3!(PRECISION) inverseApplyTo(PRECISION)(Vector3!(PRECISION) v) const
	{
		v.x = (v.x - x) * inv_width - 1;
		v.y = (y - v.y) * inv_height + 1;
		v.z = 2 * v.z - 1;
		return v;
	}

	real inverseApplyToX(real wx) const { return (wx - x) * inv_width - 1; }
	real inverseApplyToY(real wy) const { return (y - wy) * inv_height + 1; }
	real inverseApplyToZ(real wz) const { return 2 * wz - 1; }
}
+/