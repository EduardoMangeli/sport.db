# encoding: utf-8

require 'helper'

class TestScores < MiniTest::Unit::TestCase


  def test_scores
    assert_equal [10,0], parse_scores( '10:0' )
    assert_equal [1,22], parse_scores( '1:22' )
    assert_equal [1,22], parse_scores( '1-22' )

    assert_equal [], parse_scores( '1-222' )   # do not support three digits
    assert_equal [], parse_scores( '111-0' )   # do not support three digits
    assert_equal [], parse_scores( '1:222' )   # do not support three digits
    assert_equal [], parse_scores( '111:0' )   # do not support three digits

    ## penality only
    assert_equal [-1,-1,-1,-1,3,4], parse_scores( '3-4iE' )
    assert_equal [-1,-1,-1,-1,3,4], parse_scores( '3:4iE' )

    ## extra time only - allow ?? why not ?? only allow penalty w/ missing extra time?
    ## todo/fix: issue warning or error in parser!!!
    assert_equal [-1,-1,3,4], parse_scores( '3-4nV' )
    assert_equal [-1,-1,3,4], parse_scores( '3:4nV' )

    assert_equal [1,1,3,4], parse_scores( '3:4nV 1:1' )
    assert_equal [1,1,3,4], parse_scores( '1:1 3:4nV' )

    assert_equal [1,1,-1,-1,3,4], parse_scores( '3:4iE 1:1' )
    assert_equal [1,1,-1,-1,3,4], parse_scores( '1:1 3:4iE' )
  end

private
  class Reader
    include LogUtils::Logging      # add logger
    include SportDb::FixtureHelpers
  end

  def parse_scores( line )
     reader = Reader.new
     reader.find_scores!( line )
  end

end # class TestScores