# From http://scottwb.com/blog/2012/07/14/merge-git-repositories-and-preseve-commit-history/

require 'tmpdir'
require 'colored'
require 'pry'

def cmd(command)
  puts "$ #{command}".yellow
  puts `#{command}`
end

require './tools'
names = @tools
names << "countdown"

url = "https://github.com/fastlane/fastlane" # the repo everything goes to

new_branch_name = "monorepo"
path = Dir.mktmpdir
path = "all_cloned"
destination = "workspace"
FileUtils.rm_rf(path)
FileUtils.rm_rf(destination)
FileUtils.mkdir_p(path)
FileUtils.mkdir_p(destination)

cmd "cd '#{destination}' && git clone '#{url}'"
parent_name = url.split("/").last
destination = File.join(destination, parent_name)
raise "Destination repo must be the fastlane repo".red unless File.exist?(File.join(destination, "fastlane.gemspec"))

Dir.chdir(destination) do
  cmd "git checkout -b '#{new_branch_name}'"
end

# Move the main tool into its subfolder
subfolder_name = ENV["SUBFOLDER_NAME"] || "fastlane"


def copy_with_hidden(from, to)
  FileUtils.mv(Dir[File.join(from, "*")], to) # move everything away to create a new fastlane folder

  # to also copy hidden files...
  Dir.foreach(from).each do |current|
    next if current == '.' or current == '..'
    next if current.include?("git")
    FileUtils.mv(File.join(from, current), File.join(to, File.basename(current)))
  end
end

tmp = Dir.mktmpdir
copy_with_hidden(destination, tmp)
# FileUtils.mv(Dir[File.join(destination, "*")], tmp) # move everything away to create a new fastlane folder
FileUtils.mkdir_p(File.join(destination, subfolder_name))
# FileUtils.mv(Dir[File.join(tmp, "*")], File.join(destination, subfolder_name))
copy_with_hidden(tmp, File.join(destination, subfolder_name))

names.each do |name|
  cmd "cd '#{path}' && git clone 'https://github.com/fastlane/#{name}' && cd #{name} && git remote rm origin"
end

names.each do |name|
  puts "Rewriting history of '#{name}'"
  commit_message = "Migrate #{name} to the fastlane mono repo"
  commit_body = "You can read more about the change in our blog post: https://krausefx.com/blog/our-goal-to-unify-fastlane-tools"

  ref = File.expand_path("#{path}/#{name}")
  puts "Going to '#{ref}'".green
  Dir.chdir(ref) do
    cmd "mkdir #{name}"
    Dir.foreach(".") do |current| # foreach instead of glob to have hidden items too
      next if current == '.' or current == '..'
      next if current.include?(".git")
      cmd "git mv '#{current}' '#{name}/'"
    end
    cmd "git add -A"
    cmd "git commit -m '#{commit_message}' -m '#{commit_body}'"
  end

  puts "Going to '#{destination}' (to merge stuff)".green
  Dir.chdir(destination) do
    cmd "git remote add local_ref '#{ref}'"
    cmd "git pull local_ref master"
    cmd "git remote rm local_ref"
    cmd "git add -A"
    cmd "git commit -m '#{commit_message}' -m '#{commit_body}'"
  end
end

# foreach => hidden files as well

def remove_dot_files(path)
  Dir.chdir(path) do
    Dir.foreach(".") do |current|
      next if current == '.' or current == '..'
      next if current == ".git"
      next if current == ".rspec"

      if current.start_with?(".")
        puts "Deleting '#{current}' dot file"
        FileUtils.rm_rf(current)
      end
    end
  end
end

remove_dot_files(destination)
names.each do |current|
  remove_dot_files(File.join(destination, current))
end
cmd "cd #{destination} && git add -A && git commit -m 'Removed dot files'"

# Migrate the countdown repo too
FileUtils.mv(File.join(destination, "countdown", "Rakefile"), File.join(destination, "Rakefile"))

# Copy files from files_to_copy
Dir.foreach("files_to_copy").each do |current|
  next if current == '.' or current == '..'
  FileUtils.cp(File.join("files_to_copy", current), File.join(destination, File.basename(current)))
end

Dir[File.join(destination, "*/Gemfile")].each do |current| # one * only, that's important, otherwise it matches ./Gemfile
  next if current.include?("fastlane/Gemfile")
  File.write(current, "source \"https://rubygems.org\"\n\ngemspec\n")
end

# We leave the countdown folder for now, as it also contains documentation about things
Dir.chdir(destination) do
  cmd "git add -A"
  cmd "git commit -m 'Switched to fastlane mono repo'"
end

puts `open '#{path}'`
puts `open '#{destination}'`

puts "To push the changes run this:"
puts "cd '#{destination}' && git push origin #{new_branch_name}".green
