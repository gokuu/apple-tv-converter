# apple-tv-converter

Command line utility to convert media to a format playable on the AppleTV. Supports embedding subtitles and sets metadata according to the media file.

## On Mac OSX

- Uses [ffmpeg](http://ffmpeg.org) to encode video and audio, as well as extracting embedded subtitles
- Uses [Subler](http://code.google.com/p/subler/)'s command line interface to add the subtitles and set the iTunes metadata tags 

# Command line usage

``` bash
Usage: apple-tv-converter [options] [file]
       [file] must be provided unless the -d (--dir) switch is present.
        --no-transcoding             Don't transcode video or audio
        --no-subtitles               Don't add subtitles
        --no-metadata                Don't add metadata
        --no-cleanup                 Don't cleanup the source files after processing
    -l, --languages eng,por,...      Only keep audio and subtitles in the specified languages
    -d, --dir [DIRECTORY]            Process all files in DIRECTORY recursively
        --itunes                     Add processed file to iTunes library, if it isn't there yet

Common options:
    -h, --help                       Show this message
        --version                    Show version
```

## Remarks

- The file metadata name is set according to the file's directory name, ie, the file `/Home Movie 1/movie.mkv` is converted to `/Home Movie 1/movie.mp4` and the name on metadata is set as `Home Movie 1`.
    - For TV Show episodes, the metadata name is a concatenation of the directory (removing a reference to the season number, in the format Sxx) with the season and episode number, ie, `/TV Show S01/tv.show.s01e01.mkv` will have, after conversion, the name `TV Show S01E01`.
    Episode and season information is captured from the file name, in the formats S01E01 or 1x01 (case insensitive).
- The file genre is set from the directory name, for tv shows (ie, `/TV Show S01/tv.show.s01e01.mkv` will have the genre `TV Show`), and according to the movie's size (ie, `1080p Movies`, `720p Movies`, and `XviD movies`).
- External subtitles must be in SubRip (srt) format and have the same name as the file, optionally appending the language's code ie, for movie `/Home Movie 1/movie.mkv`, will load subtitles from file `/Home Movie 1/movie.srt` or `/Home Movie 1/movie.<language>.mkv`
    - Subtitles with appended language code will have the correct language set in metadata.
        - Language codes should be [ISO 639-3](http://www.iso.org/iso/home/standards/language_codes.htm) codes (mostly, I haven't quite figured all the languages yet =)

    Example: 
    For the movie file `/Home Movie 1/movie.mkv`, the following subtitle files are loaded:

    - `/Home Movie 1/movie.srt` (language 'Unknown')
    - `/Home Movie 1/movie.eng.srt` (language 'English')
    - `/Home Movie 1/movie.2.por.srt` (language 'Portuguese'. Note: the _2_ is an mkvinfo id when extracted from an MKV movie)


# TODO

- Windows implementation
- Tests!