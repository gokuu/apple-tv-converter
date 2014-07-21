module AppleTvConverter
  module Metadata
    class MovieDb
      def initialize
        # Configure the gem
        Tmdb.api_key = "t478f8de5776c799de5a"
        Tmdb.default_language = "en"
      end

      private

        def self.api_key; return '5ebb3f1009ddd14d244cbe1645b616a0' ; end
    end
  end
end

