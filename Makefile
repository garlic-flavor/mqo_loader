## MACRO
TARGET = sample.exe
DC = dmd
MAKE = make
MAKEFILE = Makefile
TO_COMPILE = src\sworks\compo\sdl\port.d src\sworks\mqo\parser.d src\sworks\compo\util\dregex.d src\sworks\compo\gl\util.d src\sworks\mqo\mikoto_motion.d src\sworks\compo\sdl\gl.d src\sworks\mqo\mqo.d src\sworks\mqo\mks.d src\sworks\compo\gl\port.d src\sworks\compo\util\cached_buffer.d src\sworks\mqo\bone_system.d src\sworks\compo\gl\glsl.d src\sworks\compo\util\strutil.d src\sworks\compo\gl\texture_2drgba32.d src\sworks\sample\sample.d src\sworks\compo\util\matrix.d src\sworks\mqo\mikoto.d src\sworks\compo\util\sequential_file.d src\sworks\mqo\misc.d src\sworks\compo\sdl\image.d src\sworks\compo\util\class_switch.d src\sworks\compo\sdl\iconv.d src\sworks\compo\sdl\util.d src\sworks\compo\util\dump_members.d src\sworks\mqo\mkm.d src\sworks\mqo\mikoto_model.d
TO_LINK = src\sworks\compo\sdl\port.obj src\sworks\mqo\parser.obj src\sworks\compo\util\dregex.obj src\sworks\compo\gl\util.obj src\sworks\mqo\mikoto_motion.obj src\sworks\compo\sdl\gl.obj src\sworks\mqo\mqo.obj src\sworks\mqo\mks.obj src\sworks\compo\gl\port.obj src\sworks\compo\util\cached_buffer.obj src\sworks\mqo\bone_system.obj src\sworks\compo\gl\glsl.obj src\sworks\compo\util\strutil.obj src\sworks\compo\gl\texture_2drgba32.obj src\sworks\sample\sample.obj src\sworks\compo\util\matrix.obj src\sworks\mqo\mikoto.obj src\sworks\compo\util\sequential_file.obj src\sworks\mqo\misc.obj src\sworks\compo\sdl\image.obj src\sworks\compo\util\class_switch.obj src\sworks\compo\sdl\iconv.obj src\sworks\compo\sdl\util.obj src\sworks\compo\util\dump_members.obj src\sworks\mqo\mkm.obj src\sworks\mqo\mikoto_model.obj
COMPILE_FLAG = -Isrc;import
LINK_FLAG =
EXT_LIB = lib\DerelictGL3.lib lib\DerelictSDL2.lib lib\DerelictUtil.lib lib\msvcrt.lib
DDOC_FILE = doc\main.ddoc
FLAG =

## LINK COMMAND
$(TARGET) : $(TO_LINK) $(EXT_LIB)
	$(DC) -g $(LINK_FLAG) $(FLAG) $(EXT_LIB) -of$@ $**

## COMPILE RULE
.d.obj :
	$(DC) -c -g -op -debug $(COMPILE_FLAG) $(FLAG) $<

