require 'knife-zero/version'

class TC_Version < Test::Unit::TestCase
  test 'returns version correctly' do
    assert_equal('2.2.1', Knife::Zero::VERSION)
  end
end
