/** \file mki.d Mikoto Intermediate ファイルを読み込みます。
 */
module sworks.mqo.mki;

import std.ascii, std.conv, std.exception, std.range, std.string, std.regex;
import sworks.compo.util.matrix;
import sworks.mqo.parser;

/*############################################################################*\
|*#                                 Classes                                  #*|
\*############################################################################*/
/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                              MKIntermediate                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
///
class MKIntermediate
{
	string version_string;

	CharacterChunk[string] character;
}


/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                              CharacterChunk                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class CharacterChunk
{
	string name;
	string coordinate;
	SkeltonChunk[string] skelton;
	PolygonChunk[string] polygon;

	string getName() const @property { return name; }
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               SkeltonChunk                               |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class SkeltonChunk
{
	string name;
	LocateChunk[string] locate;
	BoneChunk[string] bone;

	string getName() const @property { return name; }
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               LocateChunk                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class LocateChunk
{
	string name;
	Vector3f spos;
	string getName() const @property { return name; }
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                BoneChunk                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class BoneChunk
{
	string name;
	Quaternionf srot;
	string start;
	string end;
	string getName() const @property { return name; }
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               PolygonChunk                               |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class PolygonChunk
{
	string name;
	string coordinate;
	PolygonChunk[string] polygon;
	SphericalDeform[string] sphericaldeform;

	string getName() const @property { return name; }
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                             SphericalDeform                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class SphericalDeform
{
	string name;
	string getName() const @property { return name; }
}



/*############################################################################*\
|*#                                Functions                                 #*|
\*############################################################################*/

//==============================================================================
//
private FileCell mki_check_validation( string filebody )
{
	auto m = match( filebody, regex( `Mikoto Intermediate Ver\s+(\d[\.\d]?)$`, "im" ) );
	enforce( !m.empty, "Invalid Mikoto Intermediate file." );
	auto c = m.captures;
	c.popFront;
	enforce( !c.empty, "couldn't detect an version string of Mikoto Intermediate file." );
	return new FileCell( filebody, filebody[ 0 .. cast(size_t)c.front.ptr - cast(size_t)filebody.ptr ]
	                   , c.front, m.post );
}

private FileCell loadMKICell(CONVERTER)( string filebody, CONVERTER sjis2utf8 )
{
	auto cell = mki_check_validation( filebody );
	cell.parse( sjis2utf8 );
	return cell;
}


//==============================================================================
//
MKIntermediate loadMKIntermediate(CONVERTER)( string filebody, CONVERTER sjis2utf8 )
{
	auto filecell = loadMKICell( filebody, sjis2utf8 );
	MKIntermediate mki;
	auto cell = cast(CellObject)filecell;
	cell.chomp( mki );
	return mki;
}
