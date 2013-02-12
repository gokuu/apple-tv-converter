module AppleTvConverter
  class Media
    attr_accessor :show, :season, :number
    attr_reader :original_filename

    def self.subtitle_extensions
      ['srt', 'sub', 'ssa', 'ass']
    end

    def original_filename=(value)
      @original_filename = value

      if @original_filename =~ /.*?\.mp4$/
        Dir[@original_filename.gsub(File.extname(@original_filename), '*')].each do |file|
          if @original_filename != file && !Media.subtitle_extensions.include?(file.downcase.gsub(/.*\./, ''))
            @original_filename = file
            break
          end
        end
      end

      if converted_filename == original_filename && needs_transcoding?
        @converted_filename = original_filename.gsub(File.extname(original_filename), "_2#{File.extname(original_filename)}")
        @converted_filename_equals_original_filename = true
      end
    end

    def converted_filename_equals_original_filename?
      @converted_filename_equals_original_filename || false
    end

    def artwork_filename
      @artwork_filename ||= self.original_filename.gsub(File.extname(self.original_filename), '.jpg')
    end

    def subtitle_filename
      @subtitle_filename ||= self.original_filename.gsub(File.extname(self.original_filename), '.srt')
    end

    def converted_filename
      @converted_filename ||= self.original_filename.gsub(File.extname(self.original_filename), '.mp4')
    end

    def converted_filename=(value)
      @converted_filename = value
    end

    def converted_filename_with_subtitles
      @converted_filename_with_subtitles ||= self.original_filename.gsub(/\.(mkv|avi|m4v)/, '_subtitled.mp4')
    end

    def ffmpeg_data
      @ffmpeg_data ||= FFMPEG::Movie.new(original_filename)
    end

    def quality
      if !@quality
        @quality = '1080p' if ffmpeg_data.height == 1080 || ffmpeg_data.width == 1920
        @quality = '720p' if ffmpeg_data.height == 720 || ffmpeg_data.width == 1280
        @quality = 'Xvid' if !@quality
      end

      @quality
    end

    def genre
      is_tv_show_episode? ? show : "#{quality} Movies"
    end

    def quality=(value)
      @quality = value
    end

    def name
      %Q[#{show}#{" S#{season.to_s.rjust(2, '0')}E#{number.to_s.rjust(2, '0')}" if is_tv_show_episode?}]
    end

    def is_tv_show_episode?
      !season.nil? && !number.nil?
    end

    def is_movie?
      !is_tv_show_episode?
    end

    def is_mp4?
      ffmpeg_data.container =~ /mp4/ rescue File.extname(original_filename) =~ /\.(m4v|mp4)$/
    end

    def is_valid?
      ffmpeg_data.valid?
    end

    def has_embedded_subtitles?(languages = [])
      languages = languages.map { |l| l.downcase.to_sym }
      ffmpeg_data.streams.select { |stream| stream.type == :subtitle && (languages.empty? || languages.include?(stream.language.downcase.to_sym)) }.any?
    end

    def streams(type = nil)
      @streams ||= ffmpeg_data.streams
      return @streams.select { |stream| stream.type == type } if type
      return @streams
    end

    def video_streams
      streams :video
    end

    def audio_streams
      streams :audio
    end

    def subtitle_streams
      streams :subtitle
    end

    def needs_audio_conversion?
      return ffmpeg_data.audio_codec !~ /(?:aac)/i
    end

    def needs_video_conversion?
      return ffmpeg_data.video_codec !~ /(?:.*?h264|^mpeg4).*/i || ffmpeg_data.video_codec =~ /.*(?:xvid|divx).*/i
    end

    def needs_subtitles_conversion?
      return ffmpeg_data.subtitle_streams.any?
    end

    def needs_transcoding?
      !(is_valid? && is_mp4? && !needs_video_conversion? && !needs_audio_conversion?)
    end

    def hd?
      ['1080p', '720p'].include?(quality)
    end
  end
end