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
            puts exit_status.exitstatus == 0 ? " [DONE]" : " [ERROR]"
          end
        end
      else
        puts "  * No subtitles found"
      end
    end

    def tag(media)
      metadata = ''

      if media.imdb_movie
        unless media.is_tv_show_episode?
          metadata << %Q[{Name: #{media.imdb_movie.title.gsub(/"/, '\\"')}}]
          metadata << %Q[{Genre: #{media.imdb_movie.genres.first.gsub(/"/, '\\"')}}]
        end
        metadata << %Q[{Description: #{media.imdb_movie.plot.gsub(/"/, '\\"')}}] if media.imdb_movie.plot
        metadata << %Q[{Release Date: #{media.imdb_movie.year}}]
        metadata << %Q[{Director: #{(media.imdb_movie.director.first || '').gsub(/"/, '\\"')}}]
        metadata << %Q[{Codirector: #{media.imdb_movie.director[1].gsub(/"/, '\\"')}}] if media.imdb_movie.director.length > 1

        if media.imdb_movie.poster
          open(media.imdb_movie.poster) do |f|
            File.open(media.artwork_filename,"wb") do |file|
              file.puts f.read
            end
          end

          metadata << %Q[{Artwork: #{media.artwork_filename}}]
        end
      end

      metadata << %Q[{HD Video: true}] if media.hd?

      # Overwrite the name and genre to group the episode correctly
      if media.is_tv_show_episode?
        metadata << %Q[{Name: #{media.show} S#{media.season.to_s.rjust(2, '0')}E#{media.number.to_s.rjust(2, '0')}}]
        metadata << %Q[{Genre: #{media.genre}}]
        metadata << %Q[{TV Show: #{media.show}}]
        metadata << %Q[{TV Season: #{media.season}}]
        metadata << %Q[{TV Episode #: #{media.number}}]
      elsif !media.imdb_movie
        metadata << %Q[{Name: #{media.show}}]
        metadata << %Q[{Genre: #{media.genre}}]
      end

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