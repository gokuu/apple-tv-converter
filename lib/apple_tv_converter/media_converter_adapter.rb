module AppleTvConverter
  class MediaConverterAdapter
    include AppleTvConverter

    attr_accessor :conversion_options

    def initialize(options)
      self.conversion_options = options
    end

    def search_subtitles(media, languages)
      # Load the subtitles into memory and get IMDB id from them
      AppleTvConverter::SubtitlesFetcher::Opensubtitles.new(languages, self.conversion_options.download_subtitles_username, self.conversion_options.download_subtitles_password) do |fetcher|
        fetcher.search_subtitles media do |subtitles|
          media.imdb_id = subtitles.first['IDMovieImdb'] if media.imdb_id.nil? || media.imdb_id.to_s.strip == ''
        end
      end
    end

    def download_subtitles(media, languages)
      AppleTvConverter::SubtitlesFetcher::Opensubtitles.new(languages, self.conversion_options.download_subtitles_username, self.conversion_options.download_subtitles_password) do |fetcher|
        if fetcher.has_found_subtitles?(media)
          printf "* Downloading subtitles#{%Q[ using user "#{self.conversion_options.download_subtitles_username}"] unless self.conversion_options.download_subtitles_username.nil?}"
          status = {
            :total => 0,
            :ok => 0,
            :error => 0
          }

          fetcher.download_subtitles media do |step, subtitles, message|
            case step
              when :search          then puts %Q[ (#{subtitles.map { |l, subs| "#{subs.count} #{AppleTvConverter.get_language_name(l)}" }.join(', ') })]
              when :downloading
                status[:total] += 1
                printf "  * Downloading: \##{subtitles['IDSubtitleFile']} (#{AppleTvConverter.get_language_name(subtitles['SubLanguageID'])}) - #{subtitles['SubFileName']}"
              when :downloaded      then
                status[:ok] += 1
                puts " [DONE]"
              when :download_failed then
                status[:error] += 1
                puts " [ERROR - #{message}]"
            end
          end

          if status[:total] == status[:ok]
            puts "  * All subtitles downloaded"
          elsif status[:total] == status[:error]
            puts "  * Couldn't download any subtitle"
          else
            puts "  * Downloaded #{status[:ok]} of #{status[:total]} subtitles"
          end
        else
          puts "* No subtitles found to download"
        end
      end
    end

    def extract_subtitles(media, languages)
      puts "* Extracting subtitles"

      languages.map!(&:to_sym)

      if media.has_embedded_subtitles?(languages)
        last_destination_filename = nil

        options = "-scodec subrip"

        media.ffmpeg_data.streams.each do |stream|
          next unless stream.type == :subtitle && (languages.empty? || languages.include?(stream.language.to_sym))
          filename = File.join(File.dirname(media.original_filename), "#{File.basename(media.original_filename).gsub(File.extname(media.original_filename), %Q[.#{stream.stream_number}.#{stream.language}.srt])}")

          begin
            printf "  * #{File.basename(filename)}: Progress:     0%"
            start_time = Time.now.to_i
            transcoded = media.ffmpeg_data.transcode(filename, "#{options} -map #{stream.input_number}:#{stream.stream_number}", :validate_output => false) do |progress|
              elapsed = Time.now.to_i - start_time
              printf "\r" + (" " * 40)
              printf "\r  * #{File.basename(filename)}: Progress: #{(progress * 10000).round.to_s.gsub(/(\d{2})$/, '.\1').gsub(/^\./, '0.').rjust(6)}%% (#{(elapsed / 60).to_s.rjust(2, '0')}:#{(elapsed % 60).to_s.rjust(2, '0')})     "
            end
            puts ""
          rescue Interrupt
            puts "\nProcess canceled!"
            exit!
          end
        end

        puts "  * Extracted all subtitles"
      else
        puts "  * No subtitles to extract"
      end
    end

    def transcode(media, languages = nil)
      if media.needs_transcoding? || needs_transformation?(media)
        puts "* Transcoding"

        options = {}
        options[:codecs] = get_transcode_options(media)
        options[:files] = ""
        options[:metadata] = ""
        options[:map] = ""
        options[:extra] = ""

        # Better video and audio transcoding quality
        if media.needs_video_conversion?
          options[:extra] << " #{get_transcoded_dimensions_options(media)} -mbd rd -flags +mv4+aic -trellis 2 -cmp 2 -subcmp 2 -g 300 -pass 1 -q:v 1 -r 23.98 -pix_fmt yuv420p"
        end

        if media.needs_audio_conversion?
          if media.ffmpeg_data.audio_codec =~ /mp3/i
            # Ensure that destination audio bitrate is 128k for Stereo MP3 (couldn't convert with higher bitrate)
            audio_bitrate = 128 if media.ffmpeg_data.audio_channels == 2
          elsif media.ffmpeg_data.audio_codec =~ /pcm_s16le/i
            # Ensure that destination audio bitrate is 128k for PCM signed 16-bit little-endian (couldn't convert with higher bitrate)
            audio_bitrate = 128
          elsif media.ffmpeg_data.audio_codec =~ /ac3/i
            # Ensure that maximum destination audio bitrate is 576k for AC3 (couldn't convert with higher bitrate)
            audio_bitrate = [media.ffmpeg_data.audio_bitrate || 576, 576].min
          end

          audio_bitrate ||= media.ffmpeg_data.audio_bitrate || 448

          options[:extra] << " -af volume=2.000000" # Increase the volume when transcoding
          options[:extra] << " -ac #{get_transcoded_audio_channels(media)} -ar #{media.ffmpeg_data.audio_sample_rate}"
          options[:extra] << " -ab #{[audio_bitrate, (media.ffmpeg_data.audio_bitrate || 1000000)].min}k"
        end

        # Ensure the languages are 'stored' as symbols, for comparison
        languages = (languages || []).map(&:to_sym)

        # If we're filtering by language, ensure that unknown and undetermined language
        # streams are also mapped
        languages += [nil, :und, :unk] if languages.any?

        # If the file has more than one audio track, map all tracks but subtitles when transcoding
        if media.audio_streams.length > 0
          # Check whether to filter audio tracks (ie, we have at least one of the languages we're filtering)
          filter_by_language = false

          if languages.any?
            media.streams.each do |stream|
              if stream.type == :audio && languages.include?(stream.language ? stream.language.to_sym : stream.language)
                filter_by_language = true
                break
              end
            end
          end

          media.streams.each do |stream|
            options[:map] << " -map #{stream.input_number}:#{stream.stream_number}" if stream.type == :video || (stream.type == :audio && (!filter_by_language || languages.include?(stream.language ? stream.language.to_sym : stream.language)))
          end
        end

        options = "#{options[:files]} #{options[:codecs]} #{options[:map]} #{options[:metadata]} #{options[:extra]}"

        transcoded = nil

        begin
          start_time = Time.now.to_i
          transcoded = media.ffmpeg_data.transcode(media.converted_filename, options) do |progress|
            elapsed = Time.now.to_i - start_time
            printf "\r" + (" " * 40)
            printf %Q[\r  * Progress: #{(progress * 10000).round.to_s.gsub(/(\d{2})$/, '.\1').gsub(/^\./, '0.').rjust(6)}%% (#{(elapsed / 60).to_s.rjust(2, '0')}:#{(elapsed % 60).to_s.rjust(2, '0')})]
          end
        rescue Interrupt
          puts "\nProcess canceled!"
          exit!
        end

        status = transcoded.valid?

        printf "\r" + (" " * 40)

        if status
          puts "\r  * Progress: [DONE]#{' ' * 20}"
        else
          puts "\r  * Progress: [ERROR]#{' ' * 20}"
          exit!
        end
      else
        puts "* Encoding: [UNNECESSARY]"
        status = true
      end

      return status
    end

    def add_subtitles(media)
      raise NotImplementedYetException
    end

    def get_metadata(media)
      if media.is_tv_show_episode?
        get_tv_show_db_info media
      else
        get_imdb_info media
      end
    end

    def get_tv_show_db_info(media)
      printf "* Getting info from TheTVDB"

      media.tvdb_movie = TvDbFetcher.search(media, conversion_options.interactive)
      if media.tvdb_movie
        media.imdb_id = media.tvdb_movie[:show][:series]['IMDB_ID'] if media.tvdb_movie.has_key?(:show) && media.tvdb_movie[:show].has_key?(:series)
        media.imdb_id = media.imdb_id.gsub(/\D+/, '') if media.imdb_id

        # Update the episode name, if available
        media.episode_title = media.tvdb_movie_data('EpisodeName')
        media.tvdb_id = media.tvdb_movie_data('seriesid')
        media.tvdb_season_id = media.tvdb_movie_data('seasonid')
        media.tvdb_episode_id = media.tvdb_movie_data('id')
        media.imdb_episode_id = media.tvdb_movie_data('IMDB_ID')
        media.imdb_episode_id = media.imdb_episode_id.gsub(/\D+/, '') if media.imdb_episode_id

        unless media.imdb_id.nil? || media.imdb_id.blank?
          puts "" # Line break just for output layout
          get_imdb_info(media, false)
        end

        puts " [DONE]"
      else
        puts " [NOT FOUND]"
      end
    end

    def get_imdb_info(media, feedback = true)
      printf "* Getting info from IMDB" if feedback

      if media.imdb_id
        media.imdb_movie = Imdb::Movie.new(media.imdb_id)
      elsif Dir[File.join(File.dirname(media.original_filename), '*.imdb')].any?
        media.imdb_movie = Imdb::Movie.new(File.basename(Dir[File.join(File.dirname(media.original_filename), '*.imdb')].first).gsub(/\.imdb$/i, ''))
      else

        search = Imdb::Search.new(media.show)

        search.movies.delete_if do |item|
          item.title.strip =~ /(?:(?:\(TV\s*(?:Movie|(?:Mini.?)?Series|Episode))|(?:Video(?:\s*Game)?))/i
        end

        media.imdb_id = if search.movies.length > 1 && conversion_options.interactive
          choice = 0
          puts "\n  *"
          while true
            puts %Q[  | Several movies found, choose the intended one#{" (showing only the first 20 of #{search.movies.length} results)" if search.movies.length > 20}:]

            search.movies[0...20].each_with_index do |item, index|
              puts "  | #{(index + 1).to_s.rjust(search.movies.length.to_s.length)} - #{item.title.strip} (id: #{item.id})"
              puts "  | #{' '.rjust(search.movies.length.to_s.length)}   AKA: #{item.also_known_as.join(', ').strip}" if item.also_known_as.any?
            end

            printf "  |\n  *- What's your choice (1..#{[search.movies.length, 20].min})? "
            choice = STDIN.gets.chomp.to_i

            break if choice.between?(1, [search.movies.length, 20].min)

            puts "  | Invalid choice!"
            puts "  |"
          end

          printf "  * Getting info from IMDB"
          search.movies[choice - 1].id
        else
          search.movies.first.id rescue nil
        end

        media.imdb_movie = Imdb::Movie.new(media.imdb_id) if media.imdb_id
      end

      begin
        media.imdb_movie.year
        puts " [DONE]" if feedback
      rescue OpenURI::HTTPError => e
        media.imdb_id = nil
        media.imdb_movie = nil
        puts (e.message =~ /404/ ? " [NOT FOUND]" : " [ERROR]") if feedback
      rescue
        if media.imdb_id.nil?
          puts " [NOT FOUND]" if feedback
        else
          raise e
        end
      end
    end

    def tag(media)
      raise NotImplementedYetException
    end

    def add_to_itunes(media)
      raise NotImplementedYetException
    end

    def clean_up(media)
      printf "* Cleaning up"
      begin
        if media.needs_transcoding?
          FileUtils.rm media.original_filename

          if media.converted_filename_equals_original_filename?
            FileUtils.mv media.converted_filename, media.original_filename
          end
        end

        # Always clean up subtitles and artwork, and backup
        FileUtils.rm(media.artwork_filename) if File.exists?(media.artwork_filename)
        FileUtils.rm_r list_files(media.original_filename.gsub(File.extname(media.original_filename), '*.srt'))
        FileUtils.rm(media.backup_filename) if File.exists?(media.backup_filename)

        puts " [DONE]"
      rescue
        puts " [ERROR]"
      end
    end

    def rename_to_plex_format(media)
      printf "* Renaming to PLEX format"
      begin
        plex_format_filename = media.plex_format_filename
        FileUtils.mv(media.converted_filename_equals_original_filename? ? media.original_filename : media.converted_filename, plex_format_filename) unless media.converted_filename == plex_format_filename

        puts " [DONE]"
      rescue => e
        puts " [ERROR]"
      end
    end

    protected

      def list_files(ls)
        raise NotImplementedYetException
      end

      def has_subtitles?(media)
        list_files(File.join(File.dirname(media.original_filename), '*.srt')).any?
      end

      def needs_transformation?(media)
        media.needs_video_resizing?
      end

      def get_transcode_options(media)
        options =  " -vcodec #{media.needs_video_conversion? ? 'libx264' : 'copy'}"
        options << " -acodec #{media.needs_audio_conversion? ? 'libfaac' : 'copy'}"

        options
      end

      def get_transcoded_audio_channels(media)
        audio_channels = media.ffmpeg_data.audio_channels || media.audio_streams.first.audio_channels
        # Fix for "[libfaac @ 0x7ff7bc0e6e00] Specified channel layout '2.1' is not supported" error
        audio_channels = 4 if audio_channels == 3

        audio_channels
      end

      def get_transcoded_dimensions_options(media)
        "-s #{(media.movie_width % 2 > 0) ? (media.movie_width + 1) : media.movie_width}x#{(media.movie_height % 2 > 0) ? (media.movie_height + 1) : media.movie_height}" if media.needs_video_resizing?
      end
  end
end