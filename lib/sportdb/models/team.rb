
module SportDb
  module Model

##################
#  FIX: add ?
#
#   use single table inheritance STI  ????
#    - to mark two dervided classes e.g.
#    - Club           ???   - why? why not?
#    - NationalTeam   ???   - why? why not?


class Team < ActiveRecord::Base

  has_many :home_games, class_name: 'Game', foreign_key: 'team1_id'
  has_many :away_games, class_name: 'Game', foreign_key: 'team2_id'

  REGEX_KEY  = /^[a-z]{3,}$/
  REGEX_CODE = /^[A-Z][A-Z0-9][A-Z0-9_]?$/  # must start w/ letter a-z (2 n 3 can be number or underscore _)

  ## todo/fix: must be 3 or more letters (plus allow digits e.g. salzburgii, muenchen1980, etc.) - why? why not??
  validates :key,  :format => { :with => REGEX_KEY,  :message => 'expected three or more lowercase letters a-z' }
  validates :code, :format => { :with => REGEX_CODE, :message => 'expected two or three uppercase letters A-Z (and 0-9_; must start with A-Z)' }, :allow_nil => true

  has_many :event_teams, class_name: 'EventTeam'  # join table (events+teams)
  has_many :events, :through => :event_teams


  ### fix!!! - how to do it with has_many macro? use finder_sql?
  ##  finder_sql is depreciated in Rails 4!!!
  ##   keep as is! best solution ??
  ##   a discussion here -> https://github.com/rails/rails/issues/9726
  ##   a discussion here (not really helpful) -> http://stackoverflow.com/questions/2125440/activerecord-has-many-where-two-columns-in-table-a-are-primary-keys-in-table-b
  
  def games
    Game.where( 'team1_id = ? or team2_id = ?', id, id ).order( 'play_at' )
  end

  def upcoming_games
    Game.where( 'team1_id = ? or team2_id = ?', id, id ).where( 'play_at > ?', Time.now ).order( 'play_at' )
  end

  def past_games
    Game.where( 'team1_id = ? or team2_id = ?', id, id ).where( 'play_at < ?', Time.now ).order( 'play_at desc' )
  end


  has_many :badges   # Winner, 2nd, Cupsieger, Aufsteiger, Absteiger, etc.

  belongs_to :country, class_name: 'WorldDb::Model::Country', foreign_key: 'country_id'
  belongs_to :city,    class_name: 'WorldDb::Model::City',    foreign_key: 'city_id'



  def self.create_or_update_from_values( new_attributes, values )

    ## fix: add/configure logger for ActiveRecord!!!
    logger = LogKernel::Logger.root

    ## check optional values
    values.each_with_index do |value, index|
      if value =~ /^city:/   ## city:
        value_city_key = value[5..-1]  ## cut off city: prefix
        value_city = City.find_by_key( value_city_key )
        if value_city.present?
          new_attributes[ :city_id ] = value_city.id
        else
          ## todo/fix: add strict mode flag - fail w/ exit 1 in strict mode
          logger.warn "city with key #{value_city_key} missing"
          ## todo: log errors to db log??? 
        end
      elsif value =~ /^(18|19|20)[0-9]{2}$/  ## assume founding year -- allow 18|19|20
        ## logger.info "  founding/opening year #{value}"
        new_attributes[ :since ] = value.to_i
      elsif value =~ /\/{2}/  # assume it's an address line e.g.  xx // xx
        ## logger.info "  found address line #{value}"
        new_attributes[ :address ] = value
      elsif value =~ /^(?:[a-z]{2}\.)?wikipedia:/  # assume it's wikipedia e.g. [es.]wikipedia:
        logger.info "  found wikipedia line #{value}; skipping for now"
      elsif value =~ /(^www\.)|(\.com$)/  # FIX: !!!! use a better matcher not just www. and .com
        new_attributes[ :web ] = value
      elsif value =~ /^[A-Z][A-Z0-9][A-Z0-9_]?$/   ## assume two or three-letter code e.g. FCB, RBS, etc.
        new_attributes[ :code ] = value
      elsif value =~ /^[a-z]{2}$/  ## assume two-letter country key e.g. at,de,mx,etc.
        ## fix: allow country letter with three e.g. eng,sco,wal,nir, etc. !!!
        value_country = Country.find_by_key!( value )
        new_attributes[ :country_id ] = value_country.id
      else
        ## todo: assume title2 ??
        # issue warning: unknown type for value
        logger.warn "unknown type for value >#{value}< - key #{new_attributes[:key]}"
      end
    end

    rec = Team.find_by_key( new_attributes[ :key ] )
    if rec.present?
      logger.debug "update Team #{rec.id}-#{rec.key}:"
    else
      logger.debug "create Team:"
      rec = Team.new
    end
      
    logger.debug new_attributes.to_json
   
    rec.update_attributes!( new_attributes )
  end # create_or_update_from_values


  def self.create_from_ary!( teams, more_values={} )
    teams.each do |values|
      
      ## key & title required
      attr = {
        key: values[0]
      }

      ## title (split of optional synonyms)
      # e.g. FC Bayern Muenchen|Bayern Muenchen|Bayern
      titles = values[1].split('|')
      
      attr[ :title ]    =  titles[0]
      ## add optional synonyms
      attr[ :synonyms ] =  titles[1..-1].join('|')  if titles.size > 1

      
      attr = attr.merge( more_values )
      
      ## check for optional values
      values[2..-1].each do |value|
        if value.is_a? Country
          attr[ :country_id ] = value.id
        elsif value.is_a? City
          attr[ :city_id ] = value.id 
        elsif value =~ REGEX_CODE   ## assume its three letter code (e.g. ITA or S04 etc.)
          attr[ :code ] = value
        elsif value =~ /^city:/   ## city:
          value_city_key = value[5..-1]  ## cut off city: prefix
          value_city = City.find_by_key!( value_city_key )
          attr[ :city_id ] = value_city.id
        else
          attr[ :title2 ] = value
        end
      end

      ## check if exists
      team = Team.find_by_key( values[0] )
      if team.present?
        puts "*** warning team with key '#{values[0]}' exists; skipping create"
      else      
        Team.create!( attr )
      end
    end # each team
  end
  
end  # class Team
  

  end # module Model
end # module SportDb
