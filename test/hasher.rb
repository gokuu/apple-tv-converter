require 'test/unit'
require './lib/apple_tv_converter'

class MovieHasherTest < Test::Unit::TestCase
  def test_compute_hash
    assert_equal("8e245d9679d31e12", AppleTvConverter::MovieHasher::compute_hash(File.join(File.dirname(__FILE__), 'data','breakdance.avi')))
  end

  def test_compute_hash_large_file
    assert_equal("2a527d74d45f5b1b", AppleTvConverter::MovieHasher::compute_hash(File.join(File.dirname(__FILE__), 'data','dummy.rar')))
  end
end