require 'test_helper'

class CommandParserTest < Test::Unit::TestCase
  def test_removes_command_from_string
    hash = {command: "1+1",
            string:  "1+1\r\r\n=> 2\r\r\n",
            expect:   "=> 2\r\r\n"
           }
    cp = Hatchet::CommandParser.new(hash[:command]).parse(hash[:string])
    assert cp.has_valid_output?
    assert_equal hash[:expect], cp.to_s


    hash = {command: "ls",
            string: "Running `bash` attached to terminal... up, run.8041\r\n\e[01;34m~\e[00m \e[01;32m$ \e[00mls\r\r\napp  config\tdb   Gemfile\t   lib\tProcfile  Rakefile     script  tmp\r\r\nbin  config.ru\tdoc  Gemfile.lock  log\tpublic\t  README.rdoc  test    vendor\r\r\n",
            expect: "app  config\tdb   Gemfile\t   lib\tProcfile  Rakefile     script  tmp\r\r\nbin  config.ru\tdoc  Gemfile.lock  log\tpublic\t  README.rdoc  test    vendor\r\r\n"
           }
    cp = Hatchet::CommandParser.new(hash[:command]).parse(hash[:string])
    assert cp.has_valid_output?
    assert_equal hash[:expect], cp.to_s
  end

  def test_returns_result_if_no_command_in_result
    hash = {command: "ls",
            string:  "1+1\r\r\n=> 2\r\r\n",
            expect:  "1+1\r\r\n=> 2\r\r\n"
           }
    cp = Hatchet::CommandParser.new(hash[:command]).parse(hash[:string])
    refute cp.has_valid_output?
    assert_equal hash[:expect], cp.to_s
  end

  def test_empty_string
    hash = {command: "ls",
            string:  "",
            expect:  ""
           }
    cp = Hatchet::CommandParser.new(hash[:command]).parse(hash[:string])
    refute cp.has_valid_output?
    assert_equal hash[:expect], cp.to_s
  end


  def test_partial_command_no_result
    hash = {command: "1+1",
            string:  "1+1\r\r\n",
            expect:  "1+1\r\r\n"
           }
    cp = Hatchet::CommandParser.new(hash[:command]).parse(hash[:string])
    assert_equal hash[:expect], cp.to_s
    refute cp.has_valid_output?
  end
end

