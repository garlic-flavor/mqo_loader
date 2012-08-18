## MACRO
TARGET = ctmqo.exe
MAKE = make
MAKEFILE = Makefile
TO_COMPILE = src\sworks\mqo\parser_core.d src\sworks\compo\sdl\port.d src\sworks\mqo\parser.d sample.d src\sworks\compo\gl\util.d src\sworks\mqo\mikoto_motion.d src\sworks\compo\sdl\gl.d src\sworks\mqo\mqo.d src\sworks\mqo\mks.d src\sworks\compo\gl\port.d src\sworks\mqo\bone_system.d src\sworks\compo\gl\glsl.d src\sworks\compo\gl\texture_2drgba32.d src\sworks\compo\util\matrix.d src\sworks\mqo\mikoto.d src\sworks\mqo\misc.d src\sworks\compo\sdl\image.d src\sworks\compo\sdl\iconv.d src\sworks\compo\sdl\util.d src\sworks\compo\util\dump_members.d src\sworks\mqo\mkm.d src\sworks\mqo\mikoto_model.d
TO_LINK = src\sworks\mqo\parser_core.obj src\sworks\compo\sdl\port.obj src\sworks\mqo\parser.obj sample.obj src\sworks\compo\gl\util.obj src\sworks\mqo\mikoto_motion.obj src\sworks\compo\sdl\gl.obj src\sworks\mqo\mqo.obj src\sworks\mqo\mks.obj src\sworks\compo\gl\port.obj src\sworks\mqo\bone_system.obj src\sworks\compo\gl\glsl.obj src\sworks\compo\gl\texture_2drgba32.obj src\sworks\compo\util\matrix.obj src\sworks\mqo\mikoto.obj src\sworks\mqo\misc.obj src\sworks\compo\sdl\image.obj src\sworks\compo\sdl\iconv.obj src\sworks\compo\sdl\util.obj src\sworks\compo\util\dump_members.obj src\sworks\mqo\mkm.obj src\sworks\mqo\mikoto_model.obj
COMPILE_FLAG = -Isrc;import
LINK_FLAG =
EXT_LIB = lib\DerelictGL3.lib lib\DerelictSDL2.lib lib\DerelictUtil.lib
DDOC_FILE = doc\main.ddoc
FLAG =

## LINK COMMAND
$(TARGET) : $(TO_LINK) $(EXT_LIB)
	dmd -g $(LINK_FLAG) $(FLAG) -of$@ $**

## COMPILE RULE
.d.obj :
	dmd -c -g -op -debug $(COMPILE_FLAG) $(FLAG) $<

