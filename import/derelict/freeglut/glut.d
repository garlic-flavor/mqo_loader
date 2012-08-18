/*

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/
module derelict.freeglut.glut;

public
{
    import derelict.freeglut.types;
    import derelict.freeglut.functions;
}

private
{
    import derelict.util.loader;
    import derelict.util.system;

    static if(Derelict_OS_Windows)
        enum libNames = "freeglut.dll";
    else static if(Derelict_OS_Mac)
        enum libNames = "libfreeglut.dylib";
    else static if(Derelict_OS_Posix)
        enum libNames = "libfreeglut.so";
    else
        static assert(0, "Need to implement FreeGlut libNames for this operating system.");
}

class DerelictFreeGLUTLoader : SharedLibLoader
{
    protected
    {
        override void loadSymbols()
        {
            bindFunc(cast(void**)&glutInit, "glutInit");
            bindFunc(cast(void**)&glutInitWindowPosition, "glutInitWindowPosition");
            bindFunc(cast(void**)&glutInitWindowSize, "glutInitWindowSize");
            bindFunc(cast(void**)&glutInitDisplayMode, "glutInitDisplayMode");
            bindFunc(cast(void**)&glutInitDisplayString, "glutInitDisplayString");
            bindFunc(cast(void**)&glutMainLoop, "glutMainLoop");
            bindFunc(cast(void**)&glutCreateWindow, "glutCreateWindow");
            bindFunc(cast(void**)&glutCreateSubWindow, "glutCreateSubWindow");
            bindFunc(cast(void**)&glutDestroyWindow, "glutDestroyWindow");
            bindFunc(cast(void**)&glutSetWindow, "glutSetWindow");
            bindFunc(cast(void**)&glutGetWindow, "glutGetWindow");
            bindFunc(cast(void**)&glutSetWindowTitle, "glutSetWindowTitle");
            bindFunc(cast(void**)&glutSetIconTitle, "glutSetIconTitle");
            bindFunc(cast(void**)&glutReshapeWindow, "glutReshapeWindow");
            bindFunc(cast(void**)&glutPositionWindow, "glutPositionWindow");
            bindFunc(cast(void**)&glutShowWindow, "glutShowWindow");
            bindFunc(cast(void**)&glutHideWindow, "glutHideWindow");
            bindFunc(cast(void**)&glutIconifyWindow, "glutIconifyWindow");
            bindFunc(cast(void**)&glutPushWindow, "glutPushWindow");
            bindFunc(cast(void**)&glutPopWindow, "glutPopWindow");
            bindFunc(cast(void**)&glutFullScreen, "glutFullScreen");
            bindFunc(cast(void**)&glutPostWindowRedisplay, "glutPostWindowRedisplay");
            bindFunc(cast(void**)&glutPostRedisplay, "glutPostRedisplay");
            bindFunc(cast(void**)&glutSwapBuffers, "glutSwapBuffers");
            bindFunc(cast(void**)&glutWarpPointer, "glutWarpPointer");
            bindFunc(cast(void**)&glutSetCursor, "glutSetCursor");
            bindFunc(cast(void**)&glutEstablishOverlay, "glutEstablishOverlay");
            bindFunc(cast(void**)&glutRemoveOverlay, "glutRemoveOverlay");
            bindFunc(cast(void**)&glutUseLayer, "glutUseLayer");
            bindFunc(cast(void**)&glutPostOverlayRedisplay, "glutPostOverlayRedisplay");
            bindFunc(cast(void**)&glutPostWindowOverlayRedisplay, "glutPostWindowOverlayRedisplay");
            bindFunc(cast(void**)&glutShowOverlay, "glutShowOverlay");
            bindFunc(cast(void**)&glutHideOverlay, "glutHideOverlay");
            bindFunc(cast(void**)&glutCreateMenu, "glutCreateMenu");
            bindFunc(cast(void**)&glutDestroyMenu, "glutDestroyMenu");
            bindFunc(cast(void**)&glutGetMenu, "glutGetMenu");
            bindFunc(cast(void**)&glutSetMenu, "glutSetMenu");
            bindFunc(cast(void**)&glutAddMenuEntry, "glutAddMenuEntry");
            bindFunc(cast(void**)&glutAddSubMenu, "glutAddSubMenu");
            bindFunc(cast(void**)&glutChangeToMenuEntry, "glutChangeToMenuEntry");
            bindFunc(cast(void**)&glutChangeToSubMenu, "glutChangeToSubMenu");
            bindFunc(cast(void**)&glutRemoveMenuItem, "glutRemoveMenuItem");
            bindFunc(cast(void**)&glutAttachMenu, "glutAttachMenu");
            bindFunc(cast(void**)&glutDetachMenu, "glutDetachMenu");
            bindFunc(cast(void**)&glutTimerFunc, "glutTimerFunc");
            bindFunc(cast(void**)&glutIdleFunc, "glutIdleFunc");
            bindFunc(cast(void**)&glutKeyboardFunc, "glutKeyboardFunc");
            bindFunc(cast(void**)&glutSpecialFunc, "glutSpecialFunc");
            bindFunc(cast(void**)&glutReshapeFunc, "glutReshapeFunc");
            bindFunc(cast(void**)&glutVisibilityFunc, "glutVisibilityFunc");
            bindFunc(cast(void**)&glutDisplayFunc, "glutDisplayFunc");
            bindFunc(cast(void**)&glutMouseFunc, "glutMouseFunc");
            bindFunc(cast(void**)&glutMotionFunc, "glutMotionFunc");
            bindFunc(cast(void**)&glutPassiveMotionFunc, "glutPassiveMotionFunc");
            bindFunc(cast(void**)&glutEntryFunc, "glutEntryFunc");
            bindFunc(cast(void**)&glutKeyboardUpFunc, "glutKeyboardUpFunc");
            bindFunc(cast(void**)&glutSpecialUpFunc, "glutSpecialUpFunc");
            bindFunc(cast(void**)&glutJoystickFunc, "glutJoystickFunc");
            bindFunc(cast(void**)&glutMenuStateFunc, "glutMenuStateFunc");
            bindFunc(cast(void**)&glutMenuStatusFunc, "glutMenuStatusFunc");
            bindFunc(cast(void**)&glutOverlayDisplayFunc, "glutOverlayDisplayFunc");
            bindFunc(cast(void**)&glutWindowStatusFunc, "glutWindowStatusFunc");
            bindFunc(cast(void**)&glutSpaceballMotionFunc, "glutSpaceballMotionFunc");
            bindFunc(cast(void**)&glutSpaceballRotateFunc, "glutSpaceballRotateFunc");
            bindFunc(cast(void**)&glutSpaceballButtonFunc, "glutSpaceballButtonFunc");
            bindFunc(cast(void**)&glutButtonBoxFunc, "glutButtonBoxFunc");
            bindFunc(cast(void**)&glutDialsFunc, "glutDialsFunc");
            bindFunc(cast(void**)&glutTabletMotionFunc, "glutTabletMotionFunc");
            bindFunc(cast(void**)&glutTabletButtonFunc, "glutTabletButtonFunc");
            bindFunc(cast(void**)&glutGet, "glutGet");
            bindFunc(cast(void**)&glutDeviceGet, "glutDeviceGet");
            bindFunc(cast(void**)&glutGetModifiers, "glutGetModifiers");
            bindFunc(cast(void**)&glutLayerGet, "glutLayerGet");
            bindFunc(cast(void**)&glutBitmapCharacter, "glutBitmapCharacter");
            bindFunc(cast(void**)&glutBitmapWidth, "glutBitmapWidth");
            bindFunc(cast(void**)&glutStrokeCharacter, "glutStrokeCharacter");
            bindFunc(cast(void**)&glutStrokeWidth, "glutStrokeWidth");
            bindFunc(cast(void**)&glutBitmapLength, "glutBitmapLength");
            bindFunc(cast(void**)&glutStrokeLength, "glutStrokeLength");
            bindFunc(cast(void**)&glutWireCube, "glutWireCube");
            bindFunc(cast(void**)&glutSolidCube, "glutSolidCube");
            bindFunc(cast(void**)&glutWireSphere, "glutWireSphere");
            bindFunc(cast(void**)&glutSolidSphere, "glutSolidSphere");
            bindFunc(cast(void**)&glutWireCone, "glutWireCone");
            bindFunc(cast(void**)&glutSolidCone, "glutSolidCone");
            bindFunc(cast(void**)&glutWireTorus, "glutWireTorus");
            bindFunc(cast(void**)&glutSolidTorus, "glutSolidTorus");
            bindFunc(cast(void**)&glutWireDodecahedron, "glutWireDodecahedron");
            bindFunc(cast(void**)&glutSolidDodecahedron, "glutSolidDodecahedron");
            bindFunc(cast(void**)&glutSolidDodecahedron, "glutSolidDodecahedron");
            bindFunc(cast(void**)&glutWireOctahedron, "glutWireOctahedron");
            bindFunc(cast(void**)&glutSolidOctahedron, "glutSolidOctahedron");
            bindFunc(cast(void**)&glutWireTetrahedron, "glutWireTetrahedron");
            bindFunc(cast(void**)&glutSolidTetrahedron, "glutSolidTetrahedron");
            bindFunc(cast(void**)&glutWireIcosahedron, "glutWireIcosahedron");
            bindFunc(cast(void**)&glutSolidIcosahedron, "glutSolidIcosahedron");
            bindFunc(cast(void**)&glutWireTeapot, "glutWireTeapot");
            bindFunc(cast(void**)&glutSolidTeapot, "glutSolidTeapot");
            bindFunc(cast(void**)&glutGameModeString, "glutGameModeString");
            bindFunc(cast(void**)&glutEnterGameMode, "glutEnterGameMode");
            bindFunc(cast(void**)&glutLeaveGameMode, "glutLeaveGameMode");
            bindFunc(cast(void**)&glutGameModeGet, "glutGameModeGet");
            bindFunc(cast(void**)&glutVideoResizeGet, "glutVideoResizeGet");
            bindFunc(cast(void**)&glutSetupVideoResizing, "glutSetupVideoResizing");
            bindFunc(cast(void**)&glutStopVideoResizing, "glutStopVideoResizing");
            bindFunc(cast(void**)&glutVideoPan, "glutVideoPan");
            bindFunc(cast(void**)&glutSetColor, "glutSetColor");
            bindFunc(cast(void**)&glutGetColor, "glutGetColor");
            bindFunc(cast(void**)&glutCopyColormap, "glutCopyColormap");
            bindFunc(cast(void**)&glutIgnoreKeyRepeat, "glutIgnoreKeyRepeat");
            bindFunc(cast(void**)&glutSetKeyRepeat, "glutSetKeyRepeat");
            bindFunc(cast(void**)&glutForceJoystickFunc, "glutForceJoystickFunc");
            bindFunc(cast(void**)&glutExtensionSupported, "glutExtensionSupported");
            bindFunc(cast(void**)&glutReportErrors, "glutReportErrors");
            bindFunc(cast(void**)&glutMainLoopEvent, "glutMainLoopEvent");
            bindFunc(cast(void**)&glutLeaveMainLoop, "glutLeaveMainLoop");
            bindFunc(cast(void**)&glutExit, "glutExit");
            bindFunc(cast(void**)&glutFullScreenToggle, "glutFullScreenToggle");
            bindFunc(cast(void**)&glutLeaveFullScreen, "glutLeaveFullScreen");
            bindFunc(cast(void**)&glutMouseWheelFunc, "glutMouseWheelFunc");
            bindFunc(cast(void**)&glutCloseFunc, "glutCloseFunc");
            bindFunc(cast(void**)&glutWMCloseFunc, "glutWMCloseFunc");
            bindFunc(cast(void**)&glutMenuDestroyFunc, "glutMenuDestroyFunc");
            bindFunc(cast(void**)&glutSetOption, "glutSetOption");
            bindFunc(cast(void**)&glutGetModeValues, "glutGetModeValues");
            bindFunc(cast(void**)&glutGetWindowData, "glutGetWindowData");
            bindFunc(cast(void**)&glutSetWindowData, "glutSetWindowData");
            bindFunc(cast(void**)&glutGetMenuData, "glutGetMenuData");
            bindFunc(cast(void**)&glutSetMenuData, "glutSetMenuData");
            bindFunc(cast(void**)&glutBitmapHeight, "glutBitmapHeight");
            bindFunc(cast(void**)&glutStrokeHeight, "glutStrokeHeight");
            bindFunc(cast(void**)&glutBitmapString, "glutBitmapString");
            bindFunc(cast(void**)&glutStrokeString, "glutStrokeString");
            bindFunc(cast(void**)&glutWireRhombicDodecahedron, "glutWireRhombicDodecahedron");
            bindFunc(cast(void**)&glutSolidRhombicDodecahedron, "glutSolidRhombicDodecahedron");
            bindFunc(cast(void**)&glutWireSierpinskiSponge, "glutWireSierpinskiSponge");
            bindFunc(cast(void**)&glutSolidSierpinskiSponge, "glutSolidSierpinskiSponge");
            bindFunc(cast(void**)&glutWireCylinder, "glutWireCylinder");
            bindFunc(cast(void**)&glutSolidCylinder, "glutSolidCylinder");
            bindFunc(cast(void**)&glutGetProcAddress, "glutGetProcAddress");
            bindFunc(cast(void**)&glutMultiEntryFunc, "glutMultiEntryFunc");
            bindFunc(cast(void**)&glutMultiButtonFunc, "glutMultiButtonFunc");
            bindFunc(cast(void**)&glutMultiMotionFunc, "glutMultiMotionFunc");
            bindFunc(cast(void**)&glutMultiPassiveFunc, "glutMultiPassiveFunc");
            bindFunc(cast(void**)&glutInitContextVersion, "glutInitContextVersion");
            bindFunc(cast(void**)&glutInitContextFlags, "glutInitContextFlags");
            bindFunc(cast(void**)&glutInitContextProfile, "glutInitContextProfile");
            bindFunc(cast(void**)&glutInitErrorFunc, "glutInitErrorFunc");
            bindFunc(cast(void**)&glutInitWarningFunc, "glutInitWarningFunc");
        }
    }

    public
    {
        this()
        {
            super(libNames);
        }
    }
}

__gshared DerelictFreeGLUTLoader DerelictFreeGLUT;

shared static this()
{
    DerelictFreeGLUT = new DerelictFreeGLUTLoader();
}

shared static ~this()
{
    DerelictFreeGLUT.unload();
}