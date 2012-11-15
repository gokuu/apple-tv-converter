$LOAD_PATH.unshift File.dirname(__FILE__)

require 'logger'
require 'stringio'
require 'shellwords'
require 'open3'
require 'streamio-ffmpeg'
require 'mkv'
require 'awesome_print'
require 'fileutils'
require 'language_list'

require 'apple_tv_converter/version'
require 'apple_tv_converter/io_patch'
require 'apple_tv_converter/command_line'
require 'apple_tv_converter/media_converter'
require 'apple_tv_converter/media'
require 'apple_tv_converter/media_converter_adapter'
require 'apple_tv_converter/media_converter_windows_adapter' if RUBY_PLATFORM =~ /(win|w)(32|64)$/
require 'apple_tv_converter/media_converter_mac_adapter' if RUBY_PLATFORM =~ /(darwin)/

module AppleTvConverter
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
end
