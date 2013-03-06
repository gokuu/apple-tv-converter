module AppleTvConverter
  class MediaConverterMacAdapter < MediaConverterAdapter
    def add_subtitles(media)
      puts "* Adding external subtitles"

      if has_subtitles?(media)
        list_files(media.original_filename.gsub(File.extname(media.original_filename), '*.srt')).map do |subtitle_filename|
          subtitle_filename =~ /\.(\w{3})\.srt$/i
          language_code = $1 || 'und'

          language_name = get_language_name(language_code)

          command_line = "./SublerCLI "
          command_line << %Q[-source "#{subtitle_filename}" ]
          command_line << %Q[-language "#{language_name}" ]
          command_line << %Q[-dest "#{media.converted_filename}"]

          AppleTvConverter.logger.debug "Executing:"
          AppleTvConverter.logger.debug command_line

          printf "  * Adding #{language_name} subtitles"
          output, exit_status = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| [ stdout.read, wait_thr.value] }

          puts exit_status.exitstatus == 0 ? " [DONE]" : " [ERROR]"
        end
      else
        puts "  * No subtitles found"
      end
    end

    def tag(media)
      metadata = ''
      if media.imdb_movie
        metadata << %Q[{Name: #{media.imdb_movie.title}}]
        metadata << %Q[{Genre: #{media.imdb_movie.genres.first}}]
        metadata << %Q[{Description: #{media.imdb_movie.plot.gsub(/"/, '\\"')}}]
        metadata << %Q[{Release Date: #{media.imdb_movie.year}}]
        metadata << %Q[{Director: #{media.imdb_movie.director.first}}]
        metadata << %Q[{Codirector: #{media.imdb_movie.director[1]}}] if media.imdb_movie.director.length > 1

        if media.imdb_movie.poster
          open(media.imdb_movie.poster) do |f|
            File.open(media.artwork_filename,"wb") do |file|
              file.puts f.read
            end
          end

          metadata << %Q[{Artwork: #{media.artwork_filename}}]
        end
      end

      if media.is_tv_show_episode?
        metadata << %Q[{TV Show: #{media.show}}]
        metadata << %Q[{TV Season: #{media.season}}]
        metadata << %Q[{TV Episode #: #{media.number}}]
      end

      metadata << %Q[{HD Video: true}] if media.hd?

      if !media.imdb_movie
        if media.is_tv_show_episode?
          metadata << %Q[{Name: #{media.show} S#{media.season.to_s.rjust(2, '0')}E#{media.number.to_s.rjust(2, '0')}}]
          metadata << %Q[{Genre: #{media.genre}}]
        else
          metadata << %Q[{Name: #{media.show}}]
          metadata << %Q[{Genre: #{media.genre}}]
        end

      end

      command_line = %Q[./SublerCLI -metadata "#{metadata}" -dest "#{media.converted_filename}"]

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line

      printf "* Tagging"

      output, exit_status = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| [ stdout.read, wait_thr.value ] }

      puts exit_status.exitstatus == 0 ? " [DONE]" : " [ERROR]"

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
          %Q[add POSIX file "#{media.converted_filename.gsub(/"/, '\\"')}"],
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