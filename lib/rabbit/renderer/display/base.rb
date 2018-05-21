require "rabbit/renderer/base"
require "rabbit/renderer/display/hook-handler"

module Rabbit
  module Renderer
    module Display
      module Base
        include Renderer::Base
        include HookHandler

        def initialize(*args, &block)
          @drawable = nil
          @size = nil
          @size_dirty = true
          @default_size_ratio = nil
          @size_ratio = nil
          super
        end

        def width
          refresh_size
          if @size
            @size.logical_width
          else
            nil
          end
        end

        def height
          refresh_size
          if @size
            @size.logical_height
          else
            nil
          end
        end

        def size
          refresh_size
          @size
        end

        def redraw
          widget.queue_draw
        end

        def attach_to(window, container=nil)
          @window = window
          @container = container || @window
        end

        def detach
          @window = nil
          @container = nil
        end

        def toggle_whiteout
          super
          update_menu
        end

        def toggle_blackout
          super
          update_menu
        end

        def make_layout(text)
          attrs, text = Pango.parse_markup(text)
          layout = create_pango_layout(text)
          layout.set_attributes(attrs)
          layout
        end

        def create_pango_context
          context = widget.create_pango_context
          set_font_resolution(context)
          context
        end

        def create_pango_layout(text)
          layout = widget.create_pango_layout(text)
          set_font_resolution(layout.context)
          layout
        end

        def update_title
          @canvas.update_title(@canvas.slide_title)
        end

        def draw_slide(slide, simulation)
          set_size_ratio(slide.size_ratio || @default_size_ratio)

          if simulation
            super
          else
            save_context do
              translate_context(@size.logical_margin_left,
                                @size.logical_margin_top)
              super
            end

            unless @size.have_logical_margin?
              return
            end

            margin_background = make_color("black")
            if @size.have_logical_margin_x?
              draw_rectangle(true,
                             0,
                             0,
                             @size.logical_margin_left,
                             @size.real_height,
                             margin_background)
              draw_rectangle(true,
                             @size.real_width - @size.logical_margin_right,
                             0,
                             @size.logical_margin_right,
                             @size.real_height,
                             margin_background)
            end
            if @size.have_logical_margin_y?
              draw_rectangle(true,
                             0,
                             0,
                             @size.real_width,
                             @size.logical_margin_top,
                             margin_background)
              draw_rectangle(true,
                             0,
                             @size.real_height - @size.logical_margin_bottom,
                             @size.real_width,
                             @size.logical_margin_bottom,
                             margin_background)
            end
          end
        end

        private
        def set_drawable(drawable)
          @drawable = drawable
          set_default_size(@drawable.width, @drawable.height)
        end

        def set_default_size(w, h)
          @real_width = w
          @real_height = h
          @default_size_ratio = w.to_f / h.to_f
          @size_ratio = @default_size_ratio
          set_size(w, h)
        end

        def set_size(w, h)
          @size = Size.new(w, h, @size_ratio)
        end

        def update_size(w, h)
          @real_width = w
          @real_height = h
          @size_dirty = true
        end

        def set_size_ratio(ratio)
          return if @size.ratio == ratio

          w = @size.real_width
          h = @size.real_height
          @size_ratio = ratio
          @size = Size.new(w, h, @size_ratio)
        end

        def refresh_size
          return unless @size_dirty

          @size = Size.new(@real_width,
                           @real_height,
                           @size.ratio)
          @size_dirty = false
        end

        def queue_draw
          widget.queue_draw
        end
      end
    end
  end
end
