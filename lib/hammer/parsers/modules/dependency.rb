require 'hammer/parsers/modules/extensions'
require 'hammer/parsers/modules/file_finder'

module Hammer
  module Dependency

    include Hammer::FileFinder
    include Hammer::ExtensionMapper # needed for FileFInder. It's dumb.

    attr_accessor :dependencies, :wildcard_dependencies

    def find_file_with_dependency(tag, extension=nil)
      file = find_file(tag, extension)
      add_dependency(file)
      file
    end

    def find_files_with_dependency(tag, extension=nil)
      files = find_files(tag, extension)
      add_wildcard_dependency(tag, extension)
      files
    end

    def add_dependency(file, extension=nil)
      @dependencies ||= []
      @dependencies.push(file)
    end

    def add_wildcard_dependency(*args)
      if args[1].is_a? Array
        results = {args[0] => args[1]}
      else
        results = find_files(*args)
      end
      @wildcard_dependencies ||= {}
      @wildcard_dependencies[args[0]] = [*results]
    end

  end
end