## DEPENDENCE
$(TO_LINK) : $(MAKEFILE) $(EXT_LIB)
src\sworks\mqo\parser_core.obj : src\sworks\mqo\misc.d src\sworks\compo\util\matrix.d src\sworks\mqo\parser_core.d
src\sworks\compo\sdl\port.obj : src\sworks\compo\sdl\port.d
src\sworks\mqo\parser.obj : src\sworks\mqo\misc.d src\sworks\compo\util\matrix.d src\sworks\compo\util\dump_members.d src\sworks\mqo\parser.d src\sworks\mqo\parser_core.d
sample.obj : src\sworks\mqo\parser_core.d src\sworks\compo\sdl\port.d src\sworks\mqo\parser.d sample.d src\sworks\compo\gl\util.d src\sworks\mqo\mikoto_motion.d src\sworks\compo\sdl\gl.d src\sworks\mqo\mqo.d src\sworks\mqo\mks.d src\sworks\compo\gl\port.d src\sworks\compo\gl\glsl.d src\sworks\mqo\bone_system.d src\sworks\compo\gl\texture_2drgba32.d src\sworks\compo\util\matrix.d src\sworks\mqo\mikoto.d src\sworks\mqo\misc.d src\sworks\compo\sdl\image.d src\sworks\compo\sdl\iconv.d src\sworks\compo\sdl\util.d src\sworks\compo\util\dump_members.d src\sworks\mqo\mkm.d src\sworks\mqo\mikoto_model.d
src\sworks\compo\gl\util.obj : src\sworks\compo\gl\port.d src\sworks\compo\gl\util.d
src\sworks\mqo\mikoto_motion.obj : src\sworks\compo\util\matrix.d src\sworks\mqo\misc.d src\sworks\mqo\mikoto_model.d src\sworks\compo\util\dump_members.d src\sworks\mqo\mikoto_motion.d src\sworks\mqo\bone_system.d src\sworks\mqo\mkm.d src\sworks\mqo\parser_core.d src\sworks\mqo\mqo.d
src\sworks\compo\sdl\gl.obj : src\sworks\compo\sdl\gl.d src\sworks\compo\gl\port.d src\sworks\compo\gl\texture_2drgba32.d src\sworks\compo\sdl\port.d src\sworks\compo\gl\util.d src\sworks\compo\gl\glsl.d src\sworks\compo\sdl\util.d src\sworks\compo\sdl\image.d
src\sworks\mqo\mqo.obj : src\sworks\compo\util\matrix.d src\sworks\mqo\misc.d src\sworks\mqo\mqo.d src\sworks\mqo\parser_core.d
src\sworks\mqo\mks.obj : src\sworks\compo\util\matrix.d src\sworks\mqo\misc.d src\sworks\mqo\mks.d src\sworks\mqo\parser_core.d src\sworks\mqo\mqo.d src\sworks\mqo\mkm.d
src\sworks\compo\gl\port.obj : src\sworks\compo\gl\port.d
src\sworks\mqo\bone_system.obj : src\sworks\compo\util\matrix.d src\sworks\mqo\misc.d src\sworks\mqo\mikoto_model.d src\sworks\compo\util\dump_members.d src\sworks\mqo\bone_system.d src\sworks\mqo\mqo.d src\sworks\mqo\parser_core.d
src\sworks\compo\gl\glsl.obj : src\sworks\compo\gl\port.d src\sworks\compo\gl\glsl.d src\sworks\compo\gl\util.d
src\sworks\compo\gl\texture_2drgba32.obj : src\sworks\compo\gl\texture_2drgba32.d src\sworks\compo\gl\port.d
src\sworks\compo\util\matrix.obj : src\sworks\compo\util\matrix.d
src\sworks\mqo\mikoto.obj : src\sworks\compo\util\matrix.d src\sworks\mqo\misc.d src\sworks\compo\util\dump_members.d src\sworks\mqo\mks.d src\sworks\mqo\mikoto_model.d src\sworks\mqo\bone_system.d src\sworks\mqo\mikoto_motion.d src\sworks\mqo\mikoto.d src\sworks\mqo\parser_core.d src\sworks\mqo\parser.d src\sworks\mqo\mqo.d src\sworks\mqo\mkm.d
src\sworks\mqo\misc.obj : src\sworks\mqo\misc.d src\sworks\compo\util\matrix.d
src\sworks\compo\sdl\image.obj : src\sworks\compo\sdl\port.d src\sworks\compo\sdl\util.d src\sworks\compo\sdl\image.d
src\sworks\compo\sdl\iconv.obj : src\sworks\compo\sdl\iconv.d src\sworks\compo\sdl\port.d src\sworks\compo\sdl\util.d
src\sworks\compo\sdl\util.obj : src\sworks\compo\sdl\port.d src\sworks\compo\sdl\util.d
src\sworks\compo\util\dump_members.obj : src\sworks\compo\util\dump_members.d
src\sworks\mqo\mkm.obj : src\sworks\mqo\misc.d src\sworks\compo\util\matrix.d src\sworks\mqo\mkm.d src\sworks\mqo\parser_core.d
src\sworks\mqo\mikoto_model.obj : src\sworks\mqo\misc.d src\sworks\compo\util\matrix.d src\sworks\mqo\mikoto_model.d src\sworks\mqo\mqo.d src\sworks\mqo\parser_core.d

## PHONY TARGET
debug-all :
	dmd -g -debug -of$(TARGET) $(COMPILE_FLAG) $(LINK_FLAG) $(TO_COMPILE) $(EXT_LIB)  $(FLAG)
release :
	dmd -release -O -inline -of$(TARGET) $(COMPILE_FLAG) $(LINK_FLAG) $(TO_COMPILE) $(EXT_LIB)  $(FLAG)
clean :
	del $(TARGET) $(TO_LINK)
clean_obj :
	del $(TO_LINK)
vwrite :
	vwrite -ver="0.0013(dmd2.060)" -prj=$(TARGET) $(TO_COMPILE)
ddoc :
	dmd -c -o- -op -D -Dddoc $(COMPILE_FLAG) $(DDOC_FILE) $(TO_COMPILE) $(FLAG)
show :
	@echo ROOT = sample.d
	@echo TARGET = $(TARGET)
	@echo VERSION = 0.0013(dmd2.060)
run :
	$(TARGET) $(FLAG)
edit :
	emacs $(TO_COMPILE)  Makefile
remake :
	amm vwrite=0.0013(dmd2.060) .\sample.d doc\main.ddoc $(FLAG)

debug :
	ddbg $(TARGET)

## generated by amm.