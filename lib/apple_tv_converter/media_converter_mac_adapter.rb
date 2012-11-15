module AppleTvConverter
  class MediaConverterMacAdapter < MediaConverterAdapter
    def add_subtitles(media)
      puts "* Adding subtitles"

      printf "  * Removing any previous subtitles"

      command_line = %Q[./SublerCLI -remove -dest "#{media.converted_filename}"]

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line

      output = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| stdout.read }

      puts output.strip.empty? ? " [DONE]" : (output.strip == 'Error: (null)' ? " [NONE FOUND]" : " [ERROR]")

      if has_subtitles?(media)
        list_files(File.join(File.dirname(media.original_filename), '*.srt')).map do |subtitle_filename|
          subtitle_filename =~ /(\w{3})\.srt$/
          language_code = $1 || 'eng'

          language = ::LanguageList::LanguageInfo.find_by_iso_639_3(language_code)
          language ||= ::LanguageList::LanguageInfo.find_by_iso_639_3('eng')


          command_line = "./SublerCLI "
          command_line << %Q[-source "#{subtitle_filename}" ]
          command_line << %Q[-language "#{language.name}" ]
          command_line << %Q[-dest "#{media.converted_filename}"]

          AppleTvConverter.logger.debug "Executing:"
          AppleTvConverter.logger.debug command_line

          printf "  * Adding #{language.name} subtitles"
          output = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| stdout.read }

          puts output.strip.empty? ? " [DONE]" : " [ERROR]"
        end
      else
        puts "  * No new subtitles found"
      end
    end

    def tag(media)
      metadata = ''
      metadata << %Q[{Name: #{media.show} S#{media.season.to_s.rjust(2, '0')}E#{media.number.to_s.rjust(2, '0')}}] if media.is_tv_show_episode?     
      metadata << %Q[{Name: #{media.show}}] if media.is_movie?
      metadata << %Q[{Genre: #{media.show}}{TV Show: #{media.show}}{TV Season: #{media.season}}{TV Episode #: #{media.number}}] if media.is_tv_show_episode?
      metadata << %Q[{Genre: #{media.quality} Movie}] if media.is_movie?

      command_line = %Q[./SublerCLI -metadata "#{metadata}" -dest "#{media.converted_filename}"]

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line

      printf "* Tagging"

      output = Open3.popen3(command_line) { |stdin, stdout, stderr, wait_thr| stdout.read }

      puts output.strip.empty? ? " [DONE]" : " [ERROR]"

      return output.strip.empty?
    end

    def add_to_itunes(media)
      printf "  * Adding to iTunes"

      command_line = [
        "ln -s",
        "#{media.converted_filename}".gsub(/\s/, '\ ').gsub(/\[/, '\[').gsub(/\]/, '\]'),
        "#{File.expand_path(File.join('~', 'Music', 'iTunes', 'iTunes Media', 'Automatically Add to iTunes.localized'))}".gsub(/\s/, '\ ').gsub(/\[/, '\[').gsub(/\]/, '\]')
      ].join(' ')

      AppleTvConverter.logger.debug "Executing:"
      AppleTvConverter.logger.debug command_line

      `#{command_line}`

      puts ' [DONE]'
      return true
    end

    def list_files(ls)
      `ls -1 #{ls.gsub(/\s/, '\ ').gsub(/\[/, '\[').gsub(/\]/, '\]')} 2>/dev/null`.split("\n")
    end
  end
end