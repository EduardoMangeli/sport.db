# encoding: utf-8

###
# NB: for local testing run like:
#
# 1.9.x: ruby -Ilib lib/sportdb.rb

# core and stlibs  (note: get included via worlddb gem; see worlddb gem/lib)


require 'fileutils'


# rubygems  / 3rd party libs

require 'active_record'
require 'activerecord/utils' # check - if dependency on logutils? or props? etc let others go first
# fix: move activerecord/utils to world db - no need to require here again

require 'worlddb'
require 'persondb'

require 'logutils/db'   # NB: explict require required for LogDb (NOT automatic)
# fix: move to world db  -- no need to require here


require 'fetcher'   # for fetching/downloading fixtures via HTTP/HTTPS etc.

# our own code

require 'sportdb/version'    # let version always go first

require 'sportdb/patterns'
require 'sportdb/models/forward'
require 'sportdb/models/world/city'
require 'sportdb/models/world/country'
require 'sportdb/models/world/continent'
require 'sportdb/models/world/region'
require 'sportdb/models/assoc'
require 'sportdb/models/assoc_assoc'
require 'sportdb/models/badge'
require 'sportdb/models/event'
require 'sportdb/models/event_ground'
require 'sportdb/models/event_team'
require 'sportdb/models/game'
require 'sportdb/models/goal'
require 'sportdb/models/ground'
require 'sportdb/models/group'
require 'sportdb/models/group_team'
require 'sportdb/models/league'
require 'sportdb/models/person'
require 'sportdb/models/roster'
require 'sportdb/models/round'
require 'sportdb/models/season'
require 'sportdb/models/team'
require 'sportdb/models/team_comp'


require 'sportdb/models/stats/alltime_standing'
require 'sportdb/models/stats/alltime_standing_entry'
require 'sportdb/models/stats/event_standing'
require 'sportdb/models/stats/event_standing_entry'
require 'sportdb/models/stats/group_standing'
require 'sportdb/models/stats/group_standing_entry'

require 'sportdb/models/utils'   # e.g. GameCursor


require 'sportdb/schema'       # NB: requires sportdb/models (include SportDB::Models)

require 'sportdb/finders/date'
require 'sportdb/finders/scores'

require 'sportdb/utils'
require 'sportdb/utils_date'
require 'sportdb/utils_group'
require 'sportdb/utils_map'
require 'sportdb/utils_round'
require 'sportdb/utils_scores'
require 'sportdb/utils_teams'
require 'sportdb/utils_goals'
require 'sportdb/matcher'
require 'sportdb/calc'       # fix/todo: obsolete - replace w/ standings
require 'sportdb/standings'


require 'sportdb/finders/goals'   # no: requires FixturesHelpers

require 'sportdb/readers/assoc'
require 'sportdb/readers/event'
require 'sportdb/readers/game'
require 'sportdb/readers/ground'
require 'sportdb/readers/league'
require 'sportdb/readers/season'
require 'sportdb/readers/squad_club'    # roster
require 'sportdb/readers/squad_national_team'
require 'sportdb/readers/team'
require 'sportdb/reader'
require 'sportdb/reader_file'
require 'sportdb/reader_zip'



require 'sportdb/lang'

require 'sportdb/deleter'
require 'sportdb/stats'


module SportDb

  def self.config_path
    "#{root}/config"
  end

  def self.data_path
    "#{root}/data"
  end

  def self.test_data_path
    "#{root}/test/data"
  end


  def self.lang
    # todo/fix: find a better way for single instance ??
    #  will get us ruby warning:  instance variable @lang not initialized   => find a better way!!!
    #   just use @lang w/o .nil?  e.g.
    #  @lang =|| Lang.new   why? why not??  or better use @@lang =|| Lang.new  for class variable!!!
     if @lang.nil?
       @lang = Lang.new
     end
     @lang
  end


  def self.main
    ## Runner.new.run(ARGV) - old code
    require 'sportdb/cli/main'
  end

  def self.create
    CreateDb.new.up
    ConfDb::Model::Prop.create!( key: 'db.schema.sport.version', value: VERSION )
  end

  def self.create_all
    ## build schema - convenience helper
    LogDb.create
    ConfDb.create
    TagDb.create
    WorldDb.create
    PersonDb.create
    SportDb.create
  end


  def self.read_setup( setup, include_path )
    reader = Reader.new( include_path )
    reader.load_setup( setup )
  end

  def self.read_setup_from_zip( zip_name, setup, include_path, opts={} ) ## todo/check - use a better (shorter) name ??
    reader = ZipReader.new( zip_name, include_path, opts )
    reader.load_setup( setup )
    reader.close
  end

  def self.read_all( include_path )   # convenience helper
    read_setup( 'setups/all', include_path )
  end

  def self.read_builtin
    read_setup( 'setups/all', data_path )
  end


  # load built-in (that is, bundled within the gem) named plain text seeds
  # - pass in an array of pairs of event/seed names e.g.
  #   [['at.2012/13', 'at/2012_13/bl'],
  #    ['cl.2012/13', 'cl/2012_13/cl']] etc.

  def self.read( ary, include_path )
    reader = Reader.new( include_path )
    ## todo: check kind_of?( Array ) or kind_of?(String) to support array or string
    ary.each do |name|
      reader.load( name )
    end
  end


  # delete ALL records (use with care!)
  def self.delete!
    puts '*** deleting sport table records/data...'
    Deleter.new.run
  end # method delete!

  def self.update!
    puts '*** update event fixtures...'
    Updater.new.run
  end


  def self.stats
    Stats.new.tables   # NOTE: same as tables (remove??? why? why not??)
  end

  def self.tables
    Stats.new.tables
  end


  def self.connect( db_config={} )

    if db_config.empty?
      puts "ENV['DATBASE_URL'] - >#{ENV['DATABASE_URL']}<"

      ### change default to ./sport.db ?? why? why not?
      db = URI.parse( ENV['DATABASE_URL'] || 'sqlite3:///sport.db' )

      if db.scheme == 'postgres'
        config = {
          adapter: 'postgresql',
          host: db.host,
          port: db.port,
          username: db.user,
          password: db.password,
          database: db.path[1..-1],
          encoding: 'utf8'
        }
      else # assume sqlite3
       config = {
         adapter: db.scheme, # sqlite3
         database: db.path[1..-1] # sport.db (NB: cut off leading /, thus 1..-1)
      }
      end
    else
      config = db_config  # use passed in config hash
    end

    ## todo/check: use if defined?( JRUBY_VERSION ) instead ??
    if RUBY_PLATFORM =~ /java/ && config[:adapter] == 'sqlite3' 
      # quick hack for JRuby sqlite3 support via jdbc
      puts "jruby quick hack - adding jdbc libs for jruby sqlite3 database support"
      require 'jdbc/sqlite3'
      require 'active_record/connection_adapters/jdbc_adapter'
      require 'active_record/connection_adapters/jdbcsqlite3_adapter'
    end

    puts "Connecting to db using settings: "
    pp config
    ActiveRecord::Base.establish_connection( config )
    # ActiveRecord::Base.logger = Logger.new( STDOUT )
  end


  def self.setup_in_memory_db

    # Database Setup & Config
    ActiveRecord::Base.logger = Logger.new( STDOUT )
    ## ActiveRecord::Base.colorize_logging = false  - no longer exists - check new api/config setting?

    self.connect( adapter:  'sqlite3',
                  database: ':memory:' )

    ## build schema
    SportDb.create_all

    ## read builtins - why? why not?
    SportDb.read_builtin
  end # setup_in_memory_db (using SQLite :memory:)


end  # module SportDb


#####
# auto-load/require some addons

## puts 'before auto-load (require) sportdb addons'
## puts '  before sportdb/update'
require 'sportdb/update'
## puts '  before sportdb/service'
require 'sportdb/service'
## puts 'after auto-load (require) sportdb addons'



if __FILE__ == $0
  SportDb.main
else
   ## say hello
  puts SportDb.banner
end
