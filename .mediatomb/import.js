// Default MediaTomb import script.
// see MediaTomb scripting documentation for more information

/*MT_F*
    
    MediaTomb - http://www.mediatomb.cc/
    
    import.js - this file is part of MediaTomb.
    
    Copyright (C) 2006-2009 Gena Batyan <bgeradz@mediatomb.cc>,
                            Sergey 'Jin' Bostandzhyan <jin@mediatomb.cc>,
                            Leonhard Wimmer <leo@mediatomb.cc>
    
    This file is free software; the copyright owners give unlimited permission
    to copy and/or redistribute it; with or without modifications, as long as
    this notice is preserved.
    
    This file is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    
    $Id: import.js 2010 2009-01-11 19:10:43Z lww $
*/

function splitFeaturing(artist) {

	var feat = ' feat. ';

	index = artist.toLowerCase().indexOf(feat);

	if( index < 0 ) {
		feat = ' featuring ';
		index = artist.toLowerCase().indexOf(feat);
	}

	if( index > 0 )
		return [artist.substring(0,index), artist.substring(index+feat.length)];
	else 
		return [artist];
}    

function removeFeaturing(artist) {
	return splitFeaturing(artist)[0];
}

function getFeaturing(artist) {
	artist = splitFeaturing(artist);
	if( artist.length < 2 )
		return null;

	return artist[1];
}

function canonicalizeArtist(artist) {
	return reorderThe(splitFeaturing(replaceAmpersand(fixCase(artist)))[0]);
}

function canonicalizeAlbum(album) {
	return reorderThe(replaceAmpersand(fixCase(album)));
}

function canonicalizeTitle(title) {
	return replaceAmpersand(fixCase(title));
}

function canonicalizeTrackNumber(trackno, disc) {

	if( !trackno )
		return '';

	if (trackno.length == 1)
		trackno = '0' + trackno;

	trackno = trackno + ' ';
	//discno = discno.split('/')[0];

	return trackno;
}

function canonicalizeGenre(genre) {
	
	if( !genre )
		return '';

	// Replace ' - ' with '/'
	genre = genre.replace(' - ', '/');

	var parts = genre.split('/');
	for( i in parts )
		parts[i] = trim(parts[i]);

	return parts.join(' / ');
}

function addAudio(obj) {
 
	var desc = '';
	var artist_full;
	var album_full;
	var chain;

	if( obj.location.indexOf('/Photos') >= 0 )
		return;

	if( obj.location.indexOf('/Videos') >= 0 )
		return;
	
    // first gather data
	var title = canonicalizeTitle(obj.meta[M_TITLE]);
	if (!title) 
		title = canonicalizeTitle(obj.title);
	
	var artist = canonicalizeArtist(obj.meta[M_ARTIST]);
	if (!artist) {
		artist = 'Unknown';
		artist_full = null;
	} else {
		artist_full = artist;
		desc = artist;
	}
	
	var album = canonicalizeAlbum(obj.meta[M_ALBUM]);
	if (!album) {
		album = 'Unknown';
		album_full = null;
	} else {
		desc = desc + ', ' + album;
		album_full = album;
	}
	
	if (desc)
		desc = desc + ', ';
	desc = desc + title;
    

	var date = obj.meta[M_DATE];
	var decade;
	if (!date) {
		date = 'Unknown';
		decade = null;
	} else {
		date = getYear(date);
		decade = date.substring(0,3) + '0 - ' + String(10 * (parseInt(date.substring(0,3))) + 9);
		desc = desc + ', ' + date;
	}
	
	var genre = canonicalizeGenre(obj.meta[M_GENRE]);
	if (!genre) {
		genre = 'Unknown';
	} else {
		desc = desc + ', ' + genre;
	}
    
	var description = obj.meta[M_DESCRIPTION];
	if (!description) {
		obj.meta[M_DESCRIPTION] = desc;
	}

	// Track
	var track = canonicalizeTrackNumber(obj.meta[M_TRACKNUMBER], obj.aux['TPOS']);
	if (!track)
		track = '';


	// From http://mediatomb.cc/dokuwiki/_media/scripting:import_abcbox.js?id=scripting%3Ascripting&cache=cache
	var disctitle = '';
	var album_artist = '';
	var tracktitle = '';
	
	// ALBUM //
	// Extra code for correct display of albums with various artists (usually Collections)
	if (!description) {
		album_artist = album + ' - ' + artist;
		tracktitle = track + title;
	} else {
		if (description.toUpperCase() == 'VARIOUS') {
			album_artist = album + ' - Various';
			tracktitle = track + title + ' - ' + artist;
		} else {
			album_artist = album + ' - ' + artist;
			tracktitle = track + title;
		}
	}

	// albums with multiple discs have an extra tag: discnumber: TPOS --> discno
	var discno = obj.aux['TPOS'];
	if (!discno) {
		// current
		chain = new Array('Music', 'Album', abcbox(album, 6, ''), album_artist);
		obj.title = tracktitle;
		addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_ALBUM);
	} else {
		discno = discno.split('/')[0];
		disctitle = discno + '.' + tracktitle;
	
		// single albums
		chain = new Array('Music', 'Album', abcbox(album, 6, ''), album_artist, 'disc '+ discno);
		obj.title = tracktitle; 
		addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_ARTIST);

		// all songs
		chain = new Array('Music', 'Album', abcbox(album, 6, ''), album_artist, ' All');
		obj.title = disctitle; 
		addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_ARTIST);
	}
    
	// ARTIST //
	chain = new Array('Music', 'Artist', abcbox(artist, 6, ''), artist, ' All');
	obj.title = title + ' (' + album + ', ' + date + ')'; 
	addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_ARTIST);
	
	if (!discno)
		obj.title = tracktitle;
	else
		obj.title = disctitle;
    
	chain = new Array('Music', 'Artist', abcbox(artist, 6, ''), artist, album);
	//	obj.title = tracktitle;
	addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_ALBUM);
    
	// GENRE //
	chain = new Array('Music', 'Genre', genre, ' All');
	obj.title = title + ' - ' + artist_full;
	addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_GENRE);
	
	chain = new Array('Music', 'Genre', genre, artist + ' - ' + album);
	if (!discno) 
		obj.title = tracktitle;
	else
		obj.title = disctitle;
	addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_ARTIST);
    
	// YEAR //
	// Ordered into decades    
	if (!decade) {
		chain = new Array('Music', 'Year', date, artist, album);
		addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER);
	} else {

		chain = new Array('Music', 'Year', decade, ' All');
		addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER);
		
		chain = new Array('Music', 'Year', decade, artist + ' - ' + album);
		if (!discno)
			obj.title = tracktitle;
		else
			obj.title = disctitle;
		
		addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER_MUSIC_ARTIST);
	}
}

