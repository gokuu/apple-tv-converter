module AppleTvConverter
  class Media
    attr_accessor :show, :season, :number, :genre
    attr_reader :original_filename, :quality

    def original_filename=(value)
      @original_filename = value

      if @original_filename =~ /.*?\.m4v$/
        if File.exists?(@original_filename.gsub(/\.m4v/, '.avi'))
          @original_filename = @original_filename.gsub(/\.m4v/, '.avi')
        elsif File.exists?(@original_filename.gsub(/\.m4v/, '.mkv'))
          @original_filename = @original_filename.gsub(/\.m4v/, '.mkv')
        end
      end
    end

    def subtitle_filename
      @subtitle_filename ||= self.original_filename.gsub(/\.(mkv|avi|mp4)/, '.srt')
    end

    def converted_filename
      @converted_filename ||= self.original_filename.gsub(/\.(mkv|avi)/, '.m4v')
    end

    def converted_filename_with_subtitles
      @converted_filename_with_subtitles ||= self.original_filename.gsub(/\.(mkv|avi|mp4)/, '_subtitled.m4v')
    end

    def ffmpeg_data
      @ffmpeg_data ||= FFMPEG::Movie.new(original_filename)
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
      ffmpeg_data.container =~ /mp4/ rescue File.extname(original_filename) =~ /\.(mp4|m4v)$/
    end

    def is_valid?
      ffmpeg_data.valid?
    end
  end
end