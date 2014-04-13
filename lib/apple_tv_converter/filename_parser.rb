module AppleTvConverter
  class FilenameParser
    attr_accessor :show, :season, :number, :last_number

    def initialize(path)
      @path = path

      self.show = parse_show
    end

    def show
      @show ||= parse_show
    end

    private

    def parse_show
      test_path = File.expand_path(File.basename(File.dirname(@path)) =~ /^season\s*\d+/i ? File.dirname(File.dirname(@path)) : File.dirname(@path))
      match = test_path.match(/.*\/(.*?)(?:S(\d+))?$/i)
      match[1].strip
    end

    def parse_season
    end

    def parse_number
    end

    def parse_last_number
    end
  end
end
