module AppleTvConverter
  class FilenameParser
    attr_accessor :tvshow_name, :season_number, :episode_number, :last_episode_number

    def initialize(path)
      @path = path
    end

    def tvshow_name
      @tvshow_name ||= parse_tvshow_name
    end

    def season_number
      @season_number ||= parse_season_number
    end

    def episode_number
      @episode_number ||= parse_episode_number
    end

    def last_episode_number
      @last_episode_number ||= parse_last_episode_number
    end

    private

    def basename
      @basename ||= File.basename(@path)
    end

    def format1_match
      # /.*?S(\d+)E(\d+)(?:(?:[-E]+(\d+))*).*?/ -> S00E01, S00E01(E02)+, S00E01(-E02)+, S00E01(-02)+
      @format1_match ||= basename.match(/.*?S(\d+)E(\d+)(?:(?:[-E]+(\d+))*).*?/i)
    end

    def format2_match
      # /(\d+)x(\d+)(?:(?:_?(?:\1)x(\d+))*)/ -> 0x01, 0x01(_0x02)+ , assuming same season number (0x01_1x02 fails!)
      @format2_match ||= basename.match(/(\d+)x(\d+)(?:(?:_?(?:\1)x(\d+))*)/i)
    end

    def parse_tvshow_name
      test_path = File.expand_path(File.basename(File.dirname(@path)) =~ /^season\s*\d+/i ? File.dirname(File.dirname(@path)) : File.dirname(@path))
      match = test_path.match(/.*\/(.*?)(?:S(\d+))?$/i)
      match[1].strip
    end

    def parse_season_number
      return format1_match[1].to_i if format1_match
      return format2_match[1].to_i if format2_match
    end

    def parse_episode_number
      return format1_match[2].to_i if format1_match
      return format2_match[2].to_i if format2_match
    end

    def parse_last_episode_number
      return format1_match[3].to_i if format1_match && format1_match[3]
      return format2_match[3].to_i if format2_match && format2_match[3]
    end
  end
end
