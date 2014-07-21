$LOAD_PATH.unshift File.dirname(__FILE__)

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'gems', 'streamio-ffmpeg', 'lib', 'streamio-ffmpeg'))

require 'logger'
require 'stringio'
require 'shellwords'
require 'open3'
require 'fileutils'
require 'language_list'
require 'open-uri'
require 'imdb'
require "xmlrpc/client"
require 'net/http'
require 'uri'
require 'base64'
require 'zlib'
require 'ruby-tmdb3'

module AppleTvConverter

  # Determine whether running on Windows
  #
  # @return [boolean] true if running on Windows
  def self.is_windows? ; RUBY_PLATFORM =~/.*?mingw.*?/i ; end
  # Determine whether running on Mac OS X
  #
  # @return [boolean] true if running on Mac OS X
  def self.is_macosx? ; RUBY_PLATFORM =~/.*?darwin.*?/i ; end

  # AppleTvConverter logs information about its progress when it's transcoding.
  # Jack in your own logger through this method if you wish to.
  #
  # @param [Logger] log your own logger
  # @return [Logger] the logger you set
  def self.logger=(log)
    @logger = log
  end

  # Get AppleTvConverter logger.
  #
  # @return [Logger]
  def self.logger
    return @logger if @logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    @logger = logger
  end

  # Set the path of the mp4box binary.
  # Can be useful if you need to specify a path such as /usr/local/bin/mp4box
  #
  # @param [String] path to the mp4box binary
  # @return [String] the path you set
  def self.mp4box_binary=(bin)
    @mp4box_binary = bin
  end

  # Get the path to the mp4box binary, defaulting to 'MP4Box'
  #
  # @return [String] the path to the mp4box binary
  def self.mp4box_binary
    @mp4box_binary.nil? ? 'MP4Box' : @mp4box_binary
  end

  # Set the path of the atomic parsley binary.
  # Can be useful if you need to specify a path such as /usr/local/bin/atomic_parsley
  #
  # @param [String] path to the atomic parsley binary
  # @return [String] the path you set
  def self.atomic_parsley_binary=(bin)
    @atomic_parsley_binary = bin
  end

  # Get the path to the atomic_parsley binary, defaulting to 'AtomicParsley'
  #
  # @return [String] the path to the atomic_parsley binary
  def self.atomic_parsley_binary
    @atomic_parsley_binary.nil? ? 'AtomicParsley' : @atomic_parsley_binary
  end

  def self.copy(from, to)
    open(from) do |f|
      File.open(to, "wb") do |file|
        file.puts f.read
      end
    end
  end

  def self.data_path()
    @data_path ||= File.expand_path(File.join('~', 'Library', 'Application Support', 'apple-tv-converter')) if is_macosx?
    @data_path
  end

  def self.get_language_name(language_code)
    return language_code if language_code.length > 3

    # ??? - English
    # ara - Arabic
    # bul - Bulgarian
    # chi - Chilean? -> ignore?
    # cze - Czech -> ces
    # dan - Danish
    # dut - Dutch -> nld
    # eng - English
    # est - Estonian
    # fin - Finnish
    # fre - French -> fra
    # ger - German -> deu
    # gre - Greek -> ell
    # heb - Hebrew
    # hrv - Croatian
    # hun - Hungarian
    # ice - Icelandic -> isl
    # ita - Italian
    # jpn - Japanese
    # kor - Korean
    # lav - Latvian
    # lit - Lithuanian
    # may - Malay? -> ignore?
    # nor - Norwegian
    # pol - Polish
    # por - Portuguese
    # rum - Romanian -> ron
    # rus - Russian
    # slv - Slovenian
    # spa - Spanish
    # srp - Serbian
    # swe - Swedish
    # tha - Thai
    # tur - Turkish
    # ukr - Ukrainian
    language_code_mappings = {
      '' => 'eng',
      'chi' => nil,
      'cze' => 'ces',
      'dut' => 'nld',
      'fre' => 'fra',
      'ger' => 'deu',
      'gre' => 'ell',
      'ice' => 'isl',
      'rum' => 'ron',
      'may' => nil
    }

    language_code = language_code_mappings.has_key?(language_code) ? language_code_mappings[language_code] : language_code

    return nil if language_code.nil?

    language = ::LanguageList::LanguageInfo.find_by_iso_639_3(language_code)

    return language.name unless language.nil?
    return nil
  end
end

require 'apple_tv_converter/version'
require 'apple_tv_converter/io_patch'
require 'apple_tv_converter/filename_parser'
require 'apple_tv_converter/command_line'
require 'apple_tv_converter/media_converter'
require 'apple_tv_converter/media'
require 'apple_tv_converter/movie_hasher'
require 'apple_tv_converter/subtitles_fetcher/opensubtitles'
require 'apple_tv_converter/tv_db_fetcher'
require 'apple_tv_converter/media_converter_adapter'
require 'apple_tv_converter/media_converter_windows_adapter' if RUBY_PLATFORM =~ /(win|w)(32|64)$/
require 'apple_tv_converter/media_converter_mac_adapter' if RUBY_PLATFORM =~ /(darwin)/
