module AppleTvConverter
  class Media
    attr_accessor :show, :season, :number
    attr_reader :original_filename

    def original_filename=(value)
      @original_filename = value

      if @original_filename =~ /.*?\.mp4$/
        if File.exists?(@original_filename.gsub(/\.mp4/, '.avi'))
          @original_filename = @original_filename.gsub(/\.mp4/, '.avi')
        elsif File.exists?(@original_filename.gsub(/\.mp4/, '.mkv'))
          @original_filename = @original_filename.gsub(/\.mp4/, '.mkv')
        end
      end
    end

    def artwork_filename
      @artwork_filename ||= self.original_filename.gsub(/\.(mkv|avi|mp4)/, '.jpg')
    end

    def subtitle_filename
      @subtitle_filename ||= self.original_filename.gsub(/\.(mkv|avi|mp4)/, '.srt')
    end

    def converted_filename
      @converted_filename ||= self.original_filename.gsub(/\.(mkv|avi)/, '.mp4')
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

    def mkv_data
      @mkv_data ||= MKV::Movie.new(original_filename)
    end

    def is_tv_show_episode?
      !season.nil? && !number.nil?
    end

    def is_movie?
      !is_tv_show_episode?
    end

    def is_mkv?
      ffmpeg_data.container =~ /matroska/i rescue File.extname(original_filename).downcase == '.mkv'
    end

    def is_mp4?
      ffmpeg_data.container =~ /mp4/ rescue File.extname(original_filename) =~ /\.(m4v|mp4)$/
    end

    def is_valid?
      ffmpeg_data.valid?
    end

    def hd?
      ['1080p', '720p'].include?(quality)
    end
  end
end