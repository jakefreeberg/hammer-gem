# encoding: utf-8
$LANG = "UTF-8"

module Templatey
  def h(text)
    CGI.escapeHTML(text.to_s)
  end
end

module Hammer
  
  class Template

    attr_accessor :files

    def sort_files(files)
      return [] if files.nil?
      # This sorts the files into the correct order for display
      files.sort_by { |path, file|
        extension = File.extname(file[:output_filename]).downcase
        file[:filename]
      }.sort_by {|path, file|
        (file.include? :from_cache) ? 1 : 0
      }.sort_by {|path, file|
        file[:messages].to_a.length > 0 ? 0 : 1
      }.sort_by {|path, file|
        (file[:filename] == "index.html") ? 0 : 1
      }.sort_by {|path, file|
        file[:is_include?] ? 1 : 0
      }
    end

    def initialize(files)
      @files = sort_files(files)
    end
    
    def success?
      @files != nil and @files.length > 0 and @files.select {|path, file| file[:error]} == []
    end
    
    def to_s; raise "No such method"; end
  end
  
  class HTMLTemplate < Template
    
    def to_s
      [header, body, footer].join("\n")
    end
    
    private
    
    def header
      %Q{
        <html>
        <head>
          <meta http-equiv="Content-Type" content="text/html;charset=utf-8">
          <link href="output.css" rel="stylesheet" />
          <script src="jquery.min.js" type="text/javascript"></script>
          <script src="tabs.js" type="text/javascript"></script>
        </head>
        <body>
      }
    end
    
    def total_errors
      error_files.length rescue 0
    end
    
    def total_todos
      files.collect(&:messages).flatten.compact.length
    end
    
    def footer
      %Q{</body></html>}
    end
    
    ### Body templates
    
    def error_template(error_object)
      "
        <div class='build-error'>
          <span>Error while building!</span>
          <span>Error details:</span>
          <p>#{error_object}</p>
          <p>#{error_object && error_object.backtrace}</p>
        </div>
      "
    end
    
    def not_found_template
      "<div class='build-error not-found'><span>Folder not found</span></div>"
    end
    
    def no_files_template
      "<div class='build-error no-files'><span>No files to build</span></div>"
    end
    
    # 
    
    def todo_files
      files.select {|path, file| 
        file[:messages].to_a.length > 0
      }
    end
    
    def error_files
      files.select {|path, file| 
        file[:error]
      }.sort_by{|path, file|
        begin
          if file[:error] && file[:error][:hammer_file] != path
            100
          else
            10
          end
        rescue
          1000
        end
      }
    end
    
    def html_files
      files.select do |path, file|
        extension = File.extname(file[:output_filename])
        (['.php', '.html'].include? extension) && !file[:error]
      end.compact
    end
    
    def compilation_files
      files.select {|path, file| 
        file[:is_a_compiled_file] # && file.source_files.collect(&:error) == [] 
        }.compact
    end
    
    def css_js_files
      files.select {|path, file| 
        ['.css', '.js'].include?(File.extname(file[:output_filename])) && !file[:is_a_compiled_file] && !file[:error]
      }
    end
    
    def image_files
      files.select {|path, file| ['.png', '.gif', '.svg', '.jpg', '.gif'].include? File.extname(file[:output_filename]) }.compact
    end
    
    def other_files
      files - image_files - css_js_files - compilation_files - html_files - error_files
    end
    
    def ignored_files
      @project.ignored_files rescue []
    end
    
    def body
      
      # return error_template(@project[:error]) if @project[:error]
      
      return not_found_template if @files == nil
      return no_files_template if @files == []
      
      body = [%Q{<section id="all">}]
      
        body << %Q{<div class="error set">}
        body << "<strong>Errors</strong>"
        if error_files.any?
          body << error_files.map {|path, file| TemplateLine.new(file) }
        else
          body << '<div class="message">
            <p><b>There are no errors in your project</b></p>
          </div>'
        end
        body << %Q{</div>}
      
        body << %Q{<div class="html set">}
        body << "<strong>HTML pages</strong>"
        if html_files.any?
          body << html_files.map {|path, file| TemplateLine.new(file) if !file[:error] && !file[:include?] }
        else
          body << '<div class="message">
            <p><b>There are no HTML files in your project</b></p>
          </div>'
        end
        body << %Q{</div>}
        
        body << %Q{<div class="html includes set">}
        body << "<strong>HTML includes</strong>"
        if html_files.any?
          body << html_files.map {|path, file| TemplateLine.new(file) if !file[:error] && file[:include?] }
        else
          body << '<div class="message">
            <p><b>There are no HTML files in your project</b></p>
          </div>'
        end
        body << %Q{</div>}
      
        if compilation_files.any?
          body << %Q{<div class="optimized cssjs set">}
          body << %Q{ <strong>Optimized CSS &amp; JS</strong> }
          body << compilation_files.map {|path, file| TemplateLine.new(file) if !file[:error] }
          body << %Q{</div>}
        end
      
        body << %Q{<div class="cssjs set">}
        body << "<strong>CSS &amp; JS</strong>"
        if css_js_files.any?
          body << css_js_files.map {|path, file| TemplateLine.new(file) if !file[:error] }
        else
            body << '<div class="message">
            <p><b>There are no CSS or JS files in your project</b></p>
          </div>'
        end
        body << %Q{</div>}
      
        body << %Q{<div class="images set">}
        body << %Q{<strong>Image assets</strong>}
        if image_files.any?
          body << image_files.map {|path, file| TemplateLine.new(file)}
        else
          body << '<div class="message">
            <p><b>There are no images in your project</b></p>
          </div>'
        end
        body << %Q{</div>}
      
        body << %Q{<div class="other set">}
        body << %Q{<strong>Other files</strong>}
        if other_files.any?
          body << other_files.map {|path, file| TemplateLine.new(file)}
        else
          body << '<div class="message">
                    <p><b>There are no other files in your project</b></p>
                  </div>'
        end
        body << %Q{</div>}
      
        body << %Q{<div class="ignored set">}
        body << %Q{<strong>Ignored files</strong>}
        if ignored_files.any?
          body << ignored_files.map {|path, file| IgnoredTemplateLine.new(file)}
        else
          body << '<div class="message">
                    <p><b>There are no ignored files in your project</b></p>
                  </div>'
        end
        body << %Q{</div>}
      body << %Q{</section>}
      
      body << %Q{<section id="todos">}
      body << %Q{<strong>Todos</strong>}
      if todo_files.any?
        body << %Q{<div class="todos set"></div>}
      else
        body << '<div class="message">
                  <p><b>There are no todos in your project</b> <em>You can create a todo using <code>&lt;!-- @todo My todo --&gt;</code></em></p>
                </div>'
      end
      body << %Q{</section>}
          
      body.join("\n")
    end
    
    def files_of_type(extension)
      files.select {|path, file| File.extname(file[:output_filename]) == extension}
    rescue
      []
    end
    
    class TemplateLine
      
      include Templatey
      
      attr_reader :error, :error_file, :related_file_error_message, :error_message, :error_line
      attr_reader :extension
      
      def initialize(file)
        @file = file
        
        @error = file[:error]
        
        if file[:error] && !file[:error].is_a?(ArgumentError)
          @error_message = file[:error].text
          @error_line = file[:error].line_number
          if file[:error].hammer_file != @file
            @error_file = file[:error].hammer_file
          end
        elsif file[:error].is_a?(ArgumentError)
          @error_message = [file[:error].message, file[:error].backtrace].join(" ")
        end
        
        @filename = file[:output_filename]
        @messages = file[:messages]
        @extension = File.extname(file[:filename])[1..-1]
        @include = File.basename(file[:filename]).start_with?("_")
      end
      
      def span_class
        
        classes = []
        
        classes << "error could_not_compile" if @error_file
        classes << "optimized" if @file[:is_a_compiled_file]
        classes << "error" if @error
        classes << "include" if @include
        classes << "include" if @file[:filename].start_with? "_"
        classes << "cached" if @file[:from_cache]
        
        classes << @extension
        if ['png', 'gif', 'svg', 'jpg', 'gif'].include? @extension
          classes << 'image'
        end
        
        if @extension == "html" || @extension == "php"
          classes << "html"          
        else
          classes << "success" if @file[:compiled]
          classes << "copied"
        end
        
        classes.join(" ")
      end
            
      def link
        %Q{<a target="_blank" href="#{h @file[:output_path]}">#{@file[:output_filename]}</a>}
      end
      
      def setup_line
        if @error_file
          @line = "Error in #{@error_file[:filename]}"
        elsif @error
          lines = ["<span class=\"error\">"]
          lines << "<b>Line #{error_line}:</b> " if error_line
          lines << error_message.to_s.gsub("\n", "<br/>").gsub(" ", "&nbsp;")
          lines << "</span>"
          @line = lines.join()
        elsif @include
          @line = "Include only - not compiled"
        elsif @file[:from_cache]
          @line = "Copied to  <b>#{link}</b> <span class='from-cache'>from&nbsp;cache</span>"
        elsif !@file[:compiled]
          # Nothing
        elsif @extension == "html"
          @line = "Compiled to <b>#{link}</b>"
        elsif @file[:is_a_compiled_file]
          sources = @file.source_files.map { |hammer_file| "<a href='#{@file[:output_path]}' title='#{hammer_file[:path]}'>#{File.basename(hammer_file[:filename])}</a>" }
          @line = "Compiled into #{link}"
        else
          @line = "Compiled to #{link}"
        end
      end
      
      def line
        @line || setup_line
        @line
      end
      
      def links
        links = []
        if !@filename.start_with?(".")
          links.unshift %Q{<a target="blank" href="reveal://#{@file[:output_path]}" class="reveal" title="Reveal Built File">Reveal in Finder</a>}
        end
        if @filename.end_with?(".html") && @file[:output_path]
          links.unshift %Q{<a target="blank" href="#{@file[:output_path]}" class="browser" title="Open in Browser">Open in Browser</a>}
        end
        if ['.html', ".css", ".js"].include?(File.extname(@filename)) || @filename.start_with?(".")
          links.unshift %Q{<a target="blank" href="edit://#{@file[:path]}" class="edit" title="Edit Original">Edit Original</a>}
        end
        return links.join("")
      end
      
      def todos
        @file[:messages].to_a.map do |message|
          %Q{
            <span class="#{message[:html_class] || 'error'}">
              #{"<b>Line #{message[:line]}</b>" if message[:line]} 
              #{message[:message].to_str}
            </span>
          }
        end.join("")
      end
      
      def to_s
        
        hammer_final_filename_attribute = ""
        if @file[:output_path] && !@include
          hammer_final_filename_attribute = "hammer-final-filename=\"#{@file[:output_path]}\""
        end
        
        text = %Q{
          <article class="#{span_class}" hammer-original-filename="#{@file[:path]}" #{hammer_final_filename_attribute}">
            <span class="filename">#{filename}</span>
            <small class="#{span_class}">#{line}</small>
            #{todos}
            #{links}
          </article>
        }
      end
      
      private
      
      def error_file
        
      end
      
      def input_path
        @file[:path]
      end
      
      def output_path
        @file[:output_path]
      end
      
      def filename
        if @file[:is_a_compiled_file]
          @file.source_files.collect(&:filename).join(', ')
        else
          @file[:filename]
        end
      end
    end
    
    class IgnoredTemplateLine < TemplateLine
      def to_s
        %Q{<article class="ignored" hammer-original-filename="#{@file[:path]}">
          <span class="filename">#{filename}</span>
        </article>}
      end
    end
    
  end
end