require 'test_helper'

class ReaperTest < Test::Unit::TestCase

  def test_destroy_by_name
    heroku = mock('heroku')
    reaper = Hatchet::Reaper.new(heroku)
    heroku.expects(:delete_app).with("my-app-name")
    reaper.destroy_by_name("my-app-name")
  end

  def test_destroy_all
    heroku = stub(:get_apps =>
      stub(:body => [{
          'name' => 'hatchet-t-123',
          'created_at' => DateTime.new.to_s
        },{
          'name' => 'hatchet-t-abc',
          'created_at' => DateTime.new.to_s
        },{
          'name' => 'my-app-name',
          'created_at' => DateTime.new.to_s
        }
      ])
    )
    reaper = Hatchet::Reaper.new(heroku)
    heroku.expects(:delete_app).with('hatchet-t-123')
    heroku.expects(:delete_app).with('hatchet-t-abc')
    reaper.destroy_all
  end
end
