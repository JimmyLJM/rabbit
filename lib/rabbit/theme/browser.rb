require 'gtk2'

require 'rabbit/rabbit'
require 'rabbit/image'
require 'rabbit/theme/searcher'

module Rabbit
  module Theme
    class Browser
      include GetText
      
      TREE_MODEL = [
        [:name, String],
        [:title, String],
        [:type, String],
      ]
      
      TAG_INFOS = [
        [
          "heading1",
          {
            "weight" => Pango::FontDescription::WEIGHT_BOLD,
            "pixels-above-lines" => 5,
            "pixels-below-lines" => 10,
            "left-margin" => 5,
            "size" => 18 * Pango::SCALE,
          }
        ],
        [
          "heading2",
          {
            "pixels-above-lines" => 5,
            "pixels-below-lines" => 5,
            "left-margin" => 5,
            "size" => 17 * Pango::SCALE,
          }
        ],
        [
          "item",
          {
            "left-margin" => 15,
            "pixels-above-lines" => 2,
            "pixels-below-lines" => 2,
          }
        ],
        [
          "item-content",
          {
          }
        ],
        [
          "link",
          {
            "foreground" => "blue",
            "underline" => Pango::AttrUnderline::SINGLE,
          }
        ],
        [
          "description",
          {
            "left-margin" => 20,
            "right-margin" => 20,
          }
        ],
        [
          "parameter",
          {
            "left-margin" => 20,
            "right-margin" => 20,
            "pixels-below-lines" => 4,
          }
        ],
        [
          "parameter-name",
          {
            "foreground" => "red",
            "family" => "Monospace",
          }
        ],
        [
          "parameter-default",
          {
            "foreground" => "gray",
            "family" => "Monospace",
            "style" => Pango::FontDescription::STYLE_ITALIC,
          }
        ],
        [
          "parameter-description",
          {
            "left-margin" => 40,
            "right-margin" => 40,
          }
        ],
      ]
      
      def initialize(locales)
        @locales = locales
        @themes = Searcher.collect_theme
        @hovering = false
        @category_buffers = {}
        @theme_buffers = {}
        @locales.each do |locale|
          @category_buffers[locale] = {}
          @theme_buffers[locale] = {}
        end
        @trees = {}
        @views = {}
        @hpaneds = {}
        load_themes
        load_cursor
        load_itemize_icon
        init_gui
      end
      
      def set_window_size(width, height)
        @window.set_default_size(width, height)
        @hpaneds.each_value do |hpaned|
          hpaned.position = width * 0.25
        end
      end
      
      def run
        @window.show_all
        @notebook.page = @init_page_number
      end
      
      private
      def init_gui
        init_window
        current_locale = Locale.get
        @init_page_number = 0
        @locales.each_with_index do |locale, i|
          @init_page_number = i if /#{locale}/ =~ current_locale
          GetText.locale = locale
          init_body(locale)
        end
      end
      
      def init_window
        @window = Gtk::Window.new
        @window.signal_connect("destroy") do
          Gtk.main_quit
        end
        @window.signal_connect("key_press_event") do |widget, event|
          if event.state.control_mask? and event.keyval == Gdk::Keyval::GDK_q
            @window.destroy
          end
        end
        init_notebook
      end

      def init_notebook
        @notebook = Gtk::Notebook.new
        @notebook.signal_connect("switch-page") do |book, page, n|
          @current_locale = @locales[n]
          GetText.locale = @current_locale
          false
        end
        @window.add(@notebook)
      end
      
      def init_body(locale)
        vbox = Gtk::VBox.new
        hpaned = Gtk::HPaned.new
        @hpaneds[locale] = hpaned
        vbox.pack_end(hpaned)
        init_document_tree(hpaned, locale)
        init_document_view(hpaned, locale)
        GetText.locale = Locale.get
        locale_name_for_the_locale = _(locale)
        GetText.locale = locale
        @notebook.append_page(vbox,
                              Gtk::Label.new(locale_name_for_the_locale))
      end
      
      def init_document_tree(hpaned, locale)
        tree = Gtk::TreeView.new
        @trees[locale] = tree
        scrolled_window = wrap_by_scrolled_window(tree)
        hpaned.add1(scrolled_window)
        model_types = TREE_MODEL.collect {|key, type| type}
        model = Gtk::TreeStore.new(*model_types)
        tree.set_model(model)
        init_tree_columns(tree, locale)
        init_tree_model(tree, locale)
      end
      
      def init_tree_columns(tree, locale)
        renderer = Gtk::CellRendererText.new
        tree.insert_column(-1, _("Theme"), renderer,
                           "text" => column(:title))
        tree.selection.signal_connect("changed") do |selection|
          iter = selection.selected
          theme_changed(iter) if iter
        end
      end
      
      def theme_changed(iter)
        name = iter.get_value(column(:name))
        type = iter.get_value(column(:type))
        __send__("change_to_#{type}_buffer", name)
      end
      
      def init_document_view(hpaned, locale)
        view = Gtk::TextView.new
        @views[locale] = view
        scrolled_window = wrap_by_scrolled_window(view)
        hpaned.add2(scrolled_window)
        view.wrap_mode = Gtk::TextTag::WRAP_WORD
        view.editable = false
        view.signal_connect("event-after") do |*args|
          view_event_after(*args)
        end
        view.signal_connect("motion-notify-event") do |*args|
          view_motion_notify_event(*args)
        end
      end
      
      def column(key)
        TREE_MODEL.index(TREE_MODEL.assoc(key))
      end

      def load_itemize_icon
        rabbit_image_theme = Searcher.find_theme("rabbit-images")
        icon_file = Searcher.find_file("green-item.png", [rabbit_image_theme])
        loader = ImageLoader.new(icon_file)
        loader.resize(10, 10)
        @itemize_icon = loader.pixbuf
      end

      def load_cursor
        @hand_cursor = Gdk::Cursor.new(Gdk::Cursor::HAND2)
        @regular_cursor = Gdk::Cursor.new(Gdk::Cursor::XTERM)
      end
      
      def load_themes
        @themes = Searcher.collect_theme do |entry|
          Utils.process_pending_events
        end
      end

      def init_tree_model(tree, locale)
        model = tree.model
        categories = {}
        @themes.each do |entry|
          category = entry.category
          iter = categories[category]
          if iter.nil?
            iter = model.append(nil)
            categories[category] = iter
            iter[column(:type)] = "category"
            iter[column(:name)] = category
            iter[column(:title)] = _(category)
          end
          child_iter = model.append(iter)
          child_iter[column(:type)] = "theme"
          child_iter[column(:name)] = entry.name
          child_iter[column(:title)] = _(entry.title)
          Utils.process_pending_events
        end
        # tree.expand_all
      end
      
      def init_tags(buffer)
        TAG_INFOS.each do |name, properties|
          buffer.create_tag(name, properties)
        end
      end

      def current_view
        @views[@current_locale]
      end

      def current_tree
        @trees[@current_locale]
      end

      def update_buffer(name, buffers)
        buffer = buffers[@current_locale][name]
        if buffer.nil?
          buffer = Gtk::TextBuffer.new
          init_tags(buffer)
          buffers[@current_locale][name] = buffer
          yield(buffer)
        end
        current_view.buffer = buffer
      end
      
      def change_to_category_buffer(name)
        update_buffer(name, @category_buffers) do |buffer|
          iter = buffer.start_iter
          insert_heading(buffer, iter, _(name))
          @themes.each do |entry|
            if entry.category == name
              insert_item(buffer, iter) do |buffer, iter|
                insert_theme_link(buffer, iter, entry.name, _(entry.title))
              end
            end
          end
        end
      end

      def change_to_theme_buffer(name)
        update_buffer(name, @theme_buffers) do |buffer|
          entry = @themes.find {|entry| entry.name == name}
          iter = buffer.start_iter
          insert_heading(buffer, iter, _(entry.title))
          insert_item(buffer, iter) do |buffer, iter|
            buffer.insert(iter, _("Name: "))
            buffer.insert(iter, entry.name)
          end
          insert_item(buffer, iter) do |buffer, iter|
            buffer.insert(iter, _("Category: "))
            insert_category_link(buffer, iter, entry.category)
          end
          if entry.abstract
            insert_item(buffer, iter) do |buffer, iter|
              buffer.insert(iter, _("Abstract: "))
              buffer.insert(iter, _(entry.abstract))
            end
          end
          if entry.description
            insert_heading(buffer, iter, _("Description"), 2)
            buffer.insert(iter, "#{_(entry.description)}\n", "description")
          end
          unless entry.dependencies.empty?
            insert_heading(buffer, iter, _("Dependencies"), 2)
            entry.dependencies.each do |dependency|
              insert_item(buffer, iter) do |buffer, iter|
                e = @themes.find {|e| e.name == dependency}
                insert_theme_link(buffer, iter, e.name, _(e.title))
              end
            end
          end
          unless entry.parameters.empty?
            insert_heading(buffer, iter, _("Parameters"), 2)
            entry.parameters.each do |name, info|
              insert_parameter(buffer, iter, name, info)
            end
          end
        end
      end

      def insert_heading(buffer, iter, text, level=1)
        buffer.insert(iter, "#{text}\n", "heading#{level}")
      end

      def insert_theme_link(buffer, iter, name, text=nil)
        text ||= _(name)
        start_offset = iter.offset
        buffer.insert(iter, text, "link")
        tag = buffer.create_tag("theme-link-#{name}", {})
        buffer.apply_tag(tag,
                         buffer.get_iter_at_offset(start_offset),
                         iter)
      end

      def insert_category_link(buffer, iter, name, text=nil)
        text ||= _(name)
        start_offset = iter.offset
        buffer.insert(iter, text, "link")
        tag = buffer.create_tag("category-link-#{name}", {})
        buffer.apply_tag(tag,
                         buffer.get_iter_at_offset(start_offset),
                         iter)
      end

      def insert_item(buffer, iter, text=nil)
        start_offset = iter.offset
        buffer.insert(iter, @itemize_icon)
        buffer.insert(iter, " ")
        item_start_offset = iter.offset
        if text.nil?
          yield(buffer, iter)
        else
          buffer.insert(iter, text)
        end
        buffer.apply_tag("item-content",
                         buffer.get_iter_at_offset(item_start_offset),
                         iter)
        buffer.apply_tag("item",
                         buffer.get_iter_at_offset(start_offset),
                         iter)
        buffer.insert(iter, "\n")
      end

      def insert_parameter(buffer, iter, name, info)
        start_offset = iter.offset
        buffer.insert(iter, name, "parameter-name")
        buffer.insert(iter, " (")
        buffer.insert(iter, _("default: "))
        buffer.insert(iter, info[:default], "parameter-default")
        buffer.insert(iter, ")\n")
        buffer.insert(iter, _(info[:description]), "parameter-description")
        buffer.insert(iter, "\n")
        buffer.apply_tag("parameter",
                         buffer.get_iter_at_offset(start_offset),
                         iter)
      end

      def wrap_by_scrolled_window(widget)
        scrolled_window = Gtk::ScrolledWindow.new
        scrolled_window.set_policy(Gtk::PolicyType::AUTOMATIC,
                                   Gtk::PolicyType::AUTOMATIC)
        scrolled_window.add(widget)
        scrolled_window
      end

      def view_event_after(view, event)
        unless event.kind_of?(Gdk::EventButton) and
            event.button == 1 and
            event.event_type == Gdk::Event::BUTTON_RELEASE
          return false
        end

        buffer = view.buffer
        range = buffer.selection_bounds
        if range and range[0].offset != range[1].offset
          return false
        end

        x, y = view.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET,
                                            event.x, event.y)
        iter = view.get_iter_at_location(x, y)
        follow_if_link(view, iter)
      end

      def follow_if_link(view, iter)
        iter.tags.each do |tag|
          name = get_name_from_link_tag(tag)
          if name
            name_column = column(:name)
            tree = current_tree
            tree.model.each do |model, path, iter|
              if name == iter.get_value(name_column)
                tree.expand_to_path(path)
                tree.selection.select_iter(iter)
                break
              end
            end
          end
        end
      end

      def set_cursor_if_appropriate(view, x, y)
        buffer = view.buffer
        iter = view.get_iter_at_location(x, y)
        
        hovering = false

        iter.tags.each do |tag|
          if link_tag?(tag)
            hovering = true
            break
          end
        end
        
        if hovering != @hovering
          @hovering = hovering
          window = view.get_window(Gtk::TextView::WINDOW_TEXT)
          if @hovering
            cursor = @hand_cursor
          else
            cursor = @regular_cursor
          end
          window.cursor = cursor
        end
      end
    
      def view_motion_notify_event(view, event)
        x, y = view.window_to_buffer_coords(Gtk::TextView::WINDOW_WIDGET,
                                            event.x, event.y)
        set_cursor_if_appropriate(view, x, y)
        view.window.pointer
        false
      end

      def link_tag?(tag)
        /-?link-?/ =~ tag.name
      end
      
      def get_name_from_link_tag(tag)
        if /^(theme|category)-link-/ =~ tag.name
          $POSTMATCH
        end
      end
    end
  end
end
