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

        id_switch = 0

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
        options.tvdb_id = nil
        options.use_absolute_numbering = false
        options.episode_number_padding = nil
        options.languages = []
        options.media = []
        options.season = nil
        options.episode = nil

        opts = OptionParser.new do |opts|
          opts.banner = "Usage: apple-tv-converter [options] [file]\n" +
                        "       [file] must be provided unless the -d (--dir) switch is present.\n"

          opts.on('-i', '--id id', "Set a specific id for fetching metadata from online services") do |id|
            raise ArgumentError.new("Can't supply both --id and --imdb_id or --tvdb_id at the same time!") if id_switch > 0

            id_switch = 3
            options.imdb_id = id
            options.tvdb_id = id
          end

          opts.on('--imdb_id id', "Set a specific id for fetching metadata from IMDB") do |id|
            raise ArgumentError.new("Can't supply both --id and --imdb_id or --tvdb_id at the same time!") if id_switch & 1 > 0

            id_switch |= 1
            options.imdb_id = id
          end

          opts.on('--tvdb_id id', "Set a specific id for fetching metadata from TheTVDB") do |id|
            raise ArgumentError.new("Can't supply both --id and --imdb_id or --tvdb_id at the same time!") if id_switch & 2 > 0

            id_switch |= 2
            options.tvdb_id = id
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

          opts.on('--os [USERNAME:PASSWORD]', "Download subtitles and infer IMDB ID from opensubtitles.org") do |username_password|
            options.download_subtitles = true
            if username_password =~ /^(.*?)\:(.*?)/
              options.download_subtitles_username = $1 if username_password =~ /^(.+?)\:.+$/
              options.download_subtitles_password = $1 if username_password =~ /^.+?\:(.+)$/
            end

            options.download_subtitles_username = nil if options.download_subtitles_username == ''
            options.download_subtitles_password = nil if options.download_subtitles_password == ''
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

          opts.on('-s', '--season NUMBER', 'Set the season number for TV Shows in case folder/file naming scheme doesn\'t contain right season') do |i|
            options.season = i.to_i
          end

          opts.on('-e', '--episode NUMBER', 'Set the episode number for TV Shows in case folder/file naming scheme doesn\'t contain right episode number') do |i|
            options.episode = i.to_i
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

          begin
            e = AppleTvConverter::Media.new

            parser = FilenameParser.new(file)

            e.show        = parser.tvshow_name
            e.season      = parser.season_number
            e.number      = parser.episode_number
            e.last_number = parser.last_episode_number

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