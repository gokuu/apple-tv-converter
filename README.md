apple-tv-converter
=================

Media converter for AppleTV.

## On Mac OSX

- Uses ffmpeg for encoding (http://ffmpeg.org)
- Uses Subler for adding the subtitles and setting the iTunes metadata tags (http://code.google.com/p/subler/)
- Uses MKVToolNix for extracting the embedded subtitles from MKV files (http://www.bunkus.org/videotools/mkvtoolnix/)

## Command line usage

``` bash
apple-tv-converter option [option] [option]...

options:
    --no-subtitles  # Skips subtitles extraction and addition
    --no-metadata   # Skips adding metadata to the converted file 
    --no-cleanup    # Skips deleting the source files
    
    Anything not starting with -- is considered a file to convert
```

# TODO

- Windows implementation
- Tests!