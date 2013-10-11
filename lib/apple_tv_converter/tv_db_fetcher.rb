module AppleTvConverter
  class TvDbFetcher
    require 'httparty'
    require 'yaml'
    require 'net/http'
    require 'zip/zip'
    require 'xml'

    include HTTParty

    base_uri 'thetvdb.com/api'

    def self.search(media, interactive = true, language = 'en')
      get_updates_from_server

      if media.tvdb_id
        show_id = media.tvdb_id
      else
        data = load_config_file('show_ids') || {}

        # http://thetvdb.com/api/GetSeries.php?seriesname=
        unless data.has_key?(media.show)
          show_ids = get_and_parse_data_from_server('show_ids', '/GetSeries.php', { :query => { :seriesname => media.show } }, ['Data', 'Series']) do |loaded_data|
            loaded_data = [loaded_data].flatten

            data[media.show] = if loaded_data.length > 1 && interactive
              choice = 0
              puts "\n  *"

              while true
                puts %Q[  | Several shows found, choose the intended one:]

                loaded_data.each_with_index do |item, index|
                  puts "  | #{(index + 1).to_s.rjust(loaded_data.length.to_s.length)} - #{item['SeriesName']} (id: #{item['seriesid']})"
                  puts "  | #{' '.rjust(loaded_data.length.to_s.length)}   AKA: #{item['AliasNames']}" if item['AliasNames']
                end

                printf "  |\n  *- What's your choice (1..#{loaded_data.length})? "
                choice = STDIN.gets.chomp.to_i

                break if choice.between?(1, loaded_data.length)

                puts "  | Invalid choice!"
                puts "  |"
              end

              loaded_data[choice - 1]['seriesid']
            else
              loaded_data.first['seriesid']
            end

            # Return the new list sorted by show name
            Hash[data.sort]
          end
        end

        show_id = data[media.show]
      end

      if show_id.to_i > 0
        # <mirrorpath_zip>/api/<apikey>/series/<seriesid>/all/<language>.zip
        show_data = get_data(show_id, "/#{api_key}/series/#{show_id}/all/#{language}.zip", { :zip => true }) do |data|
          show_data = xml_document_to_hash(XML::Document.string(data[language.to_s].gsub(/>\s*</im, '><')))
          banners = xml_document_to_hash(XML::Document.string(data['banners'].gsub(/>\s*</im, '><'))) rescue { 'Banner' => [] }
          actors = xml_document_to_hash(XML::Document.string(data['actors'].gsub(/>\s*</im, '><'))) rescue { 'Actor' => [] }

          {
            :series => show_data['Series'],
            :episodes => [show_data['Episode']].flatten,
            :banners => [banners['Banner']].flatten,
            :actors => [actors['Actor']].flatten
          }

        end

        return {
          :episode => show_data[:episodes].detect { |ep| ep['SeasonNumber'].to_i == media.season.to_i && ep['EpisodeNumber'].to_i == media.number.to_i },
          :show => show_data
        }
      end

      return false
    end

    def self.get_poster(media)
      local_file = File.join(AppleTvConverter.data_path, 'cache', 'tvdb', "#{media.tvdb_id}.jpg")

      unless File.exists?(local_file)
        artwork_filename = media.tvdb_movie[:show][:series]['poster'] || ''
        artwork_filename = media.tvdb_movie_data('filename') || '' if artwork_filename.blank?
        artwork_filename = "http://thetvdb.com/banners/#{artwork_filename}" if !artwork_filename.blank?

        AppleTvConverter.copy artwork_filename, local_file unless artwork_filename.blank?
      end

      local_file
    end

    private

      def self.api_key ; return '67FBF9F0670DBDF2' ; end
      def self.local_cache_base_path
        return File.expand_path(File.join(AppleTvConverter.data_path, 'cache', 'tvdb'))
      end
      def self.server_update_timestamp
        @server_update_timestamp ||= load_config_file('update')

        unless @server_update_timestamp
          # http://thetvdb.com/api//Updates.php?type=none
          @server_update_timestamp = get_data_from_server('/Updates.php', { :query => { :type => 'none' }})["Items"]["Time"] rescue nil
          @server_update_timestamp = @server_update_timestamp.to_i unless @server_update_timestamp.nil?
          save_config_file 'update', @server_update_timestamp
        end

        @server_update_timestamp
      end

      def self.load_config_file(filename)
        full_filename = File.join(local_cache_base_path, filename =~ /\.yml$/ ? filename : "#{filename}.yml")
        File.exists?(full_filename) ? YAML.load_file(full_filename) : nil
      end

      def self.save_config_file(filename, data)
        full_filename = File.join(local_cache_base_path, filename =~ /\.yml$/ ? filename : "#{filename}.yml")
        File.open(full_filename, 'w') { |f| f.write data.to_yaml }
      end

      def self.delete_config_file(filename)
        full_filename = File.join(local_cache_base_path, filename =~ /\.yml$/ ? filename : "#{filename}.yml")
        File.delete(full_filename) if File.exists?(full_filename)
      end


      def self.get_data_from_server(url, options = {})
        AppleTvConverter.logger.debug "  -> Getting from server: #{url}"
        cache = options.delete(:cache) || true
        zip = options.delete(:zip) || false
        response = self.get(url, options).parsed_response

        if zip
          filename = File.join(local_cache_base_path, 'zip_file.zip')

          begin
            File.open(filename, 'wb') { |f| f.write response }
            response = {}

            Zip::ZipFile.open(filename) do |zipfile|
              zipfile.each do |entry|
                unless entry.name.downcase["__macosx"]
                  zip_data = zipfile.read(entry)
                  response[entry.name.to_s.gsub(/\.xml$/i, '')] = zip_data
                end
              end
            end
          rescue => e
            ap [e, e.backtrace]

          ensure
            FileUtils.rm_f filename if File.exists?(filename)
          end
        end

        return response
      end

      def self.get_data(filename, url, url_options, response_indexes = [])
        AppleTvConverter.logger.debug "-> Getting data: #{filename}"
        data = load_config_file(filename)

        unless data
          data = get_data_from_server(url, url_options)

          if data
            begin
              response_indexes.each { |idx| data = data[idx] }

              data = yield(data) if block_given?

              save_config_file filename, data
            rescue
              data = nil
            end
          end
        else
          # ap ['found on cache', filename, data]
        end

        return data
      end

      def self.get_and_parse_data_from_server(filename, url, url_options, response_indexes = [])
        cache = url_options.delete(:cache) || true
        data = get_data_from_server(url, url_options)

        if data
          begin
            response_indexes.each { |idx| data = data[idx] }

            data = yield(data) if block_given?

            save_config_file filename, data if cache
          rescue
            data = nil
          end
        end
      end

      def self.get_updates_from_server(options = {})
        get_and_parse_data_from_server('updates', '/Updates.php', { :query => { :type => 'all', :time => load_config_file('update')}, :cache => false }, ['Items']) do |data|
          if data
            # Delete each show's cached data
            data['Series'].each do |show_id|
              delete_config_file show_id
              delete_config_file "#{show_id}.jpg"
            end

            # Save the new timestamp
            save_config_file 'update', data['Time']
            @server_update_timestamp = data['Time']
          end
        end
      end

      def self.xml_document_to_hash(document)
        def self.xml_node_to_hash(xml)
          return nil if xml.children.empty?
          return xml.children.first.to_s if xml.children.count == 1 && xml.children.first.text?

          # Append a sequential number to the name to prevent replacing items that should be in an array
          child_number = 0
          Hash[*(xml.children.map { |child| child_number += 1 ; ["#{child.name}::#{child_number}", xml_node_to_hash(child)] }.compact.flatten(1))]
        end

        intermediate_hash = xml_node_to_hash(document.root)

        return Hash[*(intermediate_hash.group_by do |obj|
          obj.first.gsub(/::\d+$/, '')
        end.map do |key, value|
          # Remove the 'key' entries
          value = value.flatten(1).delete_if { |v| v.to_s =~ /#{key}::\d+/ }

          # Remove the sequential number from the keys
          value.map! do |element|
            Hash[*(element.map do |ikey, ivalue|
              [ikey.gsub(/::\d+$/, ''), ivalue]
            end.flatten(1))]
          end

          # If there's only one entry, remove the array
          value = value.first if value.count == 1

          [key, value]
        end.flatten(1))]
      end

      FileUtils.mkdir_p local_cache_base_path

      # Load the server timestamp on startup
      server_update_timestamp
  end
end