function addVideo(obj) {

	var chain;

	if( obj.location.indexOf('/Videos') < 0 )
		return;

	if( obj.location.indexOf('/Movies') >= 0 ) {

		var path = obj.location.split('/');
		chain = new Array('Movies');
		addCdsObject(obj, createContainerChain(chain));

	} else if( obj.location.indexOf('/TV') >= 0 ) {

		var path = obj.location.split('/');
		var season = path[path.length - 2];
		var show = path[path.length - 3];

		/*
		  print('path = ' + obj.location);
		  print('show = ' + show);
		  print('season = ' + season);
		*/

		chain = new Array('TV', show, season);
		addCdsObject(obj, createContainerChain(chain));

	} else if( obj.location.indexOf('/Miro') >= 0 ) {

		if( obj.location.indexOf('Incomplete') >= 0 )
			return;

		addCdsObject( obj, createContainerChain( new Array('Miro') ) );
		
	} else if( obj.location.indexOf('/Shorts') ) {

		chain = new Array('Shorts');
		addCdsObject(obj, createContainerChain(chain));

	}

}

function addWeborama(obj) {
	var req_name = obj.aux[WEBORAMA_AUXDATA_REQUEST_NAME];
	if (req_name) {
		var chain = new Array('Online Services', 'Weborama', req_name);
		addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_PLAYLIST_CONTAINER);
	}
}

function addImage(obj) {

    // Only interested in images with /Photos in its path
    if( obj.location.indexOf('/Pictures') < 0 )
	return;

    // EXIF data
    var model = obj.aux['EXIF_TAG_MODEL'];
    if( !model ) model = 'Unknown';
    var width = obj.aux['EXIF_TAG_IMAGE_WIDTH'];
    if( !width )
	width = obj.aux['EXIF_TAG_PIXEL_X_DIMENSION'];
    var height = obj.aux['EXIF_TAG_IMAGE_LENGTH'];
    if( !height )
	height = obj.aux['EXIF_TAG_PIXEL_Y_DIMENSION'];
    
    var date_time = obj.aux['EXIF_TAG_DATE_TIME_DIGITIZED'];
    if( !date_time ) date_time = obj.aux['EXIF_TAG_DATE_TIME_ORIGINAL'];
    if( !date_time ) date_time = obj.aux['EXIF_TAG_DATE_TIME'];

    var exp_time = obj.aux['EXIF_TAG_EXPOSURE_TIME'];
    var fstop = obj.aux['EXIF_TAG_FNUMBER'];
    var iso = obj.aux['EXIF_TAG_ISO_SPEED_RATINGS'];
    var exp_bias = obj.aux['EXIF_TAG_EXPOSURE_BIAS_VALUE'];
    var flash = obj.aux['EXIF_TAG_FLASH'];

    // Title it based on properties
    obj.title = date_time;
    if( fstop ) obj.title = obj.title + ' - ' + fstop;
    if( iso ) obj.title = obj.title + ' - ISO ' + iso;
    if( exp_bias ) obj.title = obj.title + ' - Exp ' + exp_bias;
    if( width && height ) obj.title = obj.title + ' - ' + width + 'x' + height;
    if( flash ) obj.title = obj.title + ' - ' + flash;

    // The master container
    //    var chain = new Array('Pictures', 'All Photos');
    //    addCdsObject(obj, createContainerChain(chain), UPNP_CLASS_CONTAINER);

    // By album
    var last_path = getLastPath(obj.location);
    if (last_path) {
	if( last_path.match(/[a-zA-Z]+/) ) {
	    chain = new Array('Pictures', 'Albums', last_path);
	    addCdsObject(obj, createContainerChain(chain));
	}
    }

    // By date
    var dt = parseDateTime(date_time);
    if( dt ) {
	addCdsObject(obj, 
		     createContainerChain(['Pictures','By date',year(dt),month(dt),date(dt)]));
	addCdsObject(obj,
		     createContainerChain(['Pictures','By date',year(dt),' All']));
	addCdsObject(obj,
		     createContainerChain(['Pictures','By date',year(dt),month(dt),' All']));
    }

    // By camera
    addCdsObject(obj,
		 createContainerChain(['Pictures','By camera',model,' All']));
    // By camera, by date
    if( dt ) {
	addCdsObject(obj,
		     createContainerChain(['Pictures','By camera',model,'By date',
					   year(dt),month(dt),date(dt)]));
	addCdsObject(obj,
		     createContainerChain(['Pictures','By camera',model,'By date',
					   year(dt),month(dt),date(dt)]));
	addCdsObject(obj,
		     createContainerChain(['Pictures','By camera',model,'By date',
					   year(dt),month(dt),' All']));
	addCdsObject(obj,
		     createContainerChain(['Pictures','By camera',model,'By date',
					   year(dt),' All']));
    }

    // By size
    addCdsObject(obj,
		 createContainerChain(['Pictures','By size',width+'x'+height,' All']));
    addCdsObject(obj,
		 createContainerChain(['Pictures','By size',width+'x'+height,
				       'By Date',year(dt),month(dt),date(dt)]));
    addCdsObject(obj,
		 createContainerChain(['Pictures','By size',width+'x'+height,
				       'By Date',year(dt),month(dt),' All']));
    addCdsObject(obj,
		 createContainerChain(['Pictures','By size',width+'x'+height,
				       'By Date',year(dt),' All']));

}


