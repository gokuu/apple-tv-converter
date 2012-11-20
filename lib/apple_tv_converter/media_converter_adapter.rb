module AppleTvConverter
  class MediaConverterAdapter
    def extract_subtitles(media)
      printf "* Extracting subtitles"
      media.mkv_data.extract_subtitles(File.dirname(media.original_filename)) do |progress|
        printf "\r" + (" " * 40)
        printf "\r  * Progress: #{progress}%%"
      end
      printf "\r" + (" " * 40)
      puts "\r  * Progress: [DONE]"
    end

    def transcode(media)
      if convert?(media)
        puts "* Encoding"

        options = get_transcode_options(media)

        # Better video and audio transcoding quality
        if convert_video?(media) || convert_audio?(media)
          options[:custom] = ''
          options[:custom] << ' -mbd rd -flags +mv4+aic -trellis 2 -cmp 2 -subcmp 2 -g 300 -pass 1 -qscale 1' if convert_video?(media)
          options[:custom] << ' -ac 6 -ar 48000 -ab 448k -vol 512' if convert_audio?(media)
        end

        transcoded = media.ffmpeg_data.transcode(media.converted_filename, options) do |progress|
          printf "\r" + (" " * 40)
          printf %Q[\r* Encoding Progress: #{(progress * 100).round(2)}%%]
        end

        status = transcoded.valid?

        printf "\r" + (" " * 40)

        if status
          puts "\r* Encoding: [DONE]#{' ' * 20}"
        else
          puts "\r* Encoding: [ERROR]#{' ' * 20}"
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

    def tag(media)
      raise NotImplementedYetException
    end

    def add_to_itunes(media)
      raise NotImplementedYetException
    end

    def clean_up(media)
      printf "* Cleaning up"
      begin
        FileUtils.rm(media.original_filename) unless media.original_filename == media.converted_filename
        FileUtils.rm_r list_files(media.original_filename.gsub(File.extname(media.original_filename), '*.srt'))
        puts " [DONE]"
      rescue
        puts " [ERROR]"
      end
    end

    protected

      def list_files(ls)
        raise NotImplementedYetException
      end

      def convert_audio?(media)
        return media.ffmpeg_data.audio_codec !~ /(?:ac3|aac)/i
      end

      def convert_video?(media)
        return media.ffmpeg_data.video_codec !~ /.*(?:h264|mpeg4).*/i || media.ffmpeg_data.video_codec =~ /.*(?:xvid|divx).*/i
      end

      def convert?(media)
        !(media.is_valid? && media.is_mp4?)# && !convert_video?(media) && !convert_audio?(media))
      end

      def has_subtitles?(media)
        list_files(File.join(File.dirname(media.original_filename), '*.srt')).any?
      end

      def get_transcode_options(media)
        raise NotImplementedYetException
      end

  end
end