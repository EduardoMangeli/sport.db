# encoding: utf-8

###
#  to run use
#     ruby -I ./lib -I ./test test/test_assoc_reader.rb
#  or better
#     rake -I ./lib test


require 'helper'

class TestAssocReader < MiniTest::Unit::TestCase

  def setup
    WorldDb.delete!
    SportDb.delete!
    PersonDb.delete!
  end

  def test_models
    assert_equal 0, Assoc.count
    assert_equal 0, Team.count
    assert_equal 0, AssocTeam.count

    uefa = Assoc.create!( key: 'uefa', title: 'UEFA' )
    assert_equal 1, Assoc.count

    at  = Country.create!( key: 'at', name: 'Austria', code: 'AUT', pop: 1, area: 1)
    aut = Team.create!( key: 'aut', title: 'Austria', code: 'AUT', country_id: at.id )
    assert_equal 1, Team.count
    assert_equal 0, AssocTeam.count

    uefa.teams << aut
    assert_equal 1, AssocTeam.count
    assert_equal 1, uefa.teams.count
    assert_equal 1, aut.assocs.count

    it  = Country.create!( key: 'it', name: 'Italy', code: 'ITA', pop: 1, area: 1)
    ita = Team.create!( key: 'ita', title: 'Italy', code: 'ITA', country_id: it.id )
    assert_equal 2, Team.count

    uefa.teams << ita
    assert_equal 2, AssocTeam.count
    assert_equal 2, uefa.teams.count
    assert_equal 1, ita.assocs.count

    oefb = Assoc.create!( key: 'oefb', title: 'Oesterr. Fussballbund' )
    assert_equal 2, Assoc.count

    oefb.teams << aut
    assert_equal 3, AssocTeam.count
    assert_equal 1, oefb.teams.count
    assert_equal 2, aut.assocs.count
  end


  def test_assocs
    reader = AssocReader.new( SportDb.test_data_path )
    reader.read( 'national-teams/assocs' )

    assert_equal 20, Assoc.count
    
    fifa = Assoc.find_by_key!( 'fifa' )
    
    assert_equal 'Fédération Internationale de Football Association (FIFA)', fifa.title
    assert_equal 1904, fifa.since
    assert_equal 'www.fifa.com', fifa.web

    uefa = Assoc.find_by_key!( 'uefa' )

    assert_equal 'Union of European Football Associations (UEFA)', uefa.title
    assert_equal 1954, uefa.since
    assert_equal 'www.uefa.com', uefa.web
  end  # method test_assocs


  def test_teams
    assocreader = AssocReader.new( SportDb.test_data_path )
    assocreader.read( 'national-teams/assocs' )

    assert_equal 20, Assoc.count
    
    ## add countries
    countries = [['mx', 'Mexico', 'MEX'],
                 ['us', 'United States', 'USA'],
                 ['ca', 'Canada', 'CAN'],
                 ['dz', 'Algeria', 'ALG'],
                 ['eg', 'Egypt', 'EGY'],
                 ['au', 'Australia', 'AUS'],
                 ['nz', 'New Zealand', 'NZL'],
                 ['ki', 'Kiribati', 'KIR'],
                 ['tv', 'Tuvalu',  'TUV']]

    countries.each do |country|
      Country.create!( key:  country[0],
                       name: country[1],
                       code: country[2],
                       pop: 1,
                       area: 1)
    end

    teamreader = TeamReader.new( SportDb.test_data_path )
    teamreader.read( 'national-teams/teams' )

    assert_equal 9, Team.count
    
    fifa = Assoc.find_by_key!( 'fifa' )
    assert_equal 7, fifa.teams.count

    ofc = Assoc.find_by_key!( 'ofc' )
    assert_equal 3, ofc.teams.count

    mex = Team.find_by_key!( 'mex' )
    assert_equal 3, mex.assocs.count

    tuv = Team.find_by_key!( 'tuv' )
    assert_equal 1, tuv.assocs.count
    
    ### fix/todo: run teamreader again!! (2nd run)
    ##   assert no new assocs (just update existing)

  end  # method test_teams


end # class TestAssocReader
