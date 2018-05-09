require 'rspec'
require_relative '../test/test_helper'
# require 'ft-ffi'
require 'library'

include FT::Wrapper

RSpec.describe Library do

  subject { Library.new }

  describe '::new' do
    it "Shouldn't raise an error" do
      expect { subject }.not_to raise_error
    end
  end

  describe '#new_face' do
    let(:filepathname) { "C:\\Windows\\Fonts\\arial.ttf" }
    it 'should return a new face' do
      face = subject.new_face(filepathname)
      expect(face).to be_a Face
      LOGGER.debug face
    end
  end

  describe '#version' do
    it 'should return an array' do
      expect(subject.version).to be_a Array
    end

    it 'should be higher than 0' do
      expect(subject.version.first).to be > 0
    end

    it 'should be a string' do
      expect(subject.version(format: :string)).to be_a String
    end
  end

  describe '#number_of_modules' do
    it 'should be a number' do
      expect(subject.number_of_modules).to be_a Numeric
    end
  end

  describe '#reference_count' do
    it 'should be a number' do
      expect(subject.reference_count).to be_a Numeric
    end
  end

  describe '#renderers' do
    it '' do
      expect(subject.renderers).to be_a ListRec
    end
  end

  describe '#current_renderer' do
    it '' do
      expect(subject.current_renderer).to be_a RendererRec
    end
  end
end