# Adds ios/Runner/Runner.entitlements to the Runner target of a Flutter iOS project and points
# CODE_SIGN_ENTITLEMENTS at it in every build configuration. The plist itself is written by the caller.
# usage: ruby wire_entitlements.rb <project root>
require 'xcodeproj'

root = ARGV[0] or abort 'project root?'
proj_path = File.join(root, 'ios', 'Runner.xcodeproj')
ent_rel = 'Runner/Runner.entitlements'
abort "missing #{ent_rel}" unless File.exist?(File.join(root, 'ios', ent_rel))

project = Xcodeproj::Project.open(proj_path)
target = project.targets.find { |t| t.name == 'Runner' } or abort 'no Runner target'
group = project.main_group.find_subpath('Runner', false) or abort 'no Runner group'
unless group.files.any? { |f| f.path == 'Runner.entitlements' }
  group.new_reference('Runner.entitlements')
  puts 'added file reference'
end
target.build_configurations.each do |c|
  if c.build_settings['CODE_SIGN_ENTITLEMENTS'] != ent_rel
    c.build_settings['CODE_SIGN_ENTITLEMENTS'] = ent_rel
    puts "#{c.name}: CODE_SIGN_ENTITLEMENTS = #{ent_rel}"
  end
end
project.save
puts 'ok'
