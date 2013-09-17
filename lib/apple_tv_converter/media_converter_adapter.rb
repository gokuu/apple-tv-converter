module AppleTvConverter
  class MediaConverterAdapter
    include AppleTvConverter

    def search_subtitles(media, languages)
      # Load the subtitles into memory and get IMDB id from them
      AppleTvConverter::SubtitlesFetcher::Opensubtitles.new(languages) do |fetcher|
        fetcher.search_subtitles media do |subtitles|
          media.imdb_id = subtitles.first['IDMovieImdb'] if media.imdb_id.nil? || media.imdb_id.to_s.strip == ''
        end
      end
    end

    def download_subtitles(media, languages)
      AppleTvConverter::SubtitlesFetcher::Opensubtitles.new(languages) do |fetcher|
        if fetcher.has_found_subtitles?(media)
          printf "* Downloading subtitles"
          fetcher.download_subtitles media do |step, subtitles|
            case step
              when :search        then puts %Q[ (#{subtitles.map { |l, subs| "#{subs.count} #{get_language_name(l)}" }.join(', ') })]
              when :downloading   then printf "  * Downloading: \##{subtitles['IDSubtitleFile']} (#{get_language_name(subtitles['SubLanguageID'])}) - #{subtitles['SubFileName']}"
              when :downloaded    then puts " [DONE]"
            end
          end
          puts "  * All subtitles downloaded"
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
      if media.needs_transcoding?
        puts "* Transcoding"

        options = {}
        options[:codecs] = get_transcode_options(media)
        options[:files] = ""
        options[:metadata] = ""
        options[:map] = ""
        options[:extra] = ""

        # Better video and audio transcoding quality
        if media.needs_video_conversion?
          # Ensure divisible by 2 width and height
          dimensions = "-s #{(media.ffmpeg_data.width % 2 > 0) ? (media.ffmpeg_data.width + 1) : media.ffmpeg_data.width}x#{(media.ffmpeg_data.height % 2 > 0) ? (media.ffmpeg_data.height + 1) : media.ffmpeg_data.height}" if media.ffmpeg_data.width % 2 > 0 || media.ffmpeg_data.height % 2 > 0

          options[:extra] << " #{dimensions} -mbd rd -flags +mv4+aic -trellis 2 -cmp 2 -subcmp 2 -g 300 -pass 1 -q:v 1 -r 23.98"
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
          options[:extra] << " -ac #{media.ffmpeg_data.audio_channels} -ar #{media.ffmpeg_data.audio_sample_rate}"
          options[:extra] << " -ab #{[audio_bitrate, (media.ffmpeg_data.audio_bitrate || 1000000)].min}k"
        end

        # Ensure the languages are 'stored' as symbols, for comparison
        languages = (languages || []).map(&:to_sym)

        # If we're filtering by language, ensure that unknown and undetermined language
        # streams are also mapped
        languages += [nil, :und, :unk] if languages.any?

        # If the file has more than one audio track, map all tracks but subtitles when transcoding
        if media.audio_streams.length > 0
          media.streams.each do |stream|
            options[:map] << " -map #{stream.input_number}:#{stream.stream_number}" if stream.type == :video || (stream.type == :audio && (languages.empty? || languages.include?(stream.language ? stream.language.to_sym : stream.language)))
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
      media.tvdb_movie = TvDbFetcher.search(media)
      if media.tvdb_movie
        media.imdb_id = media.tvdb_movie[:episode]['IMDB_ID'] if media.tvdb_movie[:episode] && media.tvdb_movie[:episode].has_key?('IMDB_ID')
        media.imdb_id = media.tvdb_movie[:show][:series]['IMDB_ID'] if media.imdb_id.nil? || media.imdb_id.blank?
        media.imdb_id = media.imdb_id.gsub(/\D+/, '')

        # Update the episode name, if available
        media.episode_title = media.tvdb_movie_data('EpisodeName')

        get_imdb_info(media) unless media.imdb_id.blank?
      end
    end

    def get_imdb_info(media)
      printf "* Getting info from IMDB"

      if media.imdb_id
        media.imdb_movie = Imdb::Movie.new(media.imdb_id)
      elsif Dir[File.join(File.dirname(media.original_filename), '*.imdb')].any?
        media.imdb_movie = Imdb::Movie.new(File.basename(Dir[File.join(File.dirname(media.original_filename), '*.imdb')].first).gsub(/\.imdb$/i, ''))
      else
        puts " [SKIPPING - COULDN'T FIND IMDB ID]"
        return
      end

      puts " [DONE]"
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

    protected

      def list_files(ls)
        raise NotImplementedYetException
      end

      def has_subtitles?(media)
        list_files(File.join(File.dirname(media.original_filename), '*.srt')).any?
      end

      def get_transcode_options(media)
        options =  " -vcodec #{media.needs_video_conversion? ? 'libx264' : 'copy'}"
        options << " -acodec #{media.needs_audio_conversion? ? 'libfaac' : 'copy'}"

        options
      end
  end
end