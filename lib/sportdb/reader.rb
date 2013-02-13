# encoding: utf-8

module SportDB

class Reader

## make models available in sportdb module by default with namespace
#  e.g. lets you use Team instead of Models::Team 
  include SportDB::Models


  def initialize( logger=nil )
    if logger.nil?
      @logger = LogUtils::Logger.new
      ## @logger = Logger.new(STDOUT)
      ## @logger.level = Logger::INFO
    else
      @logger = logger
    end
  end

  attr_reader :logger

  def run( opts, args )
 
    args.each do |arg|
      name = arg     # File.basename( arg, '.*' )

      if opts.event.present?
        load_fixtures_with_include_path( opts.event, name, opts.data_path )
      else
        ary = []
        ary << name
        load_with_include_path( ary, opts.data_path )
      end
    end

  end


  def load_setup_with_include_path( setup, include_path )
    ary = load_fixture_setup_with_include_path( setup, include_path )
    load_with_include_path( ary, include_path )
  end # method load_setup_with_include_path


  ## fix/todo: rename ??
  def load_fixture_setup_with_include_path( name, include_path )
    
   ## todo/fix: cleanup quick and dirty code
    
    path = "#{include_path}/#{name}.yml"

    logger.info "parsing data '#{name}' (#{path})..."

    text = File.read_utf8( path )
    
    hash = YAML.load( text )
    
    ### build up array for fixtures from hash
    
    ary = []
    
    hash.each do |key_wild, value_wild|
      key   = key_wild.to_s.strip
      
      logger.debug "yaml key:#{key_wild.class.name} >>#{key}<<, value:#{value_wild.class.name} >>#{value_wild}<<"
    
      if value_wild.kind_of?( String ) # assume non-event data
        ary << value_wild
      elsif value_wild.kind_of?( Array ) # assume non_event data as array of strings
        ary = ary + value_wild
      elsif value_wild.kind_of?( Hash )  # assume event data
        
        value_wild.each do |event_key, event_values|
          # e.g.
          #  at.2012/13: at/2012_13/bl, at/2012_13/bl2
          #  becomes
          # [ 'at.2012/13', 'at/2012_13/bl', 'at/2012_13/bl2' ]
          ary << ( [ event_key.to_s ] + event_values.split(',') )
        end
        
      else
        logger.error "unknow fixture type in setup (yaml key:#{key_wild.class.name} >>#{key}<<, value:#{value_wild.class.name} >>#{value_wild}<<); skipping"
      end
    
    end
    
    puts "[debug] fixture setup:"
    pp ary
    
    ary
      
  end # load_fixture_setup_with_include_path


  def load_with_include_path( ary, include_path )   # convenience helper for all-in-one reader
    
    puts "[debug] enter load_with_include_path (include_path=>>#{include_path}<<):"
    pp ary
    
    ary.each do |rec|
      if rec.kind_of?( String )
        ## assume single fixture name
        name = rec
        
        if name =~ /^seasons/
          load_seasons_with_include_path( name, include_path )
        elsif name =~ /^leagues/
          if name =~ /club/
            # e.g. leagues_club
            load_leagues_with_include_path( name, include_path, { club: true } )
          else
            # e.g. leagues
            load_leagues_with_include_path( name, include_path )
          end
        elsif name =~ /^([a-z]{2})\/teams/
          # auto-add country code (from folder structure) for country-specific teams
          #  e.g. at/teams at/teams2 de/teams etc.
          country_key = $1
          country = Country.find_by_key!( country_key )
          load_teams_with_include_path( name, include_path, { club: true, country_id: country.id } )
        elsif name =~ /\/teams/
          if name =~ /club/
            # club teams (many countries)
            # e.g. club/europe/teams
            load_teams_with_include_path( name, include_path, { club: true } )
          else
            # assume national teams
            # e.g. world/teams  amercia/teams_n
            load_teams_with_include_path( name, include_path, { national: true } )
          end
        else
          logger.error "unknown sportdb fixture type >#{name}<"
          # todo/fix: exit w/ error
        end
      else  # more than one item in record? assume fixture starting w/ event key
        
        # assume first item is key
        # assume second item is event plus fixture
        # assume option third,etc are fixtures (e.g. bl2, etc.)
        event_key      = rec[0]  # e.g. at.2012/13
        event_name     = rec[1]  # e.g. at/2012_13/bl
        fixture_names  = rec[1..-1]  # e.g. at/2012_13/bl, at/2012_13/bl2
      
        load_event_with_include_path( event_name, include_path )
        fixture_names.each do |fixture_name|
          load_fixtures_with_include_path( event_key, fixture_name, include_path )
        end
      end
      
    end # each ary
  end # method load_with_include_path


  def load_leagues_with_include_path( name, include_path, more_values={} )
    
    path = "#{include_path}/#{name}.txt"

    logger.info "parsing data '#{name}' (#{path})..."

    reader = ValuesReader.new( logger, path, more_values )

    load_leagues_worker( reader )
    
    ### todo/fix: add prop
    ### Prop.create!( key: "db.#{fixture_name_to_prop_key(name)}.version", value: "file.txt.#{File.mtime(path).strftime('%Y.%m.%d')}" )
     
  end # load_leagues_with_include_path


  def load_seasons_with_include_path( name, include_path )
    path = "#{include_path}/#{name}.yml"

    puts "*** parsing data '#{name}' (#{path})..."

    reader = HashReader.new( logger, path )

    reader.each_typed do |key, value|

      ## puts "processing event attrib >>#{key}<< >>#{value}<<..."

      if key == 'seasons'
        
        puts "#{value.class.name}: >>#{value}<<"
        
        ## nb: assume value is an array
        value.each do |item|
          season_attribs = {}
          
          season = Season.find_by_key( item.to_s.strip )

          ## check if it exists
          if season.present?
            puts "*** update season #{season.id}-#{season.key}:"
          else
            puts "*** create season:"
            season = Season.new
            season_attribs[ :key ] = item.to_s.strip
          end
          
          season_attribs[:title] = item.to_s.strip
     
          puts season_attribs.to_json
          
          season.update_attributes!( season_attribs )
        end
        
      else
        logger.error "unknown seasons key; skipping"
      end
  
    end # each key,value
    
    ### todo/fix: add prop
    ### Prop.create_from_sportdb_fixture!( name, path )
  
  end  # load_seasons_with_include_path



  def load_event_with_include_path( name, include_path )
    path = "#{include_path}/#{name}.yml"

    logger.info "parsing data '#{name}' (#{path})..."

    reader = HashReader.new( logger, path )

    event_attribs = {}

    reader.each_typed do |key, value|

      ## puts "processing event attrib >>#{key}<< >>#{value}<<..."

      if key == 'league'
        league = League.find_by_key( value.to_s.strip )

        ## check if it exists
        if league.present?
          event_attribs['league_id'] = league.id
        else
          logger.error "league with key >>#{value.to_s.strip}<< missing"
          exit 1
        end
       
      elsif key == 'season'
        season = Season.find_by_key( value.to_s.strip )

        ## check if it exists
        if season.present?
          event_attribs['season_id'] = season.id
        else
          logger.error "season with key >>#{value.to_s.strip}<< missing"
          exit 1
        end
        
      elsif key == 'start_at'
        
        if value.is_a?(DateTime) || value.is_a?(Date)
          start_at = value
        else # assume it's a string
          start_at = DateTime.strptime( value.to_s.strip, '%Y-%m-%d %H:%M' )
        end
        
        event_attribs['start_at'] = start_at
        
      elsif key == 'teams'
        
        ## assume teams value is an array
        
        team_ids = []
        value.each do |item|
          team_key = item.to_s.strip
          team = Team.find_by_key!( team_key )
          team_ids << team.id
        end
        
        event_attribs['team_ids'] = team_ids
        
      elsif key == 'team3'
        ## for now always assume false  # todo: fix - use value and convert to boolean if not boolean
        event_attribs['team3'] = false
      else
        ## todo: add a source location struct to_s or similar (file, line, col)
        logger.error "unknown event attrib; skipping attrib"
      end
  
    end # each key,value

    event = Event.find_by_league_id_and_season_id( event_attribs['league_id'], event_attribs['season_id'])

    ## check if it exists
    if event.present?
      logger.debug "*** update event #{event.id}-#{event.key}:"
    else
      logger.debug "*** create event:"
      event = Event.new
    end
    
    puts event_attribs.to_json
    
    event.update_attributes!( event_attribs )
    
    ### todo/fix: add prop
  
  end  # load_event_with_include_path


  def load_fixtures_from_string( event_key, text )  # load from string (e.g. passed in via web form)

    ## todo/fix: move code into LineReader e.g. use LineReader.fromString() - why? why not?
    reader = StringLineReader.new( logger, text )
    
    load_fixtures_worker( event_key, reader )

    ## fix add prop 
    ### Prop.create!( key: "db.#{fixture_name_to_prop_key(name)}.version", value: "file.txt.#{File.mtime(path).strftime('%Y.%m.%d')}" )  
  end

  def load_fixtures_with_include_path( event_key, name, include_path )  # load from file system
     
    path = "#{include_path}/#{name}.txt"

    puts "*** parsing data '#{name}' (#{path})..."
    
    SportDB.lang.lang = LangChecker.new.analyze( name, include_path )

    reader = LineReader.new( logger, path )
    
    load_fixtures_worker( event_key, reader )

    ## fix add prop
    ## Prop.create!( key: "db.#{fixture_name_to_prop_key(name)}.version", value: "file.txt.#{File.mtime(path).strftime('%Y.%m.%d')}" )
  end

  def load_fixtures_builtin( event_key, name ) # load from gem (built-in)
    ### todo/fix: use load_teams_with_include_path and pass in SportDB.data_path
    # see worlddb for example
    
    path = "#{SportDB.data_path}/#{name}.txt"

    puts "*** parsing data '#{name}' (#{path})..."

    reader = LineReader.new( logger, path )

    load_fixtures_worker( event_key, reader )
    
    Prop.create!( key: "db.#{fixture_name_to_prop_key(name)}.version", value: "sport.txt.#{SportDB::VERSION}" )
  end


  def load_teams_with_include_path( name, include_path, more_values={} )
    path = "#{include_path}/#{name}.txt"

    puts "*** parsing data '#{name}' (#{path})..."

    reader = ValuesReader.new( logger, path, more_values )

    load_teams_worker( reader )
    
    ## todo/fix: add prop
    ## Prop.create!( key: "db.#{fixture_name_to_prop_key(name)}.version", value: "sport.txt.#{SportDB::VERSION}" )    
  end # load_teams_with_include_path


  def load_teams_builtin( name, more_values={} )
    ## todo/fix: use load_teams_with_include_path and pass in SportDB.data_path
    path = "#{SportDB.data_path}/#{name}.txt"

    puts "*** parsing data '#{name}' (#{path})..."

    reader = ValuesReader.new( logger, path, more_values )

    load_teams_worker( reader )
    
    Prop.create!( key: "db.#{fixture_name_to_prop_key(name)}.version", value: "sport.txt.#{SportDB::VERSION}" )    
  end


