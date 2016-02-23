require 'pry'

new_repo = "fastlane"
new_repo = "playground"
exceptions = ["countdown", "boarding", "fastlane.tools", "refresher", "examples", "setups", "shenzhen", "itc-api-docs", "enhancer", "brewed-jenkins", "codes", "code-of-conduct", "spaceship.airforce"]

Dir["./workspace/**/*"].each do |path|
  next unless File.exist?(path)
  next if File.directory?(path)
  next unless ["rb", "txt", "md"].include?(path.split(".").last)

  puts "Converting #{path}"

  content = File.read(path)
  content.gsub!(/https\:\/\/github.com\/fastlane\/(\w+)[\w\d\-\/]*/) do |line|
    tool_name = Regexp.last_match[1]
    if exceptions.include?(tool_name) or line.include?("/releases/") or line.include?("tree/master") or line.include?("blob/master") or line.include?("/issues/")
      line
    else
      "https://github.com/fastlane/#{new_repo}/tree/master/#{tool_name}"
    end
  end

  File.write(path, content)
end

puts "Changed files locally, open the workspace to commit and push those changes"
