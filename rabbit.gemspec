# Copyright (C) 2012-2018  Kouhei Sutou <kou@cozmixng.org>
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

base_dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(base_dir, 'lib'))
require "rabbit/version"

Gem::Specification.new do |spec|
  spec.name = "rabbit"
  spec.version = Rabbit::VERSION.dup
  spec.rubyforge_project = "rabbit"
  spec.homepage = "http://rabbit-shocker.org/"
  spec.authors = ["Kouhei Sutou"]
  spec.email = ["kou@cozmixng.org"]
  spec.summary = 'Rabbit is an RD-document-based presentation application.'
  spec.description = spec.summary # FIXME
  spec.license = "GPLv2+"

  spec.files = ["Rakefile", "COPYING", "GPL", "README", "Gemfile"]
  spec.files += ["#{spec.name}.gemspec"]
  spec.files += Dir.glob("{lib,data,entities,sample,misc,doc}/**/*")
  spec.files += Dir.glob("po/*/*.po")
  spec.files -= Dir.glob("doc/_site/**/*")
  spec.files += Dir.glob("*.rb")
  spec.files.reject! do |file|
    not File.file?(file)
  end
  spec.test_files = Dir.glob("test/**/*.rb")
  Dir.chdir("bin") do
    spec.executables = Dir.glob("*")
  end

  spec.required_ruby_version = ">= 2.1.0"

  spec.add_runtime_dependency("gdk_pixbuf2", ">= 3.0.9")
  spec.add_runtime_dependency("gtk3")
  spec.add_runtime_dependency("rsvg2", ">= 3.1.4")
  spec.add_runtime_dependency("poppler", ">= 3.2.5")
  spec.add_runtime_dependency("hikidoc")
  spec.add_runtime_dependency("nokogiri")
  spec.add_runtime_dependency("rdtool")
  spec.add_runtime_dependency("rttool")
  spec.add_runtime_dependency("coderay", ">= 1.0.0")
  spec.add_runtime_dependency("kramdown-parser-gfm")
  spec.add_runtime_dependency("gettext", ">= 3.0.1")
  spec.add_runtime_dependency("faraday")
  # spec.add_runtime_dependency("gstreamer")
  spec.add_runtime_dependency("rouge")

  spec.add_development_dependency("test-unit")
  spec.add_development_dependency("test-unit-notify")
  spec.add_development_dependency("test-unit-rr")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("bundler")
  spec.add_development_dependency("jekyll", ">= 1.0.2")
end