## DEPENDENCE
$(TO_LINK) : $(MAKEFILE) $(EXT_LIB)
src\sworks\compo\sdl\port.obj : src\sworks\compo\sdl\port.d
src\sworks\mqo\parser.obj : src\sworks\mqo\parser.d
src\sworks\compo\util\dregex.obj : src\sworks\compo\util\dregex.d
src\sworks\compo\gl\util.obj : src\sworks\compo\gl\port.d src\sworks\compo\gl\util.d
src\sworks\mqo\mikoto_motion.obj : src\sworks\mqo\mikoto_motion.d
src\sworks\compo\sdl\gl.obj : src\sworks\compo\sdl\gl.d src\sworks\compo\gl\texture_2drgba32.d src\sworks\compo\gl\util.d src\sworks\compo\gl\glsl.d src\sworks\compo\sdl\util.d src\sworks\compo\sdl\image.d
src\sworks\mqo\mqo.obj : src\sworks\compo\util\matrix.d src\sworks\mqo\misc.d src\sworks\mqo\mqo.d
src\sworks\mqo\mks.obj : src\sworks\mqo\mks.d
src\sworks\compo\gl\port.obj : src\sworks\compo\gl\port.d
src\sworks\compo\util\cached_buffer.obj : src\sworks\compo\util\cached_buffer.d
src\sworks\mqo\bone_system.obj : src\sworks\mqo\bone_system.d
src\sworks\compo\gl\glsl.obj : src\sworks\compo\gl\glsl.d
src\sworks\compo\util\strutil.obj : src\sworks\compo\util\strutil.d
src\sworks\compo\gl\texture_2drgba32.obj : src\sworks\compo\gl\texture_2drgba32.d
src\sworks\sample\sample.obj : src\sworks\sample\sample.d
src\sworks\compo\util\matrix.obj : src\sworks\compo\util\matrix.d
src\sworks\mqo\mikoto.obj : src\sworks\mqo\misc.d src\sworks\mqo\mks.d src\sworks\mqo\mikoto_model.d src\sworks\mqo\bone_system.d src\sworks\mqo\mikoto_motion.d src\sworks\mqo\mikoto.d src\sworks\mqo\mqo.d src\sworks\mqo\mkm.d
src\sworks\compo\util\sequential_file.obj : src\sworks\compo\util\sequential_file.d
src\sworks\mqo\misc.obj : src\sworks\mqo\misc.d src\sworks\compo\util\matrix.d src\sworks\compo\util\strutil.d
src\sworks\compo\sdl\image.obj : src\sworks\compo\sdl\util.d src\sworks\compo\sdl\image.d
src\sworks\compo\util\class_switch.obj : src\sworks\compo\util\class_switch.d
src\sworks\compo\sdl\iconv.obj : src\sworks\compo\sdl\iconv.d src\sworks\compo\sdl\util.d
src\sworks\compo\sdl\util.obj : src\sworks\compo\sdl\port.d src\sworks\compo\sdl\util.d
src\sworks\compo\util\dump_members.obj : src\sworks\compo\util\dump_members.d
src\sworks\mqo\mkm.obj : src\sworks\mqo\misc.d src\sworks\mqo\mkm.d
src\sworks\mqo\mikoto_model.obj : src\sworks\mqo\mikoto_model.d

## PHONY TARGET
debug-all :
	$(DC) -g -debug -of$(TARGET) $(COMPILE_FLAG) $(LINK_FLAG) $(TO_COMPILE) $(EXT_LIB)  $(FLAG)
release :
	$(DC) -release -O -inline -of$(TARGET) $(COMPILE_FLAG) $(LINK_FLAG) $(TO_COMPILE) $(EXT_LIB)  $(FLAG)
run :
	$(TARGET) $(FLAG)
clean :
	del $(TARGET) $(TO_LINK)
clean_obj :
	del $(TO_LINK)
vwrite :
	vwrite -ver="0.0014(dmd2.062)" -prj=$(TARGET) -target=$(TARGET) $(TO_COMPILE)
ddoc :
	$(DC) -c -o- -op -D -Dddoc $(COMPILE_FLAG) $(DDOC_FILE) $(TO_COMPILE) $(FLAG)
show :
	@echo ROOT = src\sworks\sample\sample.d
	@echo TARGET = $(TARGET)
	@echo COMPILE FLAGS = $(COMPILE_FLAG)
	@echo LINK FLAGS = $(LINK_FLAG)
	@echo VERSION = 0.0014(dmd2.062)
edit :
	emacs $(TO_COMPILE)
remake :
	amm v=0.0014(dmd2.062) .\doc\main.ddoc .\src\sworks\sample\sample.d $(FLAG)

debug :
	ddbg $(TARGET)

## generated by amm.