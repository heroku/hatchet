# removes the commands from strings retrieved from stuff like `heroku run bash`
# since likely you care about the output, not the input
# this is especially useful for seeing if a given input command has finished running
# if we cannot find a valid input command and output command return the full unparsed string
module Hatchet
  class CommandParser
    attr_accessor :command

    def initialize(command)
      @command = command
      @parsed_string = ""
      @raw_string    = ""
    end

    def regex
      /#{Regexp.quote(command)}\r*\n+/
    end

    def parse(string)
      @raw_string    = string
      @parsed_string = string.split(regex).last
      return self
    end

    def to_s
      @parsed_string || @raw_string
    end

    def missing_valid_output?
      !has_valid_output?
    end

    def has_valid_output?
      return false unless @raw_string.match(regex)
      return false if @parsed_string.blank? || @parsed_string.strip.blank?
      true
    end
  end
end
