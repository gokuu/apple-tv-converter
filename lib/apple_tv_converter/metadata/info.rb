module AppleTvConverter
  module Metadata
    class Info
      attr_accessor :name, :genre, :description, :release_date
      attr_accessor :tv_show, :tv_show_season, :tv_show_episode, :tv_network
      attr_accessor :screenwriters, :director, :codirector
      attr_accessor :artwork_filename

      def initialize(media)
        @media = media
      end

      def artwork ; @media.artwork_filename ; end
      def artwork=(value) ; AppleTvConverter.copy value, @media.artwork_filename ; end

      def sort_name ; return @media.is_tv_show_episode? ? "#{tv_show} S#{tv_show_season.to_s.rjust(2, '0')}E#{tv_show_episode.to_s.rjust(2, '0')}" : name ; end
      def sort_album ; return tv_show ; end
      def sort_album_artist ; return tv_show ; end
      def sort_composer ; return tv_show ; end
      def sort_show ; return "#{tv_show} Season #{tv_show_season.to_s.rjust(2, '0')}" ; end
    end
  end
end