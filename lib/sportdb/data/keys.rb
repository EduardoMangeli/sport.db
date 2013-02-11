# encoding: utf-8

### todo/fix: move to sportdb-data gem/plugin/addon ??


### fix: rename to ::Key (singular) - why? why not??

module SportDB::Keys

    module EventKeys
  # use constants for known keys; lets us define aliases (if things change)

  
  AT_2011_12     = 'at.2011/12'
  AT_2012_13     = 'at.2012/13'
  AT_CUP_2012_13 = 'at.cup.2012/13'
  
  CL_2012_13     = 'cl.2012/13'
  
  EURO_2008      = 'euro.2008'
  EURO_2012      = 'euro.2012'

  WORLD_2010     = 'world.2010'
  
  WORLD_QUALI_EUROPE_2014  = 'world.quali.europe.2014'
  WORLD_QUALI_AMERICA_2014 = 'world.quali.america.2014'

  ############################
  ## NB: see db/leagues.rb for keys in use
    end 
    
    include SportDB::Keys::EventKeys

end # module SportDB::Keys
