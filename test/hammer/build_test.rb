#!/usr/bin/env ruby

require 'rake'
require 'test_helper'
require 'tmpdir'

class BuildTest < Test::Unit::TestCase

  context "A build" do

    setup do
      @input_directory = Dir.mktmpdir()

      @build = Hammer::Build.new(
        :input_directory => @input_directory,
        :output_directory => Dir.mktmpdir(),
        :cache_directory => Dir.mktmpdir()
      )

      File.open(File.join(@input_directory, "index.html"), 'w') do |f|
        f.print('This is an HTML file')
      end
    end

    teardown do
      FileUtils.rm_rf @input_directory
    end

    should "parse" do
      assert @build.compile.keys.include? 'index.html'
    end

    should "have filenames" do
       assert_equal(["index.html"], @build.filenames)
    end
  end

end