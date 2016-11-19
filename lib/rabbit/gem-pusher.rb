# Copyright (C) 2016 Kouhei Sutou <kou@cozmixng.org>
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

require "rake"
require "yaml"
require "open-uri"

require "rabbit/gettext"
require "rabbit/password-reader"

module Rabbit
  class GemPusher
    include GetText
    include Rake::DSL

    def initialize(gem_path, user)
      @gem_path = gem_path
      @user = user
    end

    def push
      credentials_path = File.expand_path("~/.gem/credentials")
      credentials_path_exist = File.exist?(credentials_path)
      if credentials_path_exist
        credentials = YAML.load(File.read(credentials_path))
      else
        credentials = {}
      end
      unless credentials.key?(@user.to_sym)
        credentials[@user.to_sym] = retrieve_api_key
        File.open(credentials_path, "w") do |credentials_file|
          credentials_file.print(credentials.to_yaml)
        end
        unless credentials_path_exist
          File.chmod(0600, credentials_path)
        end
      end
      ruby("-S", "gem", "push", @gem_path,
           "--key", @user)
    end

    private
    def retrieve_api_key
      prompt = _("Enter password on RubyGems.org [%{user}]: ") % {:user => @user}
      reader = PasswordReader.new(prompt)
      password = reader.read
      open("https://rubygems.org/api/v1/api_key.yaml",
           :http_basic_authentication => [@user, password]) do |response|
        YAML.load(response.read)[:rubygems_api_key]
      end
    end
  end
end