private

  include SportDB::FixtureHelpers

  def load_leagues_worker( reader )

    reader.each_line do |attribs, values|

      ## check optional values
      values.each_with_index do |value, index|
        if value =~ /^club$/   # club flag
          attribs[ :club ] = true
        elsif value =~ /^[a-z]{2}$/  ## assume two-letter country key e.g. at,de,mx,etc.
          value_country = Country.find_by_key!( value )
          attribs[ :country_id ] = value_country.id
        else
          ## todo: assume title2 ??
          ## assume title2 if title2 is empty (not already in use)
          ##  and if it title2 contains at least two letter e.g. [a-zA-Z].*[a-zA-Z]
          # issue warning: unknown type for value
          logger.warn "unknown type for value >#{value}<"
        end
      end

      rec = League.find_by_key( attribs[ :key ] )
      if rec.present?
        logger.debug "update League #{rec.id}-#{rec.key}:"
      else
        logger.debug "create League:"
        rec = League.new
      end
      
      puts attribs.to_json
   
      rec.update_attributes!( attribs )

    end # each lines

  end # load_leagues_worker


  def load_teams_worker( reader )
 
    reader.each_line do |attribs, values|

      ## check optional values
      values.each_with_index do |value, index|
        if value =~ /^city:/   ## city:
          value_city_key = value[5..-1]  ## cut off city: prefix
          value_city = City.find_by_key( value_city_key )
          if value_city.present?
            attribs[ :city_id ] = value_city.id
          else
            ## todo/fix: add strict mode flag - fail w/ exit 1 in strict mode
            logger.warn "city with key #{value_city_key} missing"
            ## todo: log errors to db log??? 
          end
        elsif value =~ /^[A-Z]{3}$/  ## assume three-letter code e.g. FCB, RBS, etc.
          attribs[ :code ] = value
        elsif value =~ /^[a-z]{2}$/  ## assume two-letter country key e.g. at,de,mx,etc.
          value_country = Country.find_by_key!( value )
          attribs[ :country_id ] = value_country.id
        else
          ## todo: assume title2 ??
          # issue warning: unknown type for value
          logger.warn "unknown type for value >#{value}<"
        end
      end

      rec = Team.find_by_key( attribs[ :key ] )
      if rec.present?
        logger.debug "update Team #{rec.id}-#{rec.key}:"
      else
        logger.debug "create Team:"
        rec = Team.new
      end
      
      puts attribs.to_json
   
      rec.update_attributes!( attribs )

    end # each lines
  end # method load_teams_worker

  def load_fixtures_worker( event_key, reader )
   
    ## assume active activerecord connection
    ##
    
    ## reset cached values
    @patch_rounds  = {}
    @knockout_flag = false
    @round         = nil
    
    
    @event = Event.find_by_key!( event_key )
    
    logger.info "Event #{@event.key} >#{@event.title}<"
    
    @known_teams = @event.known_teams_table
    
    parse_fixtures( reader )
    
  end   # method load_fixtures


  def parse_group( line )
    logger.debug "parsing group line: >#{line}<"
    
    match_teams!( line )
    team_keys = find_teams!( line )
      
    title, pos = find_group_title_and_pos!( line )

    logger.debug "  line: >#{line}<"

    group_attribs = {
      title: title
    }
        
    @group = Group.find_by_event_id_and_pos( @event.id, pos )
    if @group.present?
      logger.debug "update group #{@group.id}:"
    else
      logger.debug "create group:"
      @group = Group.new
      group_attribs = group_attribs.merge( {
        event_id: @event.id,
        pos:   pos
      })
    end
      
    puts  group_attribs.to_json
   
    @group.update_attributes!( group_attribs )

    @group.teams.clear  # remove old teams
    ## add new teams
    team_keys.each do |team_key|
      team = Team.find_by_key!( team_key )
      logger.debug "  adding team #{team.title} (#{team.code})"
      @group.teams << team
    end
  end
  
  def parse_round( line )
    logger.debug "parsing round line: >#{line}<"
    pos = find_round_pos!( line )
        
    @knockout_flag = is_knockout_round?( line )

    group_title, group_pos = find_group_title_and_pos!( line )

    if group_pos.present?
      @group = Group.find_by_event_id_and_pos!( @event.id, group_pos )
    else
      @group = nil   # reset group to no group
    end

    logger.debug "  line: >#{line}<"
        
    ## NB: dummy/placeholder start_at, end_at date
    ##  replace/patch after adding all games for round
        
    round_attribs = {
      title: "#{pos}. Runde"
    }

        
    @round = Round.find_by_event_id_and_pos( @event.id, pos )
    if @round.present?
      puts "*** update round #{@round.id}:"
    else
      puts "*** create round:"
      @round = Round.new
          
      round_attribs = round_attribs.merge( {
        event_id: @event.id,
        pos:   pos,
        start_at: Time.utc('1912-12-12'),
        end_at:   Time.utc('1912-12-12')
      })
    end
        
    puts round_attribs.to_json
   
    @round.update_attributes!( round_attribs )

    ### store list of round is for patching start_at/end_at at the end
    @patch_rounds[ @round.id ] = @round.id
  end

  def parse_game( line )
    puts "parsing game (fixture) line: >#{line}<"

    pos = find_game_pos!( line )

    match_teams!( line )
    team1_key = find_team1!( line )
    team2_key = find_team2!( line )

    date  = find_date!( line )
    scores = find_scores!( line )
        
    puts "  line: >#{line}<"


    ### todo: cache team lookups in hash?

    team1 = Team.find_by_key!( team1_key )
    team2 = Team.find_by_key!( team2_key )

    ### check if games exists
    ##  with this teams in this round if yes only update
    game = Game.find_by_round_id_and_team1_id_and_team2_id(
                         @round.id, team1.id, team2.id
    )

    game_attribs = {
      score1:    scores[0],
      score2:    scores[1],
      score3:    scores[2],
      score4:    scores[3],
      score5:    scores[4],
      score6:    scores[5],
      play_at:   date,
      knockout:  @knockout_flag,
      group_id:  @group.present? ? @group.id : nil
    }

    game_attribs[ :pos ]      = pos        if pos.present?

    if game.present?
      puts "*** update game #{game.id}:"
    else
      puts "*** create game:"
      game = Game.new

      more_game_attribs = {
        round_id:  @round.id,
        team1_id: team1.id,
        team2_id: team2.id
      }
          
      ## NB: use round.games.count for pos
      ##  lets us add games out of order if later needed
      more_game_attribs[ :pos ] = @round.games.count+1  if pos.nil? 

      game_attribs = game_attribs.merge( more_game_attribs )
    end

    puts game_attribs.to_json

    game.update_attributes!( game_attribs )
  end


  def parse_fixtures( reader )
      
    reader.each_line do |line|
      if is_round?( line )
        parse_round( line )
      elsif is_group?( line ) ## NB: group goes after round (round may contain group marker too)
        parse_group( line )
      else
        parse_game( line )
      end
    end # lines.each
    
    @patch_rounds.each do |k,v|
      puts "*** patch start_at/end_at date for round #{k}:"
      round = Round.find( k )
      games = round.games.order( 'play_at asc' ).all
      
      ## skip rounds w/ no games
      
      ## todo/fix: what's the best way for checking assoc w/ 0 recs?
      next if games.size == 0
    
      round_attribs = {}
      
      ## todo: check for no records
      ##  e.g. if game[0].present? or just if game[0]  ??
      
      round_attribs[:start_at] = games[0].play_at
      round_attribs[:end_at  ] = games[-1].play_at

      puts round_attribs.to_json
      round.update_attributes!( round_attribs )
    end
    
  end # method parse_fixtures

  
end # class Reader
end # module SportDB
