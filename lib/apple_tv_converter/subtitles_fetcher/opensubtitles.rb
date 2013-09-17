module AppleTvConverter
  module SubtitlesFetcher
    class Opensubtitles
      attr_reader :languages, :token

      def initialize(languages)
        @languages = languages
        @server = XMLRPC::Client.new(SERVER, PATH, PORT)
        @token = nil

        if block_given?
          begin
            yield self
          rescue
            raise
          ensure
            logout
          end
        end
      end

      def logout
        response = make_call("LogOut", get_token)
        parse_response! response
        @token = nil if response[:success]
      end

      def search_subtitles(media, &block)
        language_options = languages.map(&:to_s).join(',') if languages.any?
        options = []

        # Query by movie hash
        options << {
          :moviehash => media.movie_hash.to_s,
          :moviebytesize => media.movie_file_size.to_s
        }
        # Query by movie name
        options << { :query => media.show }
        # and IMDB id if present
        options.last[:imdb_id] = media.imdb_id if media.imdb_id

        # Add common options
        options.each do |query_option|
          query_option[:sublanguageid] = language_options if language_options
          query_option[:season] = media.season if media.is_tv_show_episode?
          query_option[:episode] = media.number if media.is_tv_show_episode?
        end

        response = search_for_subtitles(media, options)
        if response[:success] && response['data']
          Opensubtitles.subtitles[media] = response['data']
          block.call response['data'] if block
        end
      end

      def has_found_subtitles?(media)
        (Opensubtitles.subtitles[media] && Opensubtitles.subtitles[media].any?) == true
      end

      def download_subtitles(media, &block)
        return unless has_found_subtitles? media

        data = Opensubtitles.subtitles[media]
        media_subtitles = filter_subtitles(data, media)

        # If we have subtitles matched by moviehash, get only the first and ignore the rest
        # otherwise, get all
        media_subtitles = Hash[*media_subtitles.map { |language, subs| [language, [ subs.detect { |s| s['MatchedBy'] } || subs ].flatten ] }.flatten(1) ]

        block.call :search, media_subtitles if block

        # We now have one or many subtitles per language code, so start downloading
        media_subtitles.each do |language_code, subtitles|
          subtitles.each do |subtitle|
            block.call :downloading, subtitle
            download_subtitle(media, subtitle)
            block.call :downloaded, subtitle
          end
        end
      end

      def status
        make_call('ServerInfo')
      end

      private

        def self.subtitles
          @@subtitles ||= {}
        end

        def logged_in? ; return !@token.nil? ; end

        def login
          response = make_call("LogIn", '', '', '', USER_AGENT)
          parse_response! response

          @token = response['token'] if response[:success]
        end

        def get_token
          login unless @token
          return @token
        end

        def normalize(string) ; return string.gsub(/[^0-9a-z ]/i, '').gsub(/\s+/, ' ').downcase.strip ; end

        def filter_subtitles(data, media)
          # "MatchedBy" -> "moviehash"
          # "MatchedBy" -> "imdbid"
          # "MatchedBy" -> "fulltext"

          # Define priorities by match type
          data.each do |s|
            s[:priority] = case s['MatchedBy']
              when 'moviehash'  then 100
              when 'imdbid'     then 200
              when 'fulltext'   then 300
              else                   400
            end
          end


          # Order the subtitles first by lowest priority (my match)
          # and then by download count (descending). This way, we'll get the
          # best, top downloaded match on top
          media_subtitles = data.sort { |c, d| [d[:priority], c['SubDownloadsCnt'].to_i] <=> [c[:priority], d['SubDownloadsCnt'].to_i] }.reverse


          # Get only unique subtitle entries (we can have more than one)
          # due to different 'MatchedBy'
          media_subtitles = media_subtitles.uniq { |s| s['IDSubtitle'] }

          # Filter by subtitles format (srt)
          media_subtitles = media_subtitles.select { |s| s['SubFormat'].downcase == 'srt' }
          # Filter by number of discs (1)
          media_subtitles = media_subtitles.select { |s| s['SubSumCD'] == '1' }
          # Filter by language
          media_subtitles = media_subtitles.select { |s| languages.empty? || languages.include?(s['SubLanguageID']) }
          # Filter by movie name (unless it's an episode, as the movie name can be the episode's title)
          media_subtitles = media_subtitles.select { |s| s['MatchedBy'] == 'moviehash' || normalize(s['MovieName']) == normalize(media.show) } unless media.is_tv_show_episode?

          # exact_match = media_subtitles.select do |s|
          #   !File.basename(media.original_filename).downcase.index(s['MovieReleaseName'].downcase).nil? ||
          #   !File.basename(media.original_filename).downcase.index(s['SubFileName'].gsub(/\..*?$/, '').downcase).nil?
          # end

          # # We found exact matches on the movie name, so ignore the rest
          # media_subtitles = exact_match if exact_match.any?

          # Group the subtitles by language code
          media_subtitles = media_subtitles.group_by { |a| a['SubLanguageID'] }

          all_subtitles = Hash[*media_subtitles.flatten(1)]

          return all_subtitles
        end

        def search_for_subtitles(media, options)
          response = make_call("SearchSubtitles", get_token, options)
          parse_response! response

          return response
        end

        def download_subtitle(media, subtitle)
          response = make_call("DownloadSubtitles", get_token, [ subtitle['IDSubtitleFile'] ])
          parse_response! response

          if response[:success]
            data = response['data']

            if data
              data.each do |subtitle_data|
                # Decode Base64 encoded gzipped data
                zip_data = Base64.decode64(subtitle_data['data'])
                # UnGZip it
                unzipped_data = Zlib::GzipReader.new(StringIO.new(zip_data)).read
                # Write it to a new file
                File.open(media.get_new_subtitle_filename(subtitle['SubLanguageID'], subtitle_data['idsubtitlefile']), 'wb') { |file| file.write(unzipped_data) }
              end
            end
          end
        end

        def download(url)
          Net::HTTP.get(URI.parse(url))
        end

        def make_call(function, *parameters)
          do_make_call function, 0, parameters
        end

        def do_make_call(function, retries, *parameters)
          begin
            # Flatten the parameters to the correct depth
            @server.call(*[function, parameters.flatten(1)].flatten(1))
          rescue EOFError => e
            if retries < 3
              # retry
              puts "Error (EOFError): retrying"
              do_make_call function, retries + 1, *parameters
            else
              puts "Error (EOFError): retried 3 times, giving up"
              raise e
            end
          rescue XMLRPC::FaultException => e
            puts "Error (XMLRPC::FaultException):"
            puts e.faultCode
            puts e.faultString
            raise e
          rescue Exception => e
            raise e
          end
        end


        def parse_response!(response)
          # Clear the token in case of some errors
          @token = nil if response['status'] =~ /^(?:401|406|411|414|415)/i
          response[:success] = !(response['status'] =~ /^(?:200|206)/).nil?
        end

        # STATUS CODES
        # 200 OK
        # 206 Partial content; message
        # 301 Moved (host)
        # 401 Unauthorized
        # 402 Subtitles has invalid format
        # 403 SubHashes (content and sent subhash) are not same!
        # 404 Subtitles has invalid language!
        # 405 Not all mandatory parameters was specified
        # 406 No session
        # 407 Download limit reached
        # 408 Invalid parameters
        # 409 Method not found
        # 410 Other or unknown error
        # 411 Empty or invalid useragent
        # 412 %s has invalid format (reason)
        # 413 Invalid ImdbID
        # 414 Unknown User Agent
        # 415 Disabled user agent
        # 503 Service Unavailable

        SERVER = 'api.opensubtitles.org'
        PORT = 80
        PATH = '/xml-rpc'
        USER_AGENT = "AppleTvConverter v#{AppleTvConverter::VERSION}"
    end
  end
end