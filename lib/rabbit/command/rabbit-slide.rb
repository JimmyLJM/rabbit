# Copyright (C) 2012-2019  Kouhei Sutou <kou@cozmixng.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

require "yaml"

require "rabbit/author-configuration"
require "rabbit/console"
require "rabbit/path-manipulatable"
require "rabbit/slide-configuration"
require "rabbit/source-generator"

module Rabbit
  module Command
    class RabbitSlide
      include GetText
      include PathManipulatable

      class << self
        def run(*arguments)
          new.run(arguments)
        end
      end

      def initialize
        @use_gui = true
        @title = nil
        @allotted_time = nil
        @slide_conf = nil
        @author_conf = nil
        @logger = nil
      end

      def run(arguments)
        parse_command_line_arguments(arguments)

        if @use_gui
          return false unless show_gui
        end

        validate
        unless @validation_errors.empty?
          messages = (@validation_errors + [_("See --help for example")])
          @logger.error(messages.join("\n"))
          return false
        end

        run_command
        @author_conf.save
        true
      end

      private
      def parse_command_line_arguments(arguments)
        Rabbit::Console.parse!(ARGV) do |parser, options|
          setup_options(parser, options)
        end
        @command = @options.rest.first || default_command
      end

      def setup_options(parser, options)
        @options = options
        @logger = @options.default_logger
        @author_conf = AuthorConfiguration.new(@logger)
        @author_conf.load
        @slide_conf = SlideConfiguration.new(@logger)
        @slide_conf.author = @author_conf

        format = _("Usage: %s COMMAND [OPTIONS]\n" \
                   " e.g.: %s new \\\n" \
                   "          --id rubykaigi2012 \\\n" \
                   "          --base-name rabbit-introduction \\\n" \
                   "          --markup-language rd \\\n" \
                   "          --name \"Kouhei Sutou\" \\\n" \
                   "          --email kou@cozmixng.org \\\n" \
                   "          --rubygems-user kou \\\n" \
                   "          --slideshare-user kou \\\n" \
                   "          --speaker-deck-user kou")

        program = File.basename($0, ".*")
        parser.banner = format % [program, program]

        parser.separator("")
        parser.separator(_("COMMAND"))
        parser.separator(_("  new:    create a new slide"))
        parser.separator(_("  change: change an existing slide"))

        parser.separator("")
        parser.separator(_("User interface"))
        parser.on("--no-use-gui",
                  _("Don't use GUI")) do |boolean|
          @use_gui = boolean
        end

        parser.separator("")
        parser.separator(_("Slide information"))

        parser.on("--id=ID",
                  _("Slide ID"),
                  _("(e.g.: %s)") % "--id=rubykaigi2012",
                  _("(must)")) do |id|
          @slide_conf.id = id
        end

        messages = [
          _("Base name for the slide source file and generated PDF file"),
          _("(e.g.: %s)") % "--base-name=rabbit-introduction",
          _("(must)"),
        ]
        parser.on("--base-name=NAME",
                  *messages) do |base_name|
          @slide_conf.base_name = base_name
        end

        available_markup_languages = [:rd, :hiki, :markdown]
        label = "[" + available_markup_languages.join(", ") + "]"
        messages = [
          _("Markup language for the new slide"),
          _("(e.g.: %s)") % "--markup-language=rd",
          _("(available markup languages: %s)") % label,
        ]
        if @author_conf.markup_language
          messages << _("(default: %s)") % @author_conf.markup_language
        end
        messages << _("(optional)")
        parser.on("--markup-language=LANGUAGE", available_markup_languages,
                  *messages) do |language|
          @author_conf.markup_language = language
        end

        parser.on("--title=TITLE",
                  _("Title of the new slide"),
                  _("(e.g.: %s)") % _("--title=\"Rabbit Introduction\""),
                  _("(optional)")) do |title|
          @title = title
        end

        parser.on("--licenses=LICENSE,LICENSE,...",
                  Array,
                  _("License of the new slide"),
                  _("(e.g.: %s)") % "--licenses=CC-BY-SA-4.0,GFDL-1.3-or-later",
                  _("(optional)")) do |licenses|
          @slide_conf.licenses.concat(licenses)
        end

        parser.on("--tags=TAG,TAG,...",
                  Array,
                  _("Tags of the new slide"),
                  _("(e.g.: %s)") % "--tags=rabbit,presentation,ruby",
               _("(optional)")) do |tags|
          @slide_conf.tags.concat(tags)
        end

        parser.on("--allotted-time=TIME",
                  _("Allotted time in presentaion"),
                  _("(e.g.: %s)") % "--allotted-time=5m",
                  _("(optional)")) do |allotted_time|
          @allotted_time = allotted_time
        end

        parser.on("--presentation-date=DATE", Date,
                  _("Presentation date with the new slide"),
                  _("(e.g.: %s)") % "--presentation-date=2012-06-29",
                  _("(optional)")) do |date|
          @slide_conf.presentation_date = date
        end

        presentation_start_time_example =
          "--presentation-start-time=2012-06-29T10:30:00+0900"
        parser.on("--presentation-start-time=TIME", Time,
                  _("Presentation start time"),
                  _("(e.g.: %s)") % presentation_start_time_example,
                  _("(optional)")) do |time|
          @slide_conf.presentation_start_time = time
        end

        presentation_end_time_example =
          "--presentation-end-time=2012-06-29T11:00:00+0900"
        parser.on("--presentation-end-time=TIME", Time,
                  _("Presentation end time"),
                  _("(e.g.: %s)") % presentation_end_time_example,
                  _("(optional)")) do |time|
          @slide_conf.presentation_end_time = time
        end

        parser.separator(_("Your information"))

        messages = [
          _("Author name of the new slide"),
          _("(e.g.: %s)") % "--name=\"Kouhei Sutou\"",
        ]
        if @author_conf.name
          messages << _("(default: %s)") % @author_conf.name
        end
        messages << _("(optional)")
        parser.on("--name=NAME",
                  *messages) do |name|
          @author_conf.name = name
        end

        messages = [
          _("Author e-mail of the new slide"),
          _("(e.g.: %s)") % "--email=kou@cozmixng.org",
        ]
        if @author_conf.email
          messages << _("(default: %s)") % @author_conf.email
        end
        messages << _("(optional)")
        parser.on("--email=EMAIL",
                  *messages) do |email|
          @author_conf.email = email
        end

        messages = [
          _("Account for %s") % "RubyGems.org",
          _("It is used to publish your slide to %s") % "RubyGems.org",
          _("(e.g.: %s)") % "--rubygems-user=kou",
        ]
        if @author_conf.rubygems_user
          messages << _("(default: %s)") % @author_conf.rubygems_user
        end
        messages << _("(optional)")
        parser.on("--rubygems-user=USER",
                  *messages) do |user|
          @author_conf.rubygems_user = user
        end

        messages = [
          _("Account for %s") % "SlideShare",
          _("It is used to publish your slide to %s") % "SlideShare",
          _("(e.g.: %s)") % "--slideshare-user=kou",
        ]
        if @author_conf.slideshare_user
          messages << _("(default: %s)") % @author_conf.slideshare_user
        end
        messages << _("(optional)")
        parser.on("--slideshare-user=USER",
                  *messages) do |user|
          @author_conf.slideshare_user = user
        end

        messages = [
          _("Account for %s") % "Speaker Deck",
          _("It is used to publish your slide to %s") % "Speaker Deck",
          _("(e.g.: %s)") % "--speaker-deck-user=kou",
        ]
        if @author_conf.speaker_deck_user
          messages << _("(default: %s)") % @author_conf.speaker_deck_user
        end
        messages << _("(optional)")
        parser.on("--speaker-deck-user=USER",
                  *messages) do |user|
          @author_conf.speaker_deck_user = user
        end
      end

      def default_command
        if File.file?("config.yaml")
          "change"
        else
          "new"
        end
      end

      def available_commands
        ["new", "change"]
      end

      def gui_mappings
        {
          "slide-id" => {
            property: "text",
            value: @slide_conf.id,
            required: true,
            validate: lambda {|entry| not entry.text.empty?},
            apply: lambda {|entry| @slide_conf.id = entry.text},
          },
        }
      end

      def show_gui
        require "rabbit/gtk"

        builder = Gtk::Builder.new(path: File.join(__dir__, "rabbit-slide.ui"))
        gui_mappings.each do |id, data|
          widget = builder[id]
          if data[:required]
            widget.signal_connect(:notify, data) do |_widget, param_spec, _data|
              if param_spec.name == _data[:propperty]
                if _data[:validate].call(_widget)
                  slide_id.style_context.remove_class(Gtk::STYLE_CLASS_ERROR)
                else
                  slide_id.style_context.add_class(Gtk::STYLE_CLASS_ERROR)
                end
              end
            end
          end
          widget.set_property(data[:property], data[:value]) if data[:value]
        end

        dialog = builder["dialog"]
        case dialog.run
        when Gtk::ResponseType::CANCEL, Gtk::ResponseType::DELETE_EVENT
          false
        else
          gui_mappings.each do |id, data|
            data[:apply].call(builder[id])
          end
          true
        end
      end

      def validate
        @validation_errors = []
        validate_command
        validate_id
        validate_base_name
      end

      def validate_command
        if @options.rest.size > 1
          message = _("too many commands: %s") % @options.rest.inspect
          @validation_errors << message
        end
        unless available_commands.include?(@command)
          format = _("invalid command: <%s>: available commands: %s")
          message = format % [@command, "[#{available_commands.join(', ')}]"]
          @validation_errors << message
        end
      end

      def validate_id
        if @slide_conf.id.nil?
          @validation_errors << (_("%s is missing") % "--id")
        end
      end

      def validate_base_name
        if @slide_conf.base_name.nil?
          @validation_errors << (_("%s is missing") % "--base-name")
        end
      end

      def run_command
        __send__("run_command_#{@command}")
      end

      def run_command_new
        generate_directory
        generate_template
      end

      def run_command_change
        merge_config_yaml
        generate_template
      end

      def merge_config_yaml
        existing_slide_conf = SlideConfiguration.new(@logger)
        existing_slide_conf.load
        existing_slide_conf.merge!(@slide_conf.to_hash)
        @slide_conf = existing_slide_conf
        @author_conf = @slide_conf.author
      end

      def generate_directory
        create_directory(base_directory)
      end

      def generate_template
        generate_dot_gitignore
        generate_dot_rabbit
        generate_slide_configuration
        generate_readme
        generate_rakefile
        generate_slide
      end

      def generate_dot_gitignore
        create_file(".gitignore") do |dot_gitignore|
          dot_gitignore.puts(<<-EOD)
