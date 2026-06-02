require 'xcodeproj'
project_path = 'gitui.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Find or create group
group = project.main_group['gitui']['Modules']['Blame']['View']
unless group
  puts "Group not found"
  exit 1
end

# Check if already exists
existing = group.files.find { |f| f.path == 'BlameViewController.xib' }
if existing
  puts "Already exists"
else
  file_ref = group.new_reference('BlameViewController.xib')
  target.resources_build_phase.add_file_reference(file_ref)
  project.save
  puts "Added XIB"
end
