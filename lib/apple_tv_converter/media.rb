module AppleTvConverter
  class Media
    attr_accessor :show, :season, :number, :last_number
    attr_accessor :imdb_movie, :imdb_id, :imdb_episode_id
    attr_accessor :tvdb_movie
    attr_accessor :network, :tvdb_id, :tvdb_season_id, :tvdb_episode_id, :first_air_date, :release_date, :episode_title
    attr_accessor :use_absolute_episode_numbering, :episode_number_padding
    attr_reader :original_filename

    def self.subtitle_extensions ; ['srt', 'sub', 'ssa', 'ass'] ; end

    def self.ignored_extensions ; ['nfo', 'jpg', 'png', 'bmp', 'sfv', 'imdb'] ; end

    def original_filename=(value)
      @original_filename = value

      if @original_filename =~ /.*?\.mp4$/
        Dir[@original_filename.gsub(File.extname(@original_filename), '*')].each do |file|
          if @original_filename != file && !(Media.subtitle_extensions + Media.ignored_extensions).include?(file.downcase.gsub(/.*\./, ''))
            @original_filename = file
            break
          end
        end
      end

      if converted_filename == original_filename && needs_transcoding?
        @converted_filename = original_filename.gsub(File.extname(original_filename), "_2#{File.extname(original_filename)}")
        @converted_filename_equals_original_filename = true
      end

      load_data_file

      @original_filename
    end

    def converted_filename_equals_original_filename? ; @converted_filename_equals_original_filename || false ; end

    def artwork_filename ; @artwork_filename ||= self.original_filename.gsub(File.extname(self.original_filename), '.jpg') ; end

    def subtitle_filename ; @subtitle_filename ||= self.original_filename.gsub(File.extname(self.original_filename), '.srt') ; end

    def converted_filename ; @converted_filename ||= self.original_filename.gsub(File.extname(self.original_filename), '.mp4') ; end

    def converted_filename=(value) ; @converted_filename = value ; end

    def base_location
      unless @base_location
        @base_location = File.dirname(original_filename)
        @base_location = File.dirname(@base_location) if File.basename(@base_location) =~ /^season \d+$/i
      end
      @base_location
    end

    def data_file ; @data_file ||= File.join(base_location, '.apple-tv-converter.data') ; end
    def has_data_file? ; File.exists?(data_file) ; end

    def tvdb_season_number ; @tvdb_season_number ||= media.tvdb_movie_data(@use_absolute_episode_numbering ? '1' : 'SeasonNumber') rescue nil ; end
    def tvdb_episode_number ; @tvdb_episode_number ||= media.tvdb_movie_data(@use_absolute_episode_numbering ? 'absolute_number' : 'EpisodeNumber') rescue nil ; end

    def plex_format_filename
      filename = if is_tv_show_episode?
        %Q[#{show} - s#{season.to_s.rjust(2, '0')}e#{number.to_s.rjust(episode_number_padding || 2, '0')}#{"-e#{last_number.to_s.rjust(episode_number_padding || 2, '0')}" if last_number}#{" - #{episode_title.gsub(/\\|\//, '-').gsub(/\:/, '.').gsub(/&amp;/, '&').strip}" if !episode_title.nil? && !episode_title.blank?}.mp4]
      else
        "#{show} (#{release_date || imdb_movie.year}).mp4"
      end

      File.join(File.dirname(converted_filename), filename)
    end

    def resulting_filename ; File.exists?(plex_format_filename) ? plex_format_filename : converted_filename ; end

    def backup_filename ; @backup_filename ||= "#{self.original_filename}.backup" ; end

    def converted_filename_with_subtitles ; @converted_filename_with_subtitles ||= self.original_filename.gsub(/\.(mkv|avi|m4v)/, '_subtitled.mp4') ;end

    def ffmpeg_data ; @ffmpeg_data ||= FFMPEG::Movie.new(original_filename) ; end

    def quality
      if !@quality
        @quality = '1080p' if ffmpeg_data.height == 1080 || ffmpeg_data.width == 1920
        @quality = '720p' if ffmpeg_data.height == 720 || ffmpeg_data.width == 1280
        @quality = 'Xvid' if !@quality
      end

      @quality
    end

    def genre ; is_tv_show_episode? ? show : "#{quality} Movies" ; end

    def quality=(value) ; @quality = value ; end

    def name ; %Q[#{show}#{" S#{season.to_s.rjust(2, '0')}E#{number.to_s.rjust(episode_number_padding || 2, '0')}" if is_tv_show_episode?}] ; end

    def is_tv_show_episode? ; !season.nil? && !number.nil? ; end

    def is_movie? ; !is_tv_show_episode? ; end

    def is_mp4? ; ffmpeg_data.container =~ /mp4/ rescue File.extname(original_filename) =~ /\.(m4v|mp4)$/ ; end

    def is_valid? ; ffmpeg_data.valid? ; end

    def backup! ; FileUtils.cp original_filename, backup_filename ; end

    def has_embedded_subtitles?(languages = [])
      languages = languages.map { |l| l.downcase.to_sym }
      ffmpeg_data.streams.select { |stream| stream.type == :subtitle && (languages.empty? || languages.include?(stream.language.downcase.to_sym)) }.any?
    end

    def streams(type = nil)
      @streams ||= ffmpeg_data.streams
      return @streams.select { |stream| stream.type == type } if type
      return @streams
    end

    def video_streams ; streams :video ; end

    def audio_streams ; streams :audio ; end

    def subtitle_streams ; streams :subtitle ; end

    def needs_audio_conversion? ; return ffmpeg_data.audio_codec !~ /(?:aac)/i ; end

    def needs_video_conversion? ; return ffmpeg_data.video_codec !~ /(?:.*?h264|^mpeg4).*/i || ffmpeg_data.video_codec =~ /.*(?:xvid|divx).*/i || ffmpeg_data.video_stream =~ /h264.*?yuv420p10le/i ; end

    def needs_subtitles_conversion? ; return ffmpeg_data.subtitle_streams.any? ; end

    def needs_transcoding? ; !(is_valid? && is_mp4? && !needs_video_conversion? && !needs_audio_conversion?) ; end

    def hd? ; ['1080p', '720p'].include?(quality) ; end

    def movie_file_size ; @movie_file_size ||= File.size(original_filename) ; end

    def movie_hash ; @movie_hash ||= AppleTvConverter::MovieHasher.compute_hash(original_filename) ; end

    def tvdb_movie_data(key, default = nil) ;
      return tvdb_movie[:episode][key].gsub(/`/, '') if tvdb_movie && tvdb_movie.has_key?(:episode) && tvdb_movie[:episode].has_key?(key) && !tvdb_movie[:episode][key].blank? rescue default
      return default
    end

    def tvdb_movie_poster
      local_file = AppleTvConverter::TvDbFetcher.get_poster(self)

      unless File.exists?(local_file)
        artwork_filename = imdb_movie.poster if imdb_movie && imdb_movie.poster

        AppleTvConverter.copy artwork_filename, local_file unless artwork_filename.blank?
      end

      local_file
    end

    def get_new_subtitle_filename(language, subid = nil)
      dir_name = File.dirname(original_filename)
      existing_subtitle_counter = subid.nil? ? Dir[File.join(dir_name, '*.srt')].length : subid
      return File.join(dir_name, File.basename(original_filename).gsub(File.extname(original_filename), ".#{existing_subtitle_counter}.#{language}.srt"))
    end

    def update_data_file!
      data = has_data_file? ? YAML.load_file(data_file) : {}

      data[:tvdb_id] = self.tvdb_id if self.tvdb_id
      data[:imdb_id] = self.imdb_id if self.imdb_id
      data[:episode_number_padding] = self.episode_number_padding if self.episode_number_padding
      data[:use_absolute_episode_numbering] = self.use_absolute_episode_numbering if self.use_absolute_episode_numbering

      if self.is_tv_show_episode?
        episode_data = {}
        episode_data[:tvdb_episode_id] = self.tvdb_episode_id if self.tvdb_episode_id
        episode_data[:tvdb_season_id] = self.tvdb_season_id if self.tvdb_season_id
        episode_data[:imdb_episode_id] = self.imdb_episode_id if self.imdb_episode_id

        data[:episodes] ||= {}
        data[:episodes][:"s#{self.season}e#{self.number}"] = episode_data
      end

      File.open(self.data_file, 'w') do |f|
        f.write data.to_yaml
      end
    end

    private

      def load_data_file
        begin
          if has_data_file?
            data = YAML.load_file(data_file)
            self.tvdb_id = data[:tvdb_id] if data.has_key?(:tvdb_id)
            self.imdb_id = data[:imdb_id] if data.has_key?(:imdb_id)
            @episode_number_padding = data[:episode_number_padding] if data.has_key?(:episode_number_padding)
            @use_absolute_episode_numbering = data[:use_absolute_episode_numbering] if data.has_key?(:use_absolute_episode_numbering)
          end
        rescue => e
          ap ['e', e]
        end
      end
  end
end