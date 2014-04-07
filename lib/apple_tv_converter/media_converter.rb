module AppleTvConverter
  class MediaConverter
    @@timeout = 200

    def initialize(options)
      @options = options
      @adapter = (AppleTvConverter.is_windows? ? AppleTvConverter::MediaConverterWindowsAdapter : AppleTvConverter::MediaConverterMacAdapter).new(options)

      AppleTvConverter.logger.level = Logger::ERROR
      FFMPEG.logger.level = Logger::ERROR
      FFMPEG::Transcoder.timeout = 300
    end

    def process_media(media)
      apply_options_to_media! media

      if media.is_tv_show_episode?
        puts "* TV Show Episode information:"
        puts "* Name: #{media.show}"
        puts "* Season: #{media.season}"
        puts %Q[* Number: #{media.number}#{"-#{media.last_number}" if media.last_number}]
      else
        puts "* Movie information"
        puts "* Name: #{media.show}"
        puts "* Genre: #{media.genre}"
      end

      if !@options.skip_online_metadata
        if media.imdb_id
          puts "* IMDB ID: #{media.imdb_id}"
        elsif !@options.skip_metadata
          puts "* IMDB ID: Unknown yet"
        end
        if media.is_tv_show_episode?
          if media.tvdb_id
            puts "* TheTVDB ID: #{media.tvdb_id}"
          elsif !@options.skip_metadata
            puts "* TheTVDB ID: Unknown yet"
          end
        end
      end

      puts "* #{media.audio_streams.length} audio track(s)"
      if media.audio_streams.any?
        media.audio_streams.each do |audio|
          language_code = audio.language || 'und'
          language_name = AppleTvConverter.get_language_name(language_code)
          puts "  * #{language_code} - #{language_name.nil? ? 'Unknown (ignoring)' : language_name}"
        end
      end

      puts "* #{media.subtitle_streams.length} embedded subtitle track(s)"
      if media.subtitle_streams.any?
        media.subtitle_streams.each do |subtitle|
          language_code = subtitle.language || 'und'
          language_name = AppleTvConverter.get_language_name(language_code)
          puts "  * #{language_code} - #{language_name.nil? ? 'Unknown (ignoring)' : language_name}"
        end
      end

      puts "* #{@adapter.list_files(media.original_filename.gsub(/.{4}$/, '.*srt')).count} external subtitle track(s)"
      if @adapter.list_files(media.original_filename.gsub(/.{4}$/, '.*srt')).any?
        @adapter.list_files(media.original_filename.gsub(/.{4}$/, '.*srt')).each do |subtitle|
          subtitle =~ /\.(.{3})\.srt/i
          language_code = $1 || 'und'
          language_name = AppleTvConverter.get_language_name(language_code)
          puts "  * #{language_code.blank? ? 'eng' : language_code} - #{language_name.nil? ? 'Unknown (ignoring)' : language_name}"
        end
      end

      if @options.skip_subtitles != true && @options.download_subtitles && media.subtitle_streams.empty? && @adapter.list_files(media.original_filename.gsub(/.{4}$/, '.*srt')).empty?
        @adapter.search_subtitles(media, @options.languages)
        @adapter.download_subtitles(media, @options.languages)
      end

      @adapter.extract_subtitles(media, @options.languages) if !@options.skip_subtitles && media.subtitle_streams.any? && media.needs_transcoding?

      if @options.skip_transcoding || @adapter.transcode(media, @options.languages)
        @adapter.add_subtitles(media) unless @options.skip_subtitles

        unless @options.skip_metadata || @options.skip_online_metadata
          media.imdb_id ||= @options.imdb_id
          media.tvdb_id ||= @options.tvdb_id
          @adapter.get_metadata(media)
        end

        @adapter.tag media                   unless @options.skip_metadata
        @adapter.clean_up media              unless @options.skip_cleanup
        @adapter.rename_to_plex_format media if @options.plex_format
        @adapter.add_to_itunes media         if @options.add_to_itunes
      end

      media.update_data_file!
    end

    private

      def apply_options_to_media!(media)
        # Load IMDB id from options
        media.imdb_id ||= @options.imdb_id
        media.tvdb_id ||= @options.tvdb_id

        media.season = @options.season if @options.season
        media.use_absolute_episode_numbering = @options.use_absolute_numbering
        media.episode_number_padding = @options.episode_number_padding if @options.episode_number_padding
      end
  end
end
