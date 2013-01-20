module AppleTvConverter
  class CommandLine
    def initialize(*args)
      @skip_subtitles = false
      @skip_metadata = false
      @skip_cleanup = false

      begin
        options = parse_arguments(args)

        media_objects = options.delete(:media)

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
        data = {
          :skip_subtitles => false,
          :skip_metadata => false,
          :skip_cleanup => false,
          :media => []
        }

        raise ArgumentError.new("No arguments supplied") unless arguments.any?

        is_dir = false

        arguments.each do |argument|
          if argument.strip =~ /^--/
            # Can be a switch, starting with --
            if argument.strip =~ /^--no-subtitles$/i
              data[:skip_subtitles] = true
            elsif argument.strip =~ /^--no-metadata$/i
              data[:skip_metadata] = true
            elsif argument.strip =~ /^--no-cleanup$/i
              data[:skip_cleanup] = true
            elsif argument.strip =~ /^--dir$/i
              is_dir = true
            else
              raise ArgumentError.new("Unknown switch: #{argument}")
            end
          elsif is_dir
            # Previous argument identified a directory
            raise ArgumentError.new("Path not found: #{argument}") unless File.exists?(argument)
            raise ArgumentError.new("Path is not a directory: #{argument}") unless File.directory?(argument)

            # Recursively load all movie files
            data[:media].push *(Dir[File.join(argument, '**', '*.{mp4,avi,mkv,m4v,m2ts}')].map do |file|
              parse_filename(file)
            end.compact)

            is_dir = false
          else
            # Or a file
            raise ArgumentError.new("File not found: #{argument}") unless File.exists?(argument)

            media = parse_filename(argument)

            raise ArgumentError.new("Invalid media file: #{argument}") unless media

            data[:media] << media
          end
        end

        raise ArgumentError.new("No media file supplied") unless data[:media].any?

        return data
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