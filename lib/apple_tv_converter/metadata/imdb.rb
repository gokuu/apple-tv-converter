module AppleTvConverter
  module Metadata
    class Imdb
      def self.get_metadata(media, interactive = true, language = 'en')
        printf "* Getting info from IMDB" if interactive

        metadata_id = media.get_metadata_id(:imdb, :show)

        if !metadata_id
          search = ::Imdb::Search.new(media.show)

          search.movies.delete_if do |item|
            item.title.strip =~ /(?:(?:\(TV\s*(?:Movie|(?:Mini.?)?Series|Episode))|(?:Video(?:\s*Game)?))/i
          end

          metadata_id = if search.movies.length > 1 && interactive
            choice = 0
            puts "\n  *"
            while true
              puts %Q[  | Several movies found, choose the intended one#{" (showing only the first 20 of #{search.movies.length} results)" if search.movies.length > 20}:]

              search.movies[0...20].each_with_index do |item, index|
                puts "  | #{(index + 1).to_s.rjust(search.movies.length.to_s.length)} - #{item.title.strip} (id: #{item.id})"
                if item.also_known_as.any?
                  akas = item.also_known_as[0...5].each do |aka|
                    puts "  | #{' '.rjust(search.movies.length.to_s.length)}   AKA: #{(aka.is_a?(Hash) ? aka[:title] : aka).strip}"
                  end
                end
              end

              printf "  |\n  *- What's your choice (1..#{[search.movies.length, 20].min})? "
              choice = STDIN.gets.chomp.to_i

              break if choice.between?(1, [search.movies.length, 20].min)

              puts "  | Invalid choice!"
              puts "  |"
            end

            printf "  * Getting info from IMDB"
            search.movies[choice - 1].id
          else
            search.movies.first.id rescue nil
          end
        end

        # begin
          if metadata_id
            imdb_movie = ::Imdb::Movie.new(metadata_id)

            media.metadata.name = imdb_movie.title.gsub(/"/, '"')
            media.metadata.genre = imdb_movie.genres.first.gsub(/"/, '"') if imdb_movie.genres.any?
            media.metadata.description = imdb_movie.plot.gsub(/"/, '"') if imdb_movie.plot
            media.release_date = imdb_movie.year if imdb_movie.year
            media.metadata.director = (imdb_movie.director.first || '').gsub(/"/, '"') if imdb_movie.director.any?
            media.metadata.codirector = imdb_movie.director[1].gsub(/"/, '"') if imdb_movie.director.length > 1
            media.metadata.artwork = imdb_movie.poster if imdb_movie.poster

            media.set_metadata_id :imdb, :show, metadata_id

            puts " [DONE]" if interactive
          end
        # rescue OpenURI::HTTPError => e
        #   media.set_metadata_id :imdb, :show, nil
        #   media.imdb_movie = nil
        #   puts (e.message =~ /404/ ? " [NOT FOUND]" : " [ERROR]") if interactive
        # rescue
        #   if media.get_metadata_id(:imdb, :show).nil?
        #     puts " [NOT FOUND]" if interactive
        #   else
        #     raise e
        #   end
        # end
      end
    end
  end
end