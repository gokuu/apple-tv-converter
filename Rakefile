namespace :convert do
  desc 'Convert all videos in a folder (on Mac OS)'
  task :mac do
    require './lib/apple_tv_converter'

    converter = AppleTvConverter::MediaConverter.new
    #converter.convert_all File.join('/', 'Volumes', 'Series', 'Ignore for now')

    # media = parse_filename("/Users/pedro/Downloads/Completed Torrents/9/9.mkv")
    media = parse_filename("/Users/pedro/Downloads/Completed Torrents/Once Upon a Time S02/Once.Upon.a.Time.S02E07.HDTV.x264-LOL.mp4")

    converter.process_media media
  end

  desc 'Convert all videos in a folder (on Windows)'
  task :windows do
    require './lib/media'
    require './lib/media_converter'
    require './lib/media_converter_adapter'
    require './lib/media_converter_windows_adapter'

    converter = AppleTvConverter::MediaConverter.new
    converter.convert_all_movies File.join('e:', 'Movies HD - 1080p')
  end
end

# Expects a folder structure like #{base_dir}/Show Name S00/media
def convert_all(base_dir)
  # Build media listing
  medias = []
  Dir[File.join(base_dir, '*')].each do |series_dir|
    Dir[File.join(series_dir, '*')].each do |file|
      media = parse_filename(file)
      next unless media
      medias << media if media.convert?
    end
  end

  process_all_medias medias
end

def parse_filename(file)
  return nil unless FFMPEG::Movie.new(file).valid?

  # match
  # [0] - Full string
  # [1] - Show name
  begin
    e = AppleTvConverter::Media.new
    # Extract name
    match = File.dirname(file).match(/.*\/(.*?)(?:S(\d+))?$/i)
    e.show = match[1].strip

    # Extract season an media number
    match = File.basename(file).match(/.*S?(\d+)[Ex](\d+).*/i)
    if match
      e.season = match[1].to_i if match[1]
      e.number = match[2].to_i if match[2]
    end
    e.original_filename = file

    return e
  rescue => exc
    puts "Couldn't parse filename, skipping: #{File.basename(file)}"
    return nil
  end
end
