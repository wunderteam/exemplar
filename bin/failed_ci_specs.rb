#!/usr/bin/env ruby

# Make sure CIRCLE_API_TOKEN is present
# Gets failed builds for a CI run
# Pipe into rspec to re-run failed spec files
# e.g.
# bin/failed_ci_specs.rb -b 1234  | xargs bundle exec rspec

require 'json'
require 'open3'
require 'pp'
require 'optparse'
require 'yaml'

options = {mode: :filenames, debug: false}
OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  opts.on("-b", "--build_num [build_num]", "CircleCI build number") do |b|
    options[:build_num] = b
  end

  opts.on("-m", "--mode [mode]", [:failures, :filenames],
          "Select mdoe (failures, filenames)") do |m|
    options[:mode] = m
  end

  opts.on("-t" "--team [team]") do |t|
    options[:team] = t
  end

  opts.on("-p" "--project [project]") do |p|
    options[:project] = p
  end

  opts.on("-d", "--debug", "Debug command") do |d|
    options[:debug] = d
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

token = ENV['CIRCLE_API_TOKEN']
filename = ".failed_ci_specs_cache.yml"

cache = if File.exists?(filename)
          YAML.load_file(filename)
        else
          {}
        end

def get_failing_specs(token, options, cache, filename)
  build_num, mode, debug, project, team = options.values_at(:build_num, :mode, :debug, :project, :team)
  failures = cache[build_num]

  unless failures
    command = "curl --fail --silent -u #{token}: \"https://circleci.com/api/v1.1/project/github/#{team}/#{project}/#{build_num}/tests\""

    STDERR.puts({ command: command }) if debug
    stdout, stderr, status = Open3.capture3(command);nil
    if status.exitstatus.zero?
      data = JSON.parse(stdout); nil
      failures = data["tests"].reject {|t| ["success", "skipped"].include?(t["result"])}
      cache[build_num] = failures
      File.write(filename, cache.to_yaml)
    else
      pp({ status: status, stderr: stderr })
      raise "Failed to get list of artifacts for build"
    end
  end

  # usage:
  # failed_ci_specs.rb -b 53341 -m filenames | xargs bundle exec rspec
  if mode == :filenames
    filenames = failures.map {|test| test["file"]}
    filenames.uniq.each do |filename|
      puts filename
    end
  end

    if mode == :failures
      failures.each do |test|
        puts "-------------------------------------------------------"
        puts "In " + test["file"]
        puts test["name"]
        puts test["message"]
        puts "\n\n"
      end
    end
end


get_failing_specs(token, options, cache, filename)
