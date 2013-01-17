module AppleTvConverter
  class MediaConverterAdapter
    include AppleTvConverter

    def extract_subtitles(media)
      puts "* Extracting subtitles"
      media.mkv_data.extract_subtitles(File.dirname(media.original_filename)) do |progress|
        printf "\r" + (" " * 40)
        printf "\r  * Progress: #{progress}%%"
      end
      printf "\r" + (" " * 40)
      puts "\r  * Progress: [DONE]"
    end

    def transcode(media)
      if media.needs_transcoding?
        puts "* Encoding"

        options = {}
        options[:codecs] = get_transcode_options(media)
        options[:files] = ""
        options[:metadata] = ""
        options[:map] = ""
        options[:extra] = ""

        # Better video and audio transcoding quality
        if media.needs_video_conversion?
          options[:extra] << ' -mbd rd -flags +mv4+aic -trellis 2 -cmp 2 -subcmp 2 -g 300 -pass 1 -q:v 1 -r 23.98'
        end

        if media.needs_audio_conversion?
          options[:extra] << " -vol 512" # Increase the volume when transcoding
          options[:extra] << " -ac #{media.ffmpeg_data.audio_channels} -ar #{media.ffmpeg_data.audio_sample_rate} -ab 448k" if media.ffmpeg_data.audio_codec =~ /mp3/i
          # options << " -q:a 1" if media.ffmpeg_data.audio_codec =~ /ac3/i
        end

        # If the file is a MKV file, map all tracks when transcoding
        if media.is_mkv?
          media.mkv_data.tracks.each do |track|
            options[:map] << " -map 0:#{track.mkv_info_id}"
            options[:metadata] << " -metadata:s:#{track.mkv_info_id} language=#{track.language}" if ['audio', 'subtitle', 'subtitles'].include?(track.type)
          end

          last_stream_id = media.mkv_data.tracks.length - 1
        else
          options[:map] << " -map 0:0 -map 0:1"
          last_stream_id = 1
        end

        # Load any external subtitle files
        last_file_id = 0
        Dir["#{media.original_filename.gsub(/.{4}$/, '.*srt')}"].each do |subtitle_file|
          last_file_id += 1
          last_stream_id += 1

          subtitle_language = (subtitle_file.match(/\.(.{3})\.srt$/) || ['unk'])[1]
          options[:files] << " -i #{Shellwords.escape(subtitle_file)}"
          options[:metadata] << " -metadata:s:#{last_stream_id} language=#{subtitle_language}"
          options[:map] << " -map #{last_file_id}:0"
        end

        # Set metadata tags
        if media.is_tv_show_episode?
          options[:metadata] << %Q[ -metadata title="#{media.show} S#{media.season.to_s.rjust(2, '0')}E#{media.number.to_s.rjust(2, '0')}"]
          options[:metadata] << %Q[ -metadata genre="#{media.genre}"]
          options[:metadata] << %Q[ -metadata show="#{media.show}"]
        else
          options[:metadata] << %Q[ -metadata title="#{media.show}"]
          options[:metadata] << %Q[ -metadata genre="#{media.quality} Movies"]
        end

        options = "#{options[:files]} #{options[:codecs]} #{options[:map]} #{options[:metadata]} #{options[:extra]}"

        transcoded = nil

        begin
          transcoded = media.ffmpeg_data.transcode(media.converted_filename, options) do |progress|
            printf "\r" + (" " * 40)
            printf %Q[\r  * Progress: #{(progress * 100).round(2)}%%]
          end
        rescue Interrupt
          puts "\nProcess canceled!"
          exit!
        end

        status = transcoded.valid?

        printf "\r" + (" " * 40)

        if status
          puts "\r  * Progress: [DONE]#{' ' * 20}"
        else
          puts "\r  * Progress: [ERROR]#{' ' * 20}"
          exit!
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
        if media.needs_transcoding?
          FileUtils.rm media.original_filename

          if media.converted_filename_equals_original_filename?
            FileUtils.mv media.converted_filename, media.original_filename
          end

          FileUtils.rm(media.artwork_filename) if File.exists?(media.artwork_filename)
          FileUtils.rm_r list_files(media.original_filename.gsub(File.extname(media.original_filename), '*.srt'))
        end

        puts " [DONE]"
      rescue
        puts " [ERROR]"
      end
    end

    protected

      def list_files(ls)
        raise NotImplementedYetException
      end

      def has_subtitles?(media)
        list_files(File.join(File.dirname(media.original_filename), '*.srt')).any?
      end

      def get_transcode_options(media)
        options =  " -vcodec #{media.needs_video_conversion? ? 'mpeg4' : 'copy'}"
        options << " -acodec #{media.needs_audio_conversion? ? 'libfaac' : 'copy'}"

        options
      end

      def load_movie_from_imdb(media)
        begin
          search = Imdb::Search.new(media.show)

          return search.movies.first if search.movies.count == 1
        rescue
        end

        return nil
      end
  end
end