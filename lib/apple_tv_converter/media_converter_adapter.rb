module AppleTvConverter
  class MediaConverterAdapter
    def extract_subtitles(media)
      printf "* Extracting subtitles"
      media.mkv_data.extract_subtitles(File.dirname(media.original_filename)) do |progress|
        printf "\r  * Progress: #{progress}%%"
      end
      puts "\r  * Progress: [DONE]"
    end

    def transcode(media)
      if convert?(media)
        puts "* Encoding"

        options = {
          :video_codec => convert_video?(media) ? 'mpeg4' : 'copy',
          :audio_codec => convert_audio?(media) ? 'libfaac' : 'copy'
        }

        options[:custom] = "-qscale 1" if convert_video?(media)

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
        return media.ffmpeg_data.video_codec !~ /.*(?:mpeg4).*/i
      end

      def convert?(media)
        !(media.is_valid? && media.is_mp4?)# && !convert_video?(media) && !convert_audio?(media))
      end

      def has_subtitles?(media)
        list_files(File.join(File.dirname(media.original_filename), '*.srt')).any?
      end

  end
end