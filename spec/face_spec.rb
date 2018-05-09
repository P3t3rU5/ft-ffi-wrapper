require 'rspec'
require_relative '../test/test_helper'
require 'library'
require 'face'

include FT::Wrapper

RSpec.describe Face do
  subject { Library.new.new_face("C:\\Windows\\Fonts\\arial.ttf") }

  describe '#char_index' do
    it 'should be 0 for first char' do

    end
  end

  describe '#set_char_size' do
    it do
      subject.set_char_size(height: 12)
    end
  end


end