.DS_Store
/.tmp/
/pkg/
/pdf/
EOD
        end
      end

      def generate_dot_rabbit
        create_file(".rabbit") do |dot_rabbit|
          options = []
          if @author_conf.markup_language.nil? and @allotted_time
            options << "--allotted-time #{@allotted_time}"
          end
          options << slide_path
          dot_rabbit.puts(options.join("\n"))
        end
      end

      def generate_slide_configuration
        @slide_conf.save(base_directory)
      end

      def generate_readme
        create_file("README.#{readme_extension}") do |readme|
          readme.puts(readme_content)
        end
      end

      def readme_content
        markup_language = @author_conf.markup_language || :rd
        generator = Rabbit::SourceGenerator.find(markup_language)

        content = ""
        title = @title || _("TODO: SLIDE TITLE")
        content << generator.heading(1, title)
        content << "\n\n"
        content << _("TODO: SLIDE DESCRIPTION")
        content << "\n\n"

        content << generator.heading(2, _("For author"))
        content << "\n\n"
        content << generator.heading(3, _("Show"))
        content << "\n\n"
        content << generator.preformatted_line("rake")
        content << "\n\n"
        content << generator.heading(3, _("Publish"))
        content << "\n\n"
        content << generator.preformatted_line("rake publish")
        content << "\n\n"

        content << generator.heading(2, _("For viewers"))
        content << "\n\n"
        content << generator.heading(3, _("Install"))
        content << "\n\n"
        install_command = "gem install #{@slide_conf.gem_name}"
        content << generator.preformatted_line(install_command)
        content << "\n\n"
        content << generator.heading(3, _("Show"))
        content << "\n\n"
        show_command = "rabbit #{@slide_conf.gem_name}.gem"
        content << generator.preformatted_line(show_command)
        content << "\n\n"
      end

      def generate_rakefile
        create_file("Rakefile") do |rakefile|
          rakefile.puts(<<-'RAKEFILE')
