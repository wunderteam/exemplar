#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'pp'

token = ENV['CIRCLE_API_TOKEN']

def recent_successful_builds(token, max)
  max = [max, 100].min

  command = "curl --fail --silent -u #{token}: \"https://circleci.com/api/v1.1/project/github/wunderteam/exemplar?limit=#{max}&filter=successful&shallow=true\""

  pp({ command: command })

  stdout, stderr, status = Open3.capture3(command)

  if status.exitstatus.zero?
    data = JSON.parse(stdout)

    data.
      select { |build| build["workflows"]["job_name"] == "rspec" && build["outcome"] == "success" }.
      map { |build| { sha: build["vcs_revision"], build_num: build["build_num"] } }
  else
    pp({ status: status, stderr: stderr })
    raise "Failed to get recent builds"
  end
end

def find_successful_identical_build(token, max)
  builds = recent_successful_builds(token, max)
  builds.each do |build|
    sha = build[:sha]
    build_num = build[:build_num]

    command = "git diff --no-patch --exit-code #{sha}"
    pp({ command: command })

    _stdout, _stderr, status = Open3.capture3(command)

    pp({ sha: sha, diff_status: status.exitstatus, build_num: build_num })

    if status.exitstatus.zero? # rubocop:disable Style/GuardClause
      pp({ message: :build_found, sha: sha, build_num: build_num })
      exit 0
    else
      next
    end
  end

  pp({ message: :no_build_found })
  exit 1
rescue RuntimeError => e
  puts e
  exit 1
end

find_successful_identical_build(token, 100)
