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
    end

    def process_media(media)
      AppleTvConverter.logger.debug "  ** #{File.basename(media.original_filename)}"
      AppleTvConverter.logger.debug "* Video codec: #{media.ffmpeg_data.video_codec}"
      AppleTvConverter.logger.debug "* Audio codec: #{media.ffmpeg_data.audio_codec}"
      AppleTvConverter.logger.debug "* Container: #{media.ffmpeg_data.container}" rescue nil

      puts "*" * (4 + File.basename(media.original_filename).length)
      puts "* #{File.basename(media.original_filename)} *"
      puts "*" * (4 + File.basename(media.original_filename).length)

      extract_subtitles(media) if media.is_mkv? && @options[:skip_subtitles] != true

      if @adapter.transcode(media)
        @adapter.add_subtitles(media) unless @options[:skip_subtitles] == true
        @adapter.tag(media) unless @options[:skip_metadata] == true

        # @adapter.add_to_itunes media
        @adapter.clean_up(media) unless @options[:skip_cleanup] == true
      end
    end

    private

      # HELPERS
      def process_all_medias(medias)
        medias.each_with_index do |media, index|
          puts '*' * 80
          puts "* [#{(index + 1).to_s.rjust(medias.length.to_s.length, ' ')}/#{medias.length}] #{File.basename(media.original_filename)}"
          
          process_media media
        end
      end

      def process_file(file)
        puts '*' * 80
        puts "* #{file}"
        
        media = parse_filename(file)
        process_media media
      end
  end
end