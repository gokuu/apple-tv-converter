module AppleTvConverter
  class MediaConverter
    @@timeout = 200

    def initialize(options)
      @options = options
      @adapter = AppleTvConverter.is_windows? ? AppleTvConverter::MediaConverterWindowsAdapter.new : AppleTvConverter::MediaConverterMacAdapter.new

      AppleTvConverter.logger.level = Logger::ERROR
      FFMPEG.logger.level = Logger::ERROR
      FFMPEG::Transcoder.timeout = 300
    end

    def process_media(media)
      # Load IMDB id from options
      media.imdb_id ||= @options.imdb_id


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
      if media.imdb_id
        puts "* IMDB ID: #{media.imdb_id}"
      elsif @options.check_imdb && !@options.skip_metadata
        puts "* IMDB ID: Unknown yet"
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
        @adapter.download_subtitles(media, @options.languages)
      end

      @adapter.extract_subtitles(media, @options.languages) if !@options.skip_subtitles && media.subtitle_streams.any? && media.needs_transcoding?

      if @options.skip_transcoding || @adapter.transcode(media, @options.languages)
        @adapter.add_subtitles(media) unless @options.skip_subtitles

        unless @options.skip_metadata || !@options.check_imdb
          media.imdb_id ||= @options.imdb_id
          @adapter.get_metadata(media)
        end

        @adapter.tag media                   unless @options.skip_metadata
        @adapter.clean_up media              unless @options.skip_cleanup
        @adapter.rename_to_plex_format media if @options.plex_format
        @adapter.add_to_itunes media         if @options.add_to_itunes
      end

      media.update_data_file!
    end
  end
end
