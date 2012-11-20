module AppleTvConverter
  class MediaConverter
    @@timeout = 200

    def is_windows? ; RUBY_PLATFORM =~/.*?mingw.*?/i ; end
    def is_macosx? ; RUBY_PLATFORM =~/.*?darwin.*?/i ; end

    def initialize(options = {})
      @options = {
        :skip_subtitles => false,
        :skip_metadata => false,
        :skip_cleanup => false
      }.merge(options)

      @adapter = is_windows? ? AppleTvConverter::MediaConverterWindowsAdapter.new : AppleTvConverter::MediaConverterMacAdapter.new

      AppleTvConverter.logger.level = Logger::ERROR
      FFMPEG.logger.level = Logger::ERROR
      MKV.logger.level = Logger::ERROR
    end

    def process_media(media)
      AppleTvConverter.logger.debug "  ** #{File.basename(media.original_filename)}"
      AppleTvConverter.logger.debug "* Video codec: #{media.ffmpeg_data.video_codec}"
      AppleTvConverter.logger.debug "* Audio codec: #{media.ffmpeg_data.audio_codec}"
      AppleTvConverter.logger.debug "* Container: #{media.ffmpeg_data.container}" rescue nil

      @adapter.extract_subtitles(media) if media.is_mkv? && @options[:skip_subtitles] != true

      if @adapter.transcode(media)
        @adapter.add_subtitles(media) unless @options[:skip_subtitles] == true
        @adapter.tag(media) unless @options[:skip_metadata] == true

        # @adapter.add_to_itunes media
        @adapter.clean_up(media) unless @options[:skip_cleanup] == true
      end
    end
  end
end