module AppleTvConverter
  class MediaConverterWindowsAdapter < MediaConverterAdapter
    require 'win32ole'

    def handbrake_location
      return File.expand_path("./HandBrakeCLI#{'_x64' if is_windows_64bit?}.exe")
    end

    def atomic_parsley_location
      return File.expand_path('./AtomicParsley.exe')
    end

    def clean_up_command_line(command_line)
      return command_line.gsub(/\//, '\\')
    end
    
    def add_to_itunes(episode)
      printf "* Adding to iTunes"
      @itunes ||= WIN32OLE.new("iTunes.Application")
      @itunes.PlayFile(episode.converted_filename)
      @itunes.Stop

      puts " [DONE]"
    end

    def line_ending
    end

    def execute_command(command_line, &block)
      `#{command_line}`
    end

    private

      def is_windows_32bit?
        !is_windows_64bit?
      end

      def is_windows_64bit?
        ENV.has_key?('ProgramFiles(x86)')
      end
  end
end