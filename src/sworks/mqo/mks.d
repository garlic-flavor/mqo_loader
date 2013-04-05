/** Mikoto Scene ファイルを読み込む。
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.mks;

import std.ascii, std.file, std.path;
import sworks.compo.util.matrix;
import sworks.mqo.parser;
import sworks.mqo.mqo;
import sworks.mqo.mkm;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 MKScene                                  |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// .mks ファイルの最外側
class MKScene
{
	/// .mks ファイルのヘッダにヒットする。
	enum HEADER = `^Mikoto\s+Scene\s+Ver\s+(\d(?:\.\d)?)[\r\n]+`;
//	enum HEADER = `Mikoto Scene Ver`;
	string version_string; /// 現状では "1"

	CharacterChunk[jstring] character; ///

	string current; /// なにこれ？

	/**
	 * mks ファイルから mqo オブジェクトを探す。
	 */
	CharacterChunk getCharacterChunk( string name, string delegate(jstring) toUTF8 )
	{
		CharacterChunk search( CharacterChunk[jstring] c )
		{
			foreach( jkey, one ; c ) if( toUTF8( jkey ) == name ) return one;
			CharacterChunk ret;
			foreach( one ; c )
			{
				if( null !is ( ret = search( one.character ) ) ) return ret;
			}
			return null;
		}

		return search( character );
	}

	/**
	 * mks ファイル内で最初の import を持つ Character チャンクを持つ。
	 */
	CharacterChunk firstImportableCharacterChunk()
	{
		CharacterChunk search( CharacterChunk c )
		{
			if( 0 < c.import_data.length ) return c;
			CharacterChunk cc;
			foreach( one ; c.character ) if( null !is ( cc = search( one ) ) ) return cc;
			return null;
		}
		CharacterChunk cc;
		foreach( one ; character ) if( null !is ( cc = search( one ) ) ) return cc;
		return null;
	}


	/**
	 * 
	 */
	MotionChunk getMotionChunk( string name, string delegate(jstring) toUTF8 )
	{
		MotionChunk search_each( CharacterChunk[jstring] cs )
		{
			MotionChunk search( CharacterChunk c )
			{
				MotionChunk search_each_m( MotionChunk[jstring] ms )
				{
					foreach( jkey, one ; ms ) if( toUTF8( jkey ) == name ) return one;
					MotionChunk hit;
					foreach( m ; ms )
					{
						if( null !is ( hit = search_each_m( m.motion ) ) ) return hit;
					}
					return null;
				}
				MotionChunk hit;
				if( null !is ( hit = search_each_m( c.motion ) ) ) return hit;
				return search_each( c.character );
			}
			MotionChunk hit;
			foreach( one ; cs )
			{
				if( null !is ( hit = search(one) ) ) return hit;
			}
			return null;
		}

		return search_each( character );
	}

}

class CharacterChunk : INamed
{
	jstring name_data;
	jstring name() @property const { return name_data; }

	jstring fileName;
	int readOnly;
	SkeltonChunk[jstring] skelton;
	CharacterChunk[jstring] character;
	MotionChunk[jstring] motion;
	string coordinate;
	jstring import_data;
	int ro;
}

class SkeltonChunk : INamed
{
	jstring name_data;
	jstring name() @property const { return name_data; }
	CoordinateChunk[jstring] coordinate;
}

class CoordinateChunk : INamed
{
	jstring name_data;
	jstring name() @property const { return name_data; }
	Vector3f spos;
	Vector3f pos;
	Quaternionf srot;
	Quaternionf rot;
}

////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(mks):
import std.stdio;
import sworks.mqo.parser;
import sworks.compo.util.dump_members;

void main()
{
//	auto cc = new CellObject( new CoreCell( new CachedFile( "dsan\\DさんMove.mks" ), &toUTF8 ) );
	auto scene = load!MKScene( "dsan\\DさんMove.mks" );
/*
	auto cf = new CachedFile( "dsan\\DさんMove.mks" );
	for( size_t i = 0 ; i < 100 ; i++ )
	{
		writeln( cast(char)cf.peep );
		cf.discard;
	}
*/
	writeln( scene.dump_members );
}
