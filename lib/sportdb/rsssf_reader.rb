# encoding: UTF-8

##
#
#  todo/fix: cleanup, remove stuff not needed for "simple" rsssf format/style
#
##   for now lets only support leagues with rounds (no cups/knockout rounds n groups)
##     (re)add later when needed (e.g. for playoffs etc.)


module SportDb


class RsssfGameReader

  include LogUtils::Logging

## make models available by default with namespace
#  e.g. lets you use Usage instead of Model::Usage
  include Models

## value helpers e.g. is_year?, is_taglist? etc.
  include TextUtils::ValueHelper

  include FixtureHelpers

  ##
  ## todo: add from_file and from_zip too

  def self.from_string( event_key, text )
    ### fix - fix -fix:
    ##  change event to event_or_event_key !!!!!  - allow event_key as string passed in
    self.new( event_key, text )
  end

  def initialize( event_key, text )
    ### fix - fix -fix:
    ##  change event to event_or_event_key !!!!!  - allow event_key as string passed in

    ## todo/fix: how to add opts={} ???
    @event_key         = event_key
    @text              = text
  end


  def read
    ## note: assume active activerecord connection
    @event = Event.find_by!( key: @event_key )

    logger.debug "Event #{@event.key} >#{@event.title}<"

    @team_mapper = TextUtils::TitleMapper.new( @event.teams, 'team' )

    ## reset cached values
    @patch_round_ids = []

    @last_round    = nil
    @last_date     = nil
    
    ## always use english (en) for now
    SportDb.lang.lang = 'en'

    reader = LineReader.from_string( @text )
    parse_fixtures( reader )    
  end   # method load_fixtures


  def parse_round_header( line )

    ## todo/fix:
    ##   simplify - for now round number always required
    #      e.g. no auto-calculation supported here
    #       fail if round found w/o number/pos !!!
    #
    #  also remove knockout flag for now (set to always false for now)
    
    logger.debug "parsing round header line: >#{line}<"

    ### todo/fix/check:  move cut off optional comment in reader for all lines? why? why not?
    cut_off_end_of_line_comment!( line )  # cut off optional comment starting w/ #

    ## check for date in header first e.g. Round 36 [Jul 20]  !!
    ##   avoid "conflict" with getting "wrong" round number from date etc.
    date = find_rsssf_date!( line, start_at: @event.start_at )
    if date
      @last_date = date
    end
    
    ## todo/check/fix:
    #   make sure  Round of 16  will not return pos 16 -- how? possible?
    #   add unit test too to verify
    pos = find_round_pos!( line )

    ## check if pos available; if not auto-number/calculate
    if pos.nil?
        logger.error( "  no round pos found in line >#{line}<; round pos required in rsssf; sorry" )
        fail( "round pos required in rsssf; sorry")
    end

    title = find_round_header_title!( line )

    ## Note: use extracted round title for knockout check
    ## knockout_flag = is_knockout_round?( title )

    logger.debug "  line: >#{line}<"
        
    ## Note: dummy/placeholder start_at, end_at date
    ##  replace/patch after adding all games for round

    round_attribs = {
      title:    title,
      title2:   nil,
      knockout: false
    }

    round = Round.find_by( event_id: @event.id,
                           pos:      pos )

    if round.present?
      logger.debug "update round #{round.id}:"
    else
      logger.debug "create round:"
      round = Round.new
          
      round_attribs = round_attribs.merge( {
        event_id: @event.id,
        pos:      pos,
        start_at: Date.parse('1911-11-11'),
        end_at:   Date.parse('1911-11-11')
      })
    end

    logger.debug round_attribs.to_json
   
    round.update_attributes!( round_attribs )

    ### store list of round ids for patching start_at/end_at at the end
    @patch_round_ids << round.id
    @last_round = round     ## keep track of last seen round for matches that follow etc.
  end


  def try_parse_game( line )
    # note: clone line; for possible test do NOT modify in place for now
    # note: returns true if parsed, false if no match
    parse_game( line.dup )
  end

  def parse_game( line )
    logger.debug "parsing game (fixture) line: >#{line}<"

    @team_mapper.map_titles!( line )
    team1_key = @team_mapper.find_key!( line )
    team2_key = @team_mapper.find_key!( line )

    ## note: if we do NOT find two teams; return false - no match found
    if team1_key.nil? || team2_key.nil?
      logger.debug "  no game match (two teams required) found for line: >#{line}<"
      return false
    end

    date      = find_rsssf_date!( line, start_at: @event.start_at )

    ###
    # check if date found?
    #   note: ruby falsey is nil & false only (not 0 or empty array etc.)
    if date
      @last_date = date    # keep a reference for later use
    else
      date = @last_date    # no date found; (re)use last seen date
    end

    ## fix/todo: use find_rsssf_scores!( line )
    ##   use rsssf specific score finder!!!
    scores = find_scores!( line )

    logger.debug "  line: >#{line}<"


    ### todo: cache team lookups in hash?
    team1 = Team.find_by!( key: team1_key )
    team2 = Team.find_by!( key: team2_key )

    round = @last_round

    ### check if games exists
    ##  with this teams in this round if yes only update
    game = Game.find_by( round_id: round.id,
                         team1_id: team1.id,
                         team2_id: team2.id )
                          
    game_attribs = {
      score1:    scores[0],
      score2:    scores[1],
      score1et:  scores[2],
      score2et:  scores[3],
      score1p:   scores[4],
      score2p:   scores[5],
      play_at:    date,
      play_at_v2: nil,
      postponed:  false,
      knockout:   false,  ## round.knockout, ## note: for now always use knockout flag from round - why? why not?? 
      ground_id: nil,
      group_id:  nil
    }

    if game.present?
      logger.debug "update game #{game.id}:"
    else
      logger.debug "create game:"
      game = Game.new

      ## Note: use round.games.count for pos
      ##  lets us add games out of order if later needed
      more_game_attribs = {
        round_id: round.id,
        team1_id: team1.id,
        team2_id: team2.id,
        pos:      round.games.count+1
      }
      game_attribs = game_attribs.merge( more_game_attribs )
    end

    logger.debug game_attribs.to_json
    game.update_attributes!( game_attribs )
    
    return true   # game match found
  end # method parse_game


  def try_parse_date_header( line )
    # note: clone line; for possible test do NOT modify in place for now
    # note: returns true if parsed, false if no match
    parse_date_header( line.dup )
  end

  def parse_date_header( line )
    # note: returns true if parsed, false if no match
 
    # line with NO teams  plus include date e.g.
    #   [Jun 17]  etc.

    @team_mapper.map_titles!( line )
    team1_key = @team_mapper.find_key!( line )
    team2_key = @team_mapper.find_key!( line )

    date  = find_rsssf_date!( line, start_at: @event.start_at )

    if date && team1_key.nil? && team2_key.nil?
      logger.debug( "date header line found: >#{line}<")
      logger.debug( "    date: #{date}")
      
      @last_date = date   # keep a reference for later use
      return true
    else
      return false
    end
  end



  def parse_fixtures( reader )
      
    reader.each_line do |line|

      ## fix: use inline/simpler is_rsssf_round?       
      if is_round?( line )
        parse_round_header( line )
      elsif try_parse_game( line )
        # do nothing here
      elsif try_parse_date_header( line )
        # do nothing here
      else
        logger.info "skipping line (no match found): >#{line}<"
      end
    end # lines.each

    ###########################
    # backtrack and patch round dates (start_at/end_at)

    unless @patch_round_ids.empty?
      ###
      # note: use uniq - to allow multiple round headers (possible?)

      Round.find( @patch_round_ids.uniq ).each do |r|
        logger.debug "patch round start_at/end_at date for #{r.title}:"

        ## note:
        ## will add "scope" pos first e.g
        #
        ## SELECT "games".* FROM "games"  WHERE "games"."round_id" = ?
        # ORDER BY pos, play_at asc  [["round_id", 7]]
        #   thus will NOT order by play_at but by pos first!!!
        # =>
        #  need to unscope pos!!! or use unordered_games - games_by_play_at_date etc.??
        #   thus use reorder()!!! - not just order('play_at asc')

        games = r.games.reorder( 'play_at asc' ).all

        ## skip rounds w/ no games

        ## todo/check/fix: what's the best way for checking assoc w/ 0 recs?
        next if games.size == 0

        # note: make sure start_at/end_at is date only (e.g. use play_at.to_date)
        #   sqlite3 saves datetime in date field as datetime, for example (will break date compares later!)

        round_attribs = {
          start_at: games[0].play_at.to_date,   # use games.first ?
          end_at:   games[-1].play_at.to_date  # use games.last ? why? why not?
        }

        logger.debug round_attribs.to_json
        r.update_attributes!( round_attribs )
      end
    end
  end # method parse_fixtures

end # class RsssfGameReader
end # module SportDb
