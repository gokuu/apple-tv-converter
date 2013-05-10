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
        begin
          response = @server.call("LogOut", get_token)
          parse_response! response
          @token = nil if response[:success]
        rescue EOFError
          logout
        rescue XMLRPC::FaultException => e
          puts "Error:"
          puts e.faultCode
          puts e.faultString
          raise e
        end
      end

      def search_subtitles(media, &block)
        options = [
          :moviehash => media.movie_hash.to_s,
          :moviebytesize => media.movie_file_size.to_s
        ]
        language_options = languages.map(&:to_s).join(',') if languages.any?

        options.first[:sublanguageid] = language_options if language_options
        response = search_for_subtitles(media, options)

        if response[:success]
          if response['data']
            Opensubtitles.subtitles[media] = response['data']
            block.call response['data'] if block
          else
            # Could not find matches by hash, try by name (and season/episode)
            options = [ :query => media.show ]

            options.first[:season] = media.season if media.is_tv_show_episode?
            options.first[:episode] = media.number if media.is_tv_show_episode?
            options.first[:sublanguageid] = language_options if language_options

            response = search_for_subtitles(media, options)

            if response[:success] && response['data']
              Opensubtitles.subtitles[media] = response['data']
              block.call response['data'] if block
            end
          end
        end
      end

      def download_subtitles(media, &block)
        data = Opensubtitles.subtitles[media]
        media_subtitles = filter_subtitles(data, media)
        block.call :search, media_subtitles if block

        # We now have only one subtitle per language code, so start downloading
        media_subtitles.each do |language_code, subtitle|
          block.call :downloading, subtitle
          download_subtitle(media, subtitle)
          block.call :downloaded, subtitle
        end
      end

      def status
        begin
          @server.call('ServerInfo')
        rescue EOFError
          status
        rescue XMLRPC::FaultException => e
          puts "Error:"
          puts e.faultCode
          puts e.faultString
        end
      end

      private

        def self.subtitles
          @@subtitles ||= {}
        end

        def logged_in? ; return !@token.nil? ; end

        def login
          begin
            response = @server.call("LogIn", '', '', '', USER_AGENT)
            parse_response! response

            @token = response['token'] if response[:success]
          rescue EOFError
            login
          rescue XMLRPC::FaultException => e
            puts "Error:"
            puts e.faultCode
            puts e.faultString
            raise e
          end
        end

        def get_token
          login unless @token
          return @token
        end

        def filter_subtitles(data, media)
          media_subtitles = data.select { |s| s['SubFormat'].downcase == 'srt' } # Filter by format
          media_subtitles = media_subtitles.select { |s| languages.empty? || languages.include?(s['SubLanguageID']) } # Filter by language

          exact_match = media_subtitles.select do |s|
            !File.basename(media.original_filename).downcase.index(s['MovieReleaseName'].downcase).nil? ||
            !File.basename(media.original_filename).downcase.index(s['SubFileName'].gsub(/\..*?$/, '').downcase).nil?
          end

          # We found exact matches on the movie name, so ignore the rest
          media_subtitles = exact_match if exact_match.any?
          # Group the subtitles by language code
          media_subtitles = media_subtitles.group_by { |a| a['SubLanguageID'] }

          # Since we can have more than one subtitle per language that matches our movie
          # order the grouped subtitles by download count (descending), and keep only
          # the first (we basically going with the majority of the people)
          return Hash[*(media_subtitles.map {|a,b| [a, b.sort { |c, d| c['SubDownloadsCnt'].to_i <=> d['SubDownloadsCnt'].to_i }.reverse.first] }).flatten]
        end

        def search_for_subtitles(media, options)
          begin
            response = @server.call("SearchSubtitles", get_token, options)
            parse_response! response

            return response
          rescue EOFError
            logout
          rescue XMLRPC::FaultException => e
            puts "Error:"
            puts e.faultCode
            puts e.faultString
            raise e
          end
        end

        def download_subtitle(media, subtitle)
          begin
            response = @server.call("DownloadSubtitles", get_token, [ subtitle['IDSubtitleFile'] ])
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
          rescue EOFError
            download_subtitle subtitle
          rescue XMLRPC::FaultException => e
            puts "Error:"
            puts e.faultCode
            puts e.faultString
            raise e
          rescue Exception => e
            puts "Error:"
            # ap e
            # ap e.message

            raise e
          end
        end

        def download(url)
          Net::HTTP.get(URI.parse(url))
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