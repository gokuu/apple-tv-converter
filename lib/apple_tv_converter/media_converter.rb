module AppleTvConverter
  class MediaConverter
    @@timeout = 200

    def is_windows? ; RUBY_PLATFORM =~/.*?mingw.*?/i ; end
    def is_macosx? ; RUBY_PLATFORM =~/.*?darwin.*?/i ; end

    def initialize
      @adapter = is_windows? ? AppleTvConverter::MediaConverterWindowsAdapter.new : AppleTvConverter::MediaConverterMacAdapter.new
    end

    def process_media(media)
      AppleTvConverter.logger.debug "**** #{File.basename(media.original_filename)}"
      AppleTvConverter.logger.debug "* Video codec: #{media.ffmpeg_data.video_codec}"
      AppleTvConverter.logger.debug "* Audio codec: #{media.ffmpeg_data.audio_codec}"
      AppleTvConverter.logger.debug "* Container: #{media.ffmpeg_data.container}" rescue nil

      extract_subtitles(media) if media.is_mkv?

      if @adapter.transcode(media)
        @adapter.add_subtitles media
        @adapter.tag media

        # add_to_itunes media
        @adapter.clean_up media
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