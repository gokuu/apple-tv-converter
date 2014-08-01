# apple-tv-converter

Command line utility to convert media to a format playable on the AppleTV. Supports embedding subtitles and sets metadata according to the media file.
Now, it also supports automatically downloading subtitles from [opensubtitles.org](http://www.opensubtitles.org) and, in the same process, infering the movie's IMDB id for metadata.

## On Mac OSX

- Uses [ffmpeg](http://ffmpeg.org) to encode video and audio, as well as extracting embedded subtitles
- Uses [Subler](http://code.google.com/p/subler/)'s command line interface to add the subtitles and set the iTunes metadata tags

# Command line usage

``` bash
Usage: apple-tv-converter [options] [file]
       [file] must be provided unless the -d (--dir) switch is present.
    -i, --id id                      Set a specific id for fetching metadata from online services
        --imdb_id id                 Set a specific id for fetching metadata from IMDB
        --tvdb_id id                 Set a specific id for fetching metadata from TheTVDB
    -l, --languages eng,por,...      Only keep audio and subtitles in the specified languages
    -d, --dir DIRECTORY              Process all files in DIRECTORY recursively
        --itunes                     Add processed file to iTunes library, if it isn't present yet
        --os [USERNAME:PASSWORD]     Download subtitles and infer IMDB ID from opensubtitles.org
        --plex                       Rename file(s) to Plex Media Server recommended format

        --no-transcoding             Don't transcode video or audio
        --no-subtitles               Don't add subtitles
        --no-metadata                Don't add metadata (implies --no-online-metadata)
        --no-online-metadata         Don't fetch metadata from online services (IMDB or TheTVDB)
        --no-interactive             Perform all operations without user intervention, using sensible defaults
        --no-cleanup                 Don't cleanup the source files after processing

Advanced options:
        --use-absolute-numbering     Use absolute numbering for TV Show episodes (specially useful for cartoons)
        --episode-number-padding NUMBER
                                     Set the episode number padding length (ie, 3 for 001, 002, etc.)
    -s, --season NUMBER              Set the season number for TV Shows in case folder/file naming scheme doesn't contain right season
    -e, --episode NUMBER             Set the episode number for TV Shows in case folder/file naming scheme doesn't contain right episode number
        --width NUMBER               Resize the video to the specified width. If used with --height, can result in a different aspect ratio
        --height NUMBER              Resize the video to the specified height. If used with --width, can result in a different aspect ratio

Other options:
    -f, --ffmpeg LOCATION            Set path to ffmpeg binary

DEPRECATED options:
        --imdb                       Gather data from IMDB (optionally specifying movie id)

Common options:
    -h, --help                       Show this message
        --version                    Show version
```

## Remarks

### Subtitles

- External subtitles must be in SubRip (srt) format and have the same name as the file, optionally appending the language's code ie, for movie `/Home Movie 1/movie.mkv`, will load subtitles from file `/Home Movie 1/movie.srt` or `/Home Movie 1/movie.<language>.mkv`
    - Subtitles with appended language code will have the correct language set in metadata.
        - Language codes should be [ISO 639-3](http://www.iso.org/iso/home/standards/language_codes.htm) codes (mostly, I haven't quite figured all the languages yet =)

    Example:
    For the movie file `/Home Movie 1/movie.mkv`, the following subtitle files are loaded:

    - `/Home Movie 1/movie.srt` (language 'Unknown')
    - `/Home Movie 1/movie.eng.srt` (language 'English')
    - `/Home Movie 1/movie.2.por.srt` (language 'Portuguese'. Note: the _2_ is an mkvinfo id when extracted from an MKV movie)

### Metadata

Metadata can be obtained automatically from themoviedb.org(http://www.themoviedb.org) (for movies) or from TheTVDB.com(http://www.thetvdb.com) (for TV show episodes).
Both fall back to IMDB.com(http://www.imdb.com) for necessary information. Most metadata will be filled, including the file's artwork, so it displays a nice image on iTunes library.

#### Fallbacks

If the data can't be found on neither site, there is a fallback for how metadata is set:
- The file metadata name is set according to the file's directory name, ie, the file `/Home Movie 1/movie.mkv` is converted to `/Home Movie 1/movie.mp4` and the name on metadata is set as `Home Movie 1`.
    - An exception to this is when the directory name has the format `Season XX`. In this situation the name is obtained from the 'grandparent' folder, ie, the file `/Home Movie 1/Season 1/movie.mp4` wil have the name on metadata set to `Home Movie 1`.
- For TV Show episodes, the metadata name is a concatenation of the directory (removing a reference to the season number, in the format Sxx) with the season and episode number, ie, both `/TV Show S01/tv.show.s01e01.mkv` and `/TV Show/Season 1/tv.show.s01e01.mkv` will have, after conversion, the name `TV Show S01E01`.
    Episode and season information is captured from the file name, in the formats S01E01 or 1x01 (case insensitive).
- The file genre is set from the directory name, for tv shows (ie, `/TV Show S01/tv.show.s01e01.mkv` will have the genre `TV Show`), and according to the movie's size (ie, `1080p Movies`, `720p Movies`, and `XviD Movies`).

### Plex Media Server

For Plex Media Server users, you can pass the command-line option `--plex` to automatically rename the file after conversion following the recommended file name convention. For files with multiple TV show episodes, the first and last episodes are identified in the file name (if it was possible to infer from the original filename).

### Other remarks

After conversion, `apple-tv-converter` will create a file named `.apple-tv-converter.data` on the base directory of the file containing some information (IMDB id, TheTVDB id, etc.) that can be useful for subsequent processing.

## Thanks

**Subtitles service powered by [www.OpenSubtitles.org](http://www.opensubtitles.org)**
![opensubtitles.org logo](http://static.opensubtitles.org/gfx/logo-transparent.png)

**Movie metadata service powered by [www.imdb.com](http://www.imdb.com)**
**TV Show metadata service powered by [www.thetvdb.com](http://www.thetvdb.com)**

# TODO

- Windows implementation
- Tests!