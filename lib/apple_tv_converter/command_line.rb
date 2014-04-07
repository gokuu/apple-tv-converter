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
        options.skip_online_metadata = false
        options.plex_format = false
        options.interactive = true
        options.imdb_id = nil
        options.use_absolute_numbering = false
        options.episode_number_padding = nil
        options.languages = []
        options.media = []

        opts = OptionParser.new do |opts|
          opts.banner = "Usage: apple-tv-converter [options] [file]\n" +
                        "       [file] must be provided unless the -d (--dir) switch is present.\n"

          opts.on('-i', '--id id', "Set a specific id for fetching metadata from online services") do |id|
            options.imdb_id = id
          end

          opts.on('-l', '--languages eng,por,...', Array, "Only keep audio and subtitles in the specified languages") do |languages|
            options.languages.push *languages
            # If filtering by languages, always include the undetermined language
            options.languages.push 'und' unless options.languages.include?('und')
          end

          opts.on('-d', '--dir DIRECTORY', 'Process all files in DIRECTORY recursively') do |dir|
            raise ArgumentError.new("Path not found: #{dir}") unless File.exists?(dir)
            raise ArgumentError.new("Path is not a directory: #{dir}") unless File.directory?(dir)

            found_files = Dir[File.join(dir, '**', '*')].delete_if do |f|
              # Skip files with subtitle or ignored extensions, or directories
              File.directory?(f) || [AppleTvConverter::Media.subtitle_extensions + AppleTvConverter::Media.ignored_extensions].flatten.include?(File.extname(f).gsub(/\./, '').downcase)
            end

            options.media.push *(found_files.map do |file|
              parse_filename(file)
            end.compact)
          end

          opts.on('--itunes', "Add processed file to iTunes library, if it isn't present yet") do |i|
            options.add_to_itunes = true
          end

          opts.on('--os', "Download subtitles and infer IMDB ID from opensubtitles.org") do |i|
            options.download_subtitles = true
          end

          opts.on('--plex', 'Rename file(s) to Plex Media Server recommended format') do
            options.plex_format = true
            options.skip_online_metadata = false
          end

          opts.separator ""

          opts.on('--no-transcoding', "Don't transcode video or audio") do |v|
            options.skip_transcoding = true
          end

          opts.on('--no-subtitles', "Don't add subtitles") do |v|
            options.skip_subtitles = true
          end

          opts.on('--no-metadata', "Don't add metadata (implies --no-online-metadata)") do |m|
            options.skip_metadata = true
          end

          opts.on('--no-online-metadata', "Don't fetch metadata from online services (IMDB or TheTVDB)") do |m|
            options.skip_online_metadata = true
          end

          opts.on('--no-interactive', "Perform all operations without user intervention, using sensible defaults") do |m|
            options.interactive = false
          end

          opts.on('--no-cleanup', "Don't cleanup the source files after processing") do |c|
            options.skip_cleanup = true
          end

          opts.separator ""
          opts.separator "Advanced options:"

          opts.on('--use-absolute-numbering', 'Use absolute numbering for TV Show episodes (specially useful for cartoons)') do |f|
            options.use_absolute_numbering = true
          end

          opts.on('--episode-number-padding NUMBER', 'Set the episode number padding length (ie, 3 for 001, 002, etc.)') do |i|
            options.episode_number_padding = i.to_i
          end

          opts.separator ""
          opts.separator "Other options:"

          opts.on('-f', '--ffmpeg LOCATION', 'Set path to ffmpeg binary') do |f|
            FFMPEG.ffmpeg_binary = f
          end

          opts.separator ""
          opts.separator "DEPRECATED options:"

          opts.on('--imdb', "Gather data from IMDB (optionally specifying movie id)") do
            puts "Warning: Switch --imdb is DEPRECATED, and will be removed in a future version. It is now activated by default"
            puts "         If you want to specify an id, please use the switch --id."
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
        begin
          return nil unless FFMPEG::Movie.new(file).valid?

          # match
          # [0] - Full string
          # [1] - Show name
          begin
            e = AppleTvConverter::Media.new

            # Extract name (check if the folder name is Season XX, and use the parent folder name if it is)
            test_path = File.expand_path(File.basename(File.dirname(file)) =~ /^season\s*\d+/i ? File.dirname(File.dirname(file)) : File.dirname(file))

            match = test_path.match(/.*\/(.*?)(?:S(\d+))?$/i)

            e.show = match[1].strip

            # Extract season and media number
            match = File.basename(file).match(/.*?S(\d+)E(\d+)(?:(?:[-E]+(\d+))*).*?/i)

            # /.*?S(\d+)E(\d+)(?:(?:[-E]+(\d+))*).*?/ -> S00E01, S00E01(E02)+, S00E01(-E02)+, S00E01(-02)+
            if match
              e.season = match[1].to_i
              e.number = match[2].to_i
              e.last_number = match[3].to_i if match[3]
            else
              match = File.basename(file).match(/(\d+)x(\d+)(?:(?:_?(?:\1)x(\d+))*)/i)

              # /(\d+)x(\d+)(?:(?:_?(?:\1)x(\d+))*)/ -> 0x01, 0x01(_0x02)+ , assuming same season number (0x01_1x02 fails!)
              if match
                e.season = match[1].to_i
                e.number = match[2].to_i
                e.last_number = match[3].to_i if match[3]
              end
            end

            e.original_filename = file

            return e
          rescue => exc
            puts "File.expand_path(file): #{File.expand_path(file)}"
            puts "Couldn't parse filename, skipping: #{File.basename(file)}"
            puts "Reason: #{exc.respond_to?(:message) ? exc.message : exc}"
            puts "In: #{exc.backtrace.join("\n    ")}"

            return nil
          end
        rescue Errno::ENOENT
          puts "File not found: #{file}"
        rescue Exception => e
          puts e

          exit!
        end

      end
  end
end