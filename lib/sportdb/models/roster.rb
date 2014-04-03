
module SportDb
  module Model

### use LineUp, Squad for name? - alias??

class Roster < ActiveRecord::Base

  belongs_to :event
  belongs_to :team
  belongs_to :person

end  # class Roster


  end # module Model
end # module SportDb