require "rabbit/task/slide"

# Edit ./config.yaml to customize meta data

spec = nil
Rabbit::Task::Slide.new do |task|
  spec = task.spec
  # spec.files += Dir.glob("doc/**/*.*")
  # spec.files -= Dir.glob("private/**/*.*")
  # spec.add_runtime_dependency("rabbit-theme-YOUR-THEME")
end

desc "Tag #{spec.version}"
task :tag do
  sh("git", "tag", "-a", spec.version.to_s, "-m", "Publish #{spec.version}")
  sh("git", "push", "--tags")
end
          RAKEFILE
        end
      end

      def generate_slide
        source = slide_source
        return if source.nil?
        create_file(slide_path) do |slide|
          slide.puts(source)
        end
      end

      def slide_path
        "#{@slide_conf.base_name}.#{slide_source_extension}"
      end

      def slide_source_extension
        case @author_conf.markup_language
        when :rd
          "rab"
        when :hiki
          "hiki"
        when :markdown
          "md"
        else
          "pdf"
        end
      end

      def readme_extension
        case @author_conf.markup_language
        when :rd
          "rd"
        when :hiki
          "hiki"
        when :markdown
          "md"
        else
          "rd"
        end
      end

      def slide_source
        generator = Rabbit::SourceGenerator.find(@author_conf.markup_language)
        return nil if generator.nil?

        source = ""
        slide_source_title(source, generator, @title || _("TITLE"))
        slide_source_metadata(source, generator)
        slide_source_title(source, generator, _("FIRST SLIDE"))
        slide_source_items(source, generator)
        slide_source_title(source, generator, _("SECOND SLIDE"))
        slide_source_image(source, generator)
      end

      def slide_source_title(source, generator, title)
        source << generator.heading(1, title)
        source << "\n\n"
      end

      def slide_source_metadata(source, generator)
        presentation_date = @slide_conf.presentation_date
        presentation_date_default = Time.now
        allotted_time_default = "5m"
        allotted_time =
          Utils.ensure_time(@allotted_time || allotted_time_default)
        start_time = @slide_conf.presentation_start_time
        end_time = @slide_conf.presentation_end_time
        if presentation_date
          start_time ||= presentation_date
          end_time ||= presentation_date + allotted_time
          presentation_date = presentation_date.strftime("%Y-%m-%d")
        end
        start_time = start_time.iso8601 if start_time
        end_time = end_time.iso8601 if end_time
        start_time_default = presentation_date_default
        end_time_default = start_time_default + allotted_time
        slide_metadata = [
          ["subtitle",       nil,                _("SUBTITLE")],
          ["author",         @author_conf.name,  _("AUTHOR")],
          ["institution",    nil,                _("INSTITUTION")],
          ["content-source", nil,                _("EVENT NAME")],
          [
            "date",
            presentation_date,
            presentation_date_default.strftime("%Y-%m-%d"),
          ],
          ["allotted-time",  @allotted_time,     "5m"],
          ["start-time",     start_time,         start_time_default.iso8601],
          ["end-time",       end_time,           end_time_default.iso8601],
          ["theme",          nil,                "default"],
        ]
        slide_metadata.each do |key, value, default_value|
          item = generator.definition_list_item(key, value || default_value)
          item << "\n"
          if value
            source << item
          else
            item.each_line do |line|
              source << generator.comment(line)
            end
          end
        end
        source << "\n"
      end

      def slide_source_items(source, generator)
        1.upto(3) do |i|
          source << generator.unordered_list_item(_("ITEM %d") % i)
          source << "\n"
        end
        source << "\n"
      end

      def slide_source_image(source, generator)
        lavie = "https://raw.github.com/rabbit-shocker/rabbit/master/sample/lavie.png"
        options = {
          :relative_height => 100,
        }
        source << generator.image(lavie, options)
        source << "\n"
      end

      def base_directory
        case @command
        when "change"
          "."
        else
          @slide_conf.id
        end
      end

      def create_file(path, &block)
        super(File.join(base_directory, path), &block)
      end
    end
  end
end
