
## $:.unshift(File.dirname(__FILE__))

## minitest setup

# require 'minitest/unit'
require 'minitest/autorun'


require 'pp'


## our own code

require 'sportdb'
require 'logutils/db'   # NB: explict require required for LogDb (not automatic) 


#######################
#
#  for reuse
#   --- move to sportdb/test.rb ???
#    SportDb.setup_in_memory_db  ??? why? why not??  or
#    SportDb.setup_test_db  - alias ??



def setup_in_memory_db
  # Database Setup & Config

  db_config = {
    adapter:  'sqlite3',
    database: ':memory:'
  }

  pp db_config

  ActiveRecord::Base.logger = Logger.new( STDOUT )
  ## ActiveRecord::Base.colorize_logging = false  - no longer exists - check new api/config setting?

  ## NB: every connect will create a new empty in memory db
  ActiveRecord::Base.establish_connection( db_config )


  ## build schema

  LogDb.create
  ConfDb.create
  TagDb.create
  WorldDb.create
  PersonDb.create
  SportDb.create

  SportDb.read_builtin
end

####
# Models shortcuts

Country    = WorldDb::Model::Country

Person     = PersonDb::Model::Person

League     = SportDb::Model::League
Season     = SportDb::Model::Season
Event      = SportDb::Model::Event
Team       = SportDb::Model::Team

Round      = SportDb::Model::Round
Game       = SportDb::Model::Game
GameCursor = SportDb::Model::GameCursor

####
# Reader shortcuts

TeamReader   = SportDb::TeamReader
SeasonReader = SportDb::SeasonReader
LeagueReader = SportDb::LeagueReader
GameReader   = SportDb::GameReader


setup_in_memory_db()
