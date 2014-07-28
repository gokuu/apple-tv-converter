module AppleTvConverter
  class MediaConverterMacAdapter < MediaConverterAdapter
    def add_subtitles(media)
      puts "* Adding external subtitles"

      if has_subtitles?(media)
        list_files(media.original_filename.gsub(File.extname(media.original_filename), '*.srt')).map do |subtitle_filename|
          subtitle_filename =~ /\.(\w{3})\.srt$/i
          language_code = $1 || 'und'

          language_name = AppleTvConverter.get_language_name(language_code)

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

      metadata['Name'] = media.metadata.name
      metadata['Genre'] = media.metadata.genre
      metadata['Description'] = media.metadata.description
      metadata['Release Date'] = media.metadata.release_date
      metadata['Director'] = media.metadata.director
      metadata['Screenwriters'] = media.metadata.screenwriters
      metadata['Artwork'] = media.metadata.artwork
      metadata['Sort Name'] = media.metadata.sort_name
      metadata['HD Video'] = true if media.hd?
      metadata['Media Kind'] = media.is_tv_show_episode? ? 'TV Show' : 'Movie'

      if media.is_tv_show_episode?
        metadata['TV Show'] = media.metadata.tv_show
        metadata['TV Season'] = media.metadata.tv_show_season
        metadata['TV Episode #'] = media.metadata.tv_show_episode
        metadata['TV Network'] = media.metadata.tv_network

        metadata['Sort Album'] = media.metadata.sort_album
        metadata['Sort Album Artist'] = media.metadata.sort_album_artist
        metadata['Sort Composer'] = media.metadata.sort_composer
        metadata['Sort TV Show'] = media.metadata.sort_show
      end


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