module AppleTvConverter
  class MediaConverterMacAdapter < MediaConverterAdapter
    def add_subtitles(media)
      puts "* Adding external subtitles"

      if has_subtitles?(media)
        list_files(media.original_filename.gsub(File.extname(media.original_filename), '*.srt')).map do |subtitle_filename|
          subtitle_filename =~ /\.(\w{3})\.srt$/i
          language_code = $1 || 'und'

          language_name = get_language_name(language_code)

          command_line = [
            Shellwords.escape(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 'SublerCLI'))),
            %Q[-source "#{subtitle_filename}" ],
            %Q[-language "#{language_name}" ],
            %Q[-dest "#{media.converted_filename}"]
          ].join(' ')

          AppleTvConverter.logger.debug "Executing:"
          AppleTvConverter.logger.debug command_line

          printf "  * Adding #{language_name} subtitles"

          if RUBY_VERSION =~ /^1\.8/
            output, error = Open3.popen3(command_line) { |stdin, stdout, stderr| [ stdout.read, stderr.read ] }
            puts error.strip == '' || error =~ /guessed encoding/i ? " [DONE]" : " [ERROR] #{error}"
          else
            output, error, exit_status = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| [ stdout.read, stderr.read, wait_thr.value ] }
            if exit_status.exitstatus == 0
              puts" [DONE]"
            else
              puts " [ERROR]"
              puts command_line
            end
          end
        end
      else
        puts "  * No subtitles found"
      end
    end

    def tag(media)
      metadata = {}

      if media.is_tv_show_episode? && media.tvdb_movie
        # ap [media.tvdb_movie[:show][:series], media.tvdb_movie[:episode]]
        metadata['Name'] = media.tvdb_movie_data('EpisodeName')
        metadata['Name'] ||= "#{media.show} S#{media.season.to_s.rjust(2, '0')}E#{media.number.to_s.rjust(2, '0')}"
        metadata['Genre'] = media.tvdb_movie[:show][:series]['Genre'].gsub(/(?:^\|)|(?:\|$)/, '').split('|').first rescue nil
        metadata['Description'] = media.tvdb_movie_data('Overview')
        metadata['Release Date'] = media.tvdb_movie_data('FirstAired')
        metadata['Director'] = media.tvdb_movie_data('Director')
        metadata['TV Show'] = media.tvdb_movie[:show][:series]['SeriesName']
        metadata['TV Show'] ||= media.show
        metadata['TV Season'] = media.tvdb_movie_data('SeasonNumber')
        metadata['TV Season'] ||= media.season
        metadata['TV Episode #'] = media.tvdb_movie_data('EpisodeNumber')
        metadata['TV Episode #'] ||= media.number
        metadata['TV Network'] ||= media.tvdb_movie[:show][:series]['Network']
        metadata['Screenwriters'] = media.tvdb_movie_data('Writer').gsub(/(?:^\|)|(?:\|$)/, '').split('|').join(', ') if media.tvdb_movie_data('Writer')

        if media.imdb_movie
          # Fallback to IMDB data if present
          metadata['Genre'] ||= media.imdb_movie.genres.first if media.imdb_movie.genres && media.imdb_movie.genres.any?
          metadata['Description'] ||= media.imdb_movie.plot if media.imdb_movie.plot
          metadata['Release Date'] ||= media.imdb_movie.year if media.imdb_movie.year > 0
          metadata['Director'] ||= media.imdb_movie.director.first
        end

        if File.exists?(media.tvdb_movie_poster)
          AppleTvConverter.copy media.tvdb_movie_poster, media.artwork_filename
          metadata['Artwork'] = media.artwork_filename
        end
      else
        if media.imdb_movie
          unless media.is_tv_show_episode?
            metadata['Name'] = media.imdb_movie.title.gsub(/"/, '\\"')
          end
          metadata['Genre'] = media.imdb_movie.genres.first.gsub(/"/, '\\"')
          metadata['Description'] = media.imdb_movie.plot.gsub(/"/, '\\"') if media.imdb_movie.plot
          metadata['Release Date'] = media.imdb_movie.year if media.imdb_movie.year
          metadata['Director'] = (media.imdb_movie.director.first || '').gsub(/"/, '\\"') if media.imdb_movie.director.any?
          metadata['Codirector'] = media.imdb_movie.director[1].gsub(/"/, '\\"') if media.imdb_movie.director.length > 1

          if media.imdb_movie.poster
            AppleTvConverter.copy media.imdb_movie.poster, media.artwork_filename
            metadata['Artwork'] = media.artwork_filename
          end
        end

        # Overwrite the name and genre to group the episode correctly
        if media.is_tv_show_episode?
          metadata['Name'] = "#{media.show} S#{media.season.to_s.rjust(2, '0')}E#{media.number.to_s.rjust(2, '0')}"
          # metadata['Genre'] = media.genre
          metadata['TV Show'] = media.show
          metadata['TV Season'] = media.season
          metadata['TV Episode #'] = media.number
        elsif !media.imdb_movie
          metadata['Name'] = media.show
          metadata['Genre'] = media.genre
        end
      end

      metadata['HD Video'] = true if media.hd?
      metadata['Media Kind'] = media.is_tv_show_episode? ? 'TV Show' : 'Movie'

      metadata = metadata.map do |key, value|
        value.nil? ? nil : %Q[{#{key}: #{value.to_s.gsub(/"/, '\\"')}}]
      end.compact.join

      command_line = [
        Shellwords.escape(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 'SublerCLI'))),
        %Q[-metadata "#{metadata}"],
        %Q[-dest "#{media.converted_filename}"]
      ].join(' ')

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line

      printf "* Tagging"

      if RUBY_VERSION =~ /^1\.8/
        output, error = Open3.popen3(command_line) { |stdin, stdout, stderr| [ stdout.read, stderr.read ] }
        puts error.strip == '' ? " [DONE]" : " [ERROR]"
      else
        output, error, exit_status = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| [ stdout.read, stderr.read, wait_thr.value ] }
        puts exit_status.exitstatus == 0 ? " [DONE]" : " [ERROR]"
      end

      return output.strip.empty?
    end

    def add_to_itunes(media)
      printf "* Adding to iTunes"

      command_line = [
        'osascript',
        '-e',
        %Q['tell application "iTunes" to set results to (every file track of playlist "Library" whose name equals "#{media.name}")']
      ].join(' ')

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line
      output, exit_status = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| [ stdout.read, wait_thr.value ] }

      if output.strip.blank?
        # Blank result means the file isn't in the library
        command_line = [
          'osascript <<EOF',
          'tell application "iTunes"',
          %Q[add POSIX file "#{media.resulting_filename.gsub(/"/, '\\"')}"],
          'end tell',
          'EOF'
        ].join("\n")

        AppleTvConverter.logger.debug "Executing:"
        AppleTvConverter.logger.debug command_line
        output, exit_status = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| [ stdout.read, wait_thr.value ] }

        puts ' [DONE]'
      else
        puts ' [NOT NECESSARY]'
      end

      return true
    end

    def list_files(ls)
      `ls -1 #{Shellwords.escape(ls).gsub(/\\\*/, '*')} 2>/dev/null`.split("\n")
    end
  end
end