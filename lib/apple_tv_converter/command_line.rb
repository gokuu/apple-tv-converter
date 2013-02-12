module AppleTvConverter
  class CommandLine
    def initialize(*args)
      @skip_subtitles = false
      @skip_metadata = false
      @skip_cleanup = false

      begin
        options = parse_arguments(args)

        media_objects = options.media

        converter = AppleTvConverter::MediaConverter.new(options)

        media_objects.sort { |a, b| a.original_filename <=> b.original_filename }.each_with_index do |media, index|
          puts "---[ Processing file #{index + 1} of #{media_objects.length}: #{File.basename(media.original_filename)} ]----------------"
          converter.process_media media
        end
      rescue ArgumentError => e
        puts "Error: #{e.message}"
      rescue => e
        puts "Error: #{e.message}"
        puts e.backtrace
      end
    end

    private

      def parse_arguments(arguments)
        require 'optparse'
        require 'optparse/time'
        require 'ostruct'

        options = OpenStruct.new
        options.skip_transcoding = false
        options.skip_subtitles = false
        options.skip_metadata = false
        options.skip_cleanup = false
        options.add_to_itunes = false
        options.languages = []
        options.media = []

        opts = OptionParser.new do |opts|
          opts.banner = "Usage: apple-tv-converter [options] [file]\n" +
                        "       [file] must be provided unless the -d (--dir) switch is present.\n"

          opts.on('--no-transcoding', "Don't transcode video or audio") do |v|
            options.skip_transcoding = true
          end

          opts.on('--no-subtitles', "Don't add subtitles") do |v|
            options.skip_subtitles = true
          end

          opts.on('--no-metadata', "Don't add metadata") do |m|
            options.skip_metadata = true
          end

          opts.on('--no-cleanup', "Don't cleanup the source files after processing") do |c|
            options.skip_cleanup = true
          end

          opts.on('-l', '--languages eng,por,...', Array, "Only keep audio and subtitles in the specified languages") do |languages|
            options.languages.push *languages
          end

          opts.on('-d', '--dir [DIRECTORY]', 'Process all files in DIRECTORY recursively') do |dir|
            raise ArgumentError.new("Path not found: #{dir}") unless File.exists?(dir)
            raise ArgumentError.new("Path is not a directory: #{dir}") unless File.directory?(dir)

            options.media.push *(Dir[File.join(dir, '**', '*.{avi,mkv,m4v,m2ts,ogg,ogm,mp4}')].map do |file|
              parse_filename(file)
            end.compact)
          end

          opts.on('--itunes', "Add processed file to iTunes library, if it isn't there yet") do |i|
            options.add_to_itunes = true
          end

          opts.separator ""
          opts.separator "Common options:"

          # No argument, shows at tail.  This will print an options summary.
          # Try it and see!
          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end

          # Another typical switch to print the version.
          opts.on_tail("--version", "Show version") do
            puts AppleTvConverter::VERSION
            exit
          end
        end

        opts.parse! arguments
        options.media.push *(arguments.map { |file| parse_filename(file) }.compact)

        raise ArgumentError.new("No media file supplied") unless options.media.any?

        return options
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
  end
end