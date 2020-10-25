#!/usr/bin/env ruby
require 'github_api'
require 'net/http'
require 'oj'

USER = 'koki1023'
REPO = 'codecov-test'
CIRCLE_CI_TOKEN = ENV['CIRCLE_CI_TOKEN']
ARTIFACT_INDEX_PATH = "coverage/index.html"
GITHUB_TOKEN = ENV['GITHUB_TOKEN']
GITHUB_CLIENT = Github.new(user: USER, repo: REPO, oauth_token: GITHUB_TOKEN)

def get_artifacts
    http = Net::HTTP.new('circleci.com', 443)
    http.use_ssl = true

    puts "Will get artifacts of #{ENV["CIRCLE_BUILD_NUM"]} build"
    request = Net::HTTP::Get.new("/api/v1.1/project/github/#{USER}/#{REPO}/#{ENV["CIRCLE_BUILD_NUM"]}/artifacts", {
        "Content-Type" => "application/json",
        "Circle-Token" => CIRCLE_CI_TOKEN
    })
    begin
        http.request(request).body
    rescue => e
        puts "Net Request failed: #{e.message}"
        exit(0)
    end
end

def get_artifact_url
    artifacts = Oj.load(get_artifacts, mode: :compat)
    index_html_artifact = artifacts.find { |artifact| artifact["path"] == ARTIFACT_INDEX_PATH }

    if index_html_artifact.nil?
        puts "Failed to get index html artifact"
        exit(0)
    end

    index_html_artifact["url"]
end

def notify_coverage_report_url
    delete_existing_reports
    begin
        GITHUB_CLIENT.issues.comments.create(USER, REPO, '3', body: get_artifact_url)
    rescue Github::Error::GithubError => e
        puts "Faile to notify comment: #{e.message}"
        exit(0)
    end

    puts "Succeeded to notify report url"
end

def delete_existing_reports
    comments = GITHUB_CLIENT.issues.comments.list(USER, REPO, '3').body
    reporter_user_comment_ids = comments.map do |comment|
        if comment.user.login == USER
            comment.id
        end
    end.compact

    reporter_user_comment_ids.each do |id| 
        begin
            puts "Will delete comment, id: #{id}"
            GITHUB_CLIENT.issues.comments.delete(USER, REPO, id)
        rescue Github::Error::GithubError => e
            puts "Faile to delete comment: #{e.message}"
        end
    end

    puts "Finished deleting comments"
end

notify_coverage_report_url
