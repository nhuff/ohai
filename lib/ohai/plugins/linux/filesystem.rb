#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Ohai.plugin(:Filesystem) do
  provides "filesystem"

  collect_data(:linux) do
    fs = Mash.new

    # Grab filesystem data from df
    so = shell_out("df -P")
    so.stdout.lines do |line|
      case line
      when /^Filesystem\s+1024-blocks/
        next
      when /^(.+?)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\%)\s+(.+)$/
        filesystem = $1
        fs[filesystem] = Mash.new
        fs[filesystem][:kb_size] = $2
        fs[filesystem][:kb_used] = $3
        fs[filesystem][:kb_available] = $4
        fs[filesystem][:percent_used] = $5
        fs[filesystem][:mount] = $6
      end
    end
    
    # Grab filesystem inode data from df
    so = shell_out("df -i")
    so.stdout.lines do |line|
      case line
      when /^Filesystem\s+Inodes/
        next
      when /^(.+?)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\%)\s+(.+)$/
        filesystem = $1
        fs[filesystem] ||= Mash.new
        fs[filesystem][:total_inodes] = $2
        fs[filesystem][:inodes_used] = $3
        fs[filesystem][:inodes_available] = $4
        fs[filesystem][:inodes_percent_used] = $5
        fs[filesystem][:mount] = $6
      end
    end

    # Grab mount information from /bin/mount
    so = shell_out("mount")
    so.stdout.lines do |line|
      if line =~ /^(.+?) on (.+?) type (.+?) \((.+?)\)$/
        filesystem = $1
        fs[filesystem] = Mash.new unless fs.has_key?(filesystem)
        fs[filesystem][:mount] = $2
        fs[filesystem][:fs_type] = $3
        fs[filesystem][:mount_options] = $4.split(",")
      end
    end

    # Gather more filesystem types via libuuid, even devices that's aren't mounted
    so = shell_out("blkid -s TYPE")
    so.stdout.lines do |line|
      if line =~ /^(\S+): TYPE="(\S+)"/
        filesystem = $1
        fs[filesystem] = Mash.new unless fs.has_key?(filesystem)
        fs[filesystem][:fs_type] = $2
      end
    end

    # Gather device UUIDs via libuuid
    so = shell_out("blkid -s UUID")
    so.stdout.lines do |line|
      if line =~ /^(\S+): UUID="(\S+)"/
        filesystem = $1
        fs[filesystem] = Mash.new unless fs.has_key?(filesystem)
        fs[filesystem][:uuid] = $2
      end
    end

    # Gather device labels via libuuid
    so = shell_out("blkid -s LABEL")
    so.stdout.lines do |line|
      if line =~ /^(\S+): LABEL="(\S+)"/
        filesystem = $1
        fs[filesystem] = Mash.new unless fs.has_key?(filesystem)
        fs[filesystem][:label] = $2
      end
    end

    # Grab any missing mount information from /proc/mounts
    if File.exists?('/proc/mounts')
      File.open('/proc/mounts').read_nonblock(4096).each_line do |line|
        if line =~ /^(\S+) (\S+) (\S+) (\S+) \S+ \S+$/
          filesystem = $1
          next if fs.has_key?(filesystem)
          fs[filesystem] = Mash.new
          fs[filesystem][:mount] = $2
          fs[filesystem][:fs_type] = $3
          fs[filesystem][:mount_options] = $4.split(",")
        end
      end
    end

    # Set the filesystem data
    filesystem fs
  end
end
