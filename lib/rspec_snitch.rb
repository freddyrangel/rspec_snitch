require "rspec_snitch/version"
require 'octokit'

module RspecSnitch

  def self.new(*args)
    Snitch.new(*args)
  end

  class Snitch

    def initialize(access_token, repo, config)
      @github       ||= Octokit::Client.new(access_token: access_token)
      @issue_titles ||= @github.list_issues(repo, state: 'open').map(&:title)
      @examples     ||= config.instance_variable_get(:@reporter)
      generate_pending_issues
    end

    private

    def generate_pending_issues
      report_examples if reportable_examples.any? && user_wants_report?
    end

    def report_examples
      @reportable_examples.each do |example|
        title = example.full_description
        body = "#{example.location}\n\nThis issue was generated by rspec-snitch."
        @github.create_issue(repo, title, body)
        # TODO: Reopen issue if one exists, but is closed.
      end
    end

    def reportable_examples
      @reportable_examples ||= @examples.pending_examples.keep_if do |example|
        example.pending? && @issue_titles.exclude?(example.full_description)
      end
    end

    def user_wants_report?
      thor = Thor::Shell::Basic.new
      question = "#{pluralize(reportable_examples.size, 'issue')} to report. Snitch to GitHub? (y/n):"
      thor.yes?(question)
    end
  end
end
