require 'spec_helper'
require 'puppet/type/check_mk_agent'

RSpec.describe 'the check_mk_agent type' do
  it 'loads' do
    expect(Puppet::Type.type(:check_mk_agent)).not_to be_nil
  end
end