function addYouTube(obj)
{
    var chain;

    var temp = parseInt(obj.aux[YOUTUBE_AUXDATA_AVG_RATING], 10);
    if (temp != Number.NaN) {
        temp = Math.round(temp);
        if (temp > 3) {
            chain = new Array('Online Services', 'YouTube', 'Rating', 
			      temp.toString());
            addCdsObject(obj, createContainerChain(chain));
        }
    }
    
    temp = obj.aux[YOUTUBE_AUXDATA_REQUEST];
    if (temp) {
        var subName = (obj.aux[YOUTUBE_AUXDATA_SUBREQUEST_NAME]);
        var feedName = (obj.aux[YOUTUBE_AUXDATA_FEED]);
        var region = (obj.aux[YOUTUBE_AUXDATA_REGION]);
	
        
        chain = new Array('Online Services', 'YouTube', temp);
	
        if (subName)
            chain.push(subName);

        if (feedName)
            chain.push(feedName);

        if (region)
            chain.push(region);

        addCdsObject(obj, createContainerChain(chain));
    }
}

function addTrailer(obj) {
    var chain;
    
    chain = new Array('Online Services', 'Apple Trailers', 'All Trailers');
    addCdsObject(obj, createContainerChain(chain));
    
    var genre = obj.meta[M_GENRE];
    if (genre) {
        genres = genre.split(', ');
        for (var i = 0; i < genres.length; i++) {
	    chain = new Array('Online Services', 'Apple Trailers', 'Genres',
                              genres[i]);
            addCdsObject(obj, createContainerChain(chain));
        }
    }
    
    var reldate = obj.meta[M_DATE];
    if ((reldate) && (reldate.length >= 7)) {
        chain = new Array('Online Services', 'Apple Trailers', 'Release Date',
                          reldate.slice(0, 7));
        addCdsObject(obj, createContainerChain(chain));
    }
    
    var postdate = obj.aux[APPLE_TRAILERS_AUXDATA_POST_DATE];
    if ((postdate) && (postdate.length >= 7)) {
        chain = new Array('Online Services', 'Apple Trailers', 'Post Date',
                          postdate.slice(0, 7));
        addCdsObject(obj, createContainerChain(chain));
    }
}

// main script part

if (getPlaylistType(orig.mimetype) == '') {
    var arr = orig.mimetype.split('/');
    var mime = arr[0];
    
    // var obj = copyObject(orig);
    
    var obj = orig; 
    obj.refID = orig.id;
    
    if (mime == 'audio') {
        if (obj.onlineservice == ONLINE_SERVICE_WEBORAMA)
            addWeborama(obj);
        else
            addAudio(obj);
    }
    
    if (mime == 'video') {
        if (obj.onlineservice == ONLINE_SERVICE_YOUTUBE)
            addYouTube(obj);
        else if (obj.onlineservice == ONLINE_SERVICE_APPLE_TRAILERS)
            addTrailer(obj);
        else
            addVideo(obj);
    }
    
    if (mime == 'image') {
        addImage(obj);
    }
    
    if (orig.mimetype == 'application/ogg') {
        if (orig.theora == 1)
            addVideo(obj);
        else
            addAudio(obj);
    }
}
