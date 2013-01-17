module AppleTvConverter
  class MediaConverter
    include AppleTvConverter

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
      if media.is_tv_show_episode?
        puts "* TV Show Episode information:"
        puts "* Name: #{media.show}"
        puts "* Season: #{media.season}"
        puts "* Number: #{media.number}"
      else
        puts "* Movie information"
        puts "* Name: #{media.show}"
        puts "* Genre: #{media.genre}"
      end
      if media.is_mkv?
        puts "* #{media.mkv_data.tracks.select {|t| t.type == 'audio'}.length} audio track(s)"

        if media.mkv_data.tracks.select {|t| t.type == 'audio' }.any?
          media.mkv_data.tracks.select {|t| t.type == 'audio' }.each do |audio|
            language_code = audio.language || 'und'
            language_name = get_language_name(language_code)
            puts "  * #{language_code} - #{language_name.nil? ? 'Unknown (ignoring)' : language_name}"
          end
        end
        puts "* #{media.mkv_data.tracks.select {|t| ['subtitle', 'subtitles'].include?(t.type) }.length} embedded subtitle track(s)"

        if media.mkv_data.tracks.select {|t| ['subtitle', 'subtitles'].include?(t.type) }.any?
          media.mkv_data.tracks.select {|t| ['subtitle', 'subtitles'].include?(t.type) }.each do |subtitle|
            language_code = subtitle.language || 'und'
            language_name = get_language_name(language_code)
            puts "  * #{language_code} - #{language_name.nil? ? 'Unknown (ignoring)' : language_name}"
          end
        end
      end

      puts "* #{Dir["#{media.original_filename.gsub(/.{4}$/, '.*srt')}"].length} external subtitle track(s)"
      if Dir["#{media.original_filename.gsub(/.{4}$/, '.*srt')}"].any?
        Dir["#{media.original_filename.gsub(/.{4}$/, '.*srt')}"].each do |subtitle|
          subtitle =~ /\.(.{3})\.srt/i
          language_code = $1 || 'und'
          language_name = get_language_name(language_code)
          puts "  * #{language_code.blank? ? 'eng' : language_code} - #{language_name.nil? ? 'Unknown (ignoring)' : language_name}"
        end
      end

      if @adapter.transcode(media)
        # @adapter.add_subtitles(media) unless @options[:skip_subtitles] == true || !media.is_tv_show_episode?
        # @adapter.tag(media) unless @options[:skip_metadata] == true || !media.is_tv_show_episode?

        # @adapter.add_to_itunes media
        @adapter.clean_up(media) unless @options[:skip_cleanup] == true
      end
    end
  end
end