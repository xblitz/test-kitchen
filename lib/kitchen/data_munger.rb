# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
#
# Copyright (C) 2012, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'vendor/hash_recursive_merge'

module Kitchen

  # Class to handle recursive merging of configuration between platforms,
  # suites, and common data.
  #
  # This object will mutate the data Hash passed into its constructor and so
  # should not be reused or shared across threads.
  #
  # @author Fletcher Nichol <fnichol@nichol.ca>
  class DataMunger

    def initialize(data)
      @data = data
      convert_legacy_driver_format!
      convert_legacy_chef_paths_format!
      convert_legacy_require_chef_omnibus_format!
      move_chef_data_to_provisioner!
    end

    def driver_data_for(suite, platform)
      merged_data_for(:driver, suite, platform)
    end

    def provisioner_data_for(suite, platform)
      merged_data_for(:provisioner, suite, platform)
    end

    def busser_data_for(suite, platform)
      merged_data_for(:busser, suite, platform, :version)
    end

    private

    attr_reader :data

    def merged_data_for(key, suite, platform, default_key = :name)
      cdata = data.fetch(key, Hash.new)
      cdata = { default_key => cdata } if cdata.is_a?(String)
      pdata = platform_data(platform).fetch(key, Hash.new)
      pdata = { default_key => pdata } if pdata.is_a?(String)
      sdata = suite_data(suite).fetch(key, Hash.new)
      sdata = { default_key => sdata } if sdata.is_a?(String)

      cdata.rmerge(pdata.rmerge(sdata))
    end

    def platform_data(name)
      data.fetch(:platforms, Hash.new).find(lambda { Hash.new }) do |platform|
        platform.fetch(:name, nil) == name
      end
    end

    def suite_data(name)
      data.fetch(:suites, Hash.new).find(lambda { Hash.new }) do |suite|
        suite.fetch(:name, nil) == name
      end
    end

    def move_chef_data_to_provisioner!
      data.fetch(:suites, []).each do |suite|
        move_chef_data_to_provisioner_at!(suite, :attributes)
        move_chef_data_to_provisioner_at!(suite, :run_list)
      end

      data.fetch(:platforms, []).each do |platform|
        move_chef_data_to_provisioner_at!(platform, :attributes)
        move_chef_data_to_provisioner_at!(platform, :run_list)
      end
    end

    def move_chef_data_to_provisioner_at!(root, key)
      if root.has_key?(key)
        pdata = root.fetch(:provisioner, Hash.new)
        pdata = { :name => pdata } if pdata.is_a?(String)
        root[:provisioner] = pdata.rmerge({ key => root.delete(key) })
      end
    end

    def convert_legacy_driver_format!
      convert_legacy_driver_format_at!(data)
      data.fetch(:platforms, []).each do |platform|
        convert_legacy_driver_format_at!(platform)
      end
      data.fetch(:suites, []).each do |suite|
        convert_legacy_driver_format_at!(suite)
      end
    end

    def convert_legacy_driver_format_at!(root)
      if root[:driver_config]
        ddata = root.fetch(:driver, Hash.new)
        ddata = { :name => ddata } if ddata.is_a?(String)
        root[:driver] = root.delete(:driver_config).rmerge(ddata)
      end

      if root[:driver_plugin]
        ddata = root.fetch(:driver, Hash.new)
        ddata = { :name => ddata } if ddata.is_a?(String)
        root[:driver] = { :name => root.delete(:driver_plugin) }.rmerge(ddata)
      end
    end

    def convert_legacy_chef_paths_format!
      data.fetch(:suites, []).each do |suite|
        %w{data data_bags environments nodes roles}.each do |key|
          move_chef_data_to_provisioner_at!(suite, "#{key}_path".to_sym)
        end
      end
    end

    def convert_legacy_require_chef_omnibus_format!
      convert_legacy_require_chef_omnibus_format_at!(data)
      data.fetch(:platforms, []).each do |platform|
        convert_legacy_require_chef_omnibus_format_at!(platform)
      end
      data.fetch(:suites, []).each do |suite|
        convert_legacy_require_chef_omnibus_format_at!(suite)
      end
    end

    def convert_legacy_require_chef_omnibus_format_at!(root)
      key = :require_chef_omnibus
      ddata = root.fetch(:driver, Hash.new)

      if ddata.is_a?(Hash) && ddata.has_key?(key)
        pdata = root.fetch(:provisioner, Hash.new)
        pdata = { :name => pdata } if pdata.is_a?(String)
        root[:provisioner] =
          { key => root.fetch(:driver).delete(key) }.rmerge(pdata)
      end
    end
  end
end
