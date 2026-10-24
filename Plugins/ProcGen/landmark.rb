module ProcWild
  class Landmark
    attr_reader :name
    attr_reader :description
    attr_reader :location

    def initialize(name, description, location)
      @name = name
      @description = description
      @location = location
    end
  end
end