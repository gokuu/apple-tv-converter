module AppleTvConverter
  module Metadata
    class MovieDb
      def self.get_metadata(media, interactive = true, language = 'en')
        show_id = nil

        if media.get_metadata_id(:imdb, :show)
          # We have an id, assume it for the search
          show_id = media.get_metadata_id(:imdb, :show)
        else
          printf  "* Searching TheMovieDb.org "

          # Query the data
          results = search(media)
          if results
            ap ['results', results]
            puts "[DONE]"

            if results[:total_results] > 0
              if results[:total_results] == 1 || !interactive
                # Only 1 result, or non-interactive, use the first result
                show_id = results[:results].first[:id]
              else
                # More than one result, ask the user
                choice = 0
                puts "\n  *"

                while true
                  puts %Q[  | Several shows found, choose the intended one:]

                  results[:results].each_with_index do |item, index|
                    puts "  | #{(index + 1).to_s.rjust(results[:total_results].to_s.length)} - #{item[:title]} (#{Date.parse(item[:release_date]).year}) (id: #{item[:id]})"
                  end

                  printf "  |\n  *- What's your choice (1..#{results[:results].length})? "
                  choice = STDIN.gets.chomp.to_i

                  break if choice.between?(1, results[:results].length)

                  puts "  | Invalid choice!"
                  puts "  |"
                end

                show_id = results[:results][choice - 1][:id]
              end
            else
              # It's not found, return false to continue with other services
              return false
            end
          else
            puts "[ERROR]"
          end
        end

        if show_id.to_i > 0
          printf  "* Fetching metadata from TheMovieDb.org "

          # Fetch the detailed data
          data = get(show_id)

          if data
            puts "[DONE]"
            ap data
            # ap configuration
            media.metadata.name = data[:title]
            media.metadata.genre = data[:genres].first[:name]
            media.metadata.description = data[:overview]
            media.metadata.release_date = data[:release_date]
            # media.metadata.screenwriters = data[:release_date]
            # media.metadata.director = data[:release_date]
            # media.metadata.codirector = data[:release_date]
            media.metadata.artwork = poster_url(data[:poster_path])

            media.release_date = Date.parse(media.metadata.release_date).year
            media.set_metadata_id :imdb, :show, show_id

            return true
          else
            puts "[ERROR]"
          end
        end
      end

      private

        def self.api_key; return '5ebb3f1009ddd14d244cbe1645b616a0' ; end
        def self.base_url; return 'http://api.themoviedb.org/3/'; end
        def self.build_url(path, params = {}) ; return "#{base_url}#{path}" ; end
        def self.build_params(params = {}) ; return params.merge(:api_key => api_key) ; end
        def self.poster_url(extra) ; return "#{configuration[:images][:base_url]}original#{extra}" ; end

        def self.search(media) ; request 'search/movie', :query => media.show ; end
        def self.get(id) ; request("movie/#{id}", :append_to_response => 'credits') ; end
        def self.configuration ; @configuration ||= request('configuration') ; end

        def self.request(url, params = {})
          data = { :params => build_params(params), :accept => 'application/json', :block_response => true }
          begin
            return JSON.parse(RestClient.get(build_url(url), data), :symbolize_names => true, :symbolize_keys => true)
          rescue => e
            return nil
          end
        end
    end
  end
end

