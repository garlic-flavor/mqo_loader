
function setHeight()
{
	var h = $(window).innerHeight() - $(".main").position().top - $(".footer").outerHeight();
	$(".main").outerHeight( h );
	$(".left-pain").outerHeight( h );
	$(".left-pain > ul").outerHeight( $(".left-pain").innerHeight() - $(".module-item").outerHeight() );
}

function urlToModName( url )
{
	return url.replace( /\.\/|src\/|\.html|\.d/g, "" );
}

function modNameToIDName( modname )
{
	return "module-list-" + (modname.replace( /\//g, "_" ));
}

function urlToIDName( url )
{
	return modNameToIDName( urlToModName(url) );
}

function entryModule( path )
{
	var modname = urlToModName( path );
	$("<li id='" + modNameToIDName(modname) + "' ><span class='module-item' onclick='loadToMain( \"" + path + "\");' >" + modname + "</span></li>").appendTo( $(".module-list" ) );
}
function getLI( dt )
{
	var cont = $(dt).find( ".psymbol:first" ).text();
	if( 0 == cont.length ) return null;
	var span = $( "<span class='module-item'>" + cont  + "</span>" );
	span.click( function()
	{
		$(".main").scrollTop(0);
		$(".main").scrollTop( $(dt).position().top - $(".main").position().top );
	} );
	var li = $( "<li>" );
	span.appendTo(li);
	return li;
}

function appendToList( list, dl )
{
	var li;
	$(dl).children().each( function( i, e )
	{
		if( 0 == i%2 ) li = getLI( e )
		else
		{
			if( null == li ) return;
			if( 0 < $(e).children( "dl" ).length )
			{
				var ul = $( "<ul class='member-list'>" );
				$(e).children( "dl" ).each( function( i, ndl ){ appendToList( ul, ndl ); } );
				ul.appendTo( li );
			}
			li.appendTo( list );
		}
	} );

	setHeight();
}

function loadToMain( url )
{
	var listid = urlToIDName( url );
	$(".member-list").remove();
	$(".main").load( url, function()
	{
		$(".main").scrollTop(0);
		var ul = $("<ul class='member-list'>");
		appendToList( ul, $(".main > .module-members-sec:first") );
		ul.appendTo($("#"+listid ) );
	});
}

$(document).ready( function()
{
	$(".left-pain").resizable();
	init();
	setHeight();
} );



$(window).resize( function()
{
	setHeight();
});

