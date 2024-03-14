# frozen_string_literal: true

require 'csv'
begin
  require 'reporting/cloudwatch_client'
  require 'reporting/cloudwatch_query_quoting'
  require 'reporting/command_line_options'
rescue LoadError => e
  warn 'could not load paths, try running with "bundle exec rails runner"'
  raise e
end

module Reporting
  class FraudMetricsLg99Report
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    module Events
      IDV_PLEASE_CALL_VISITED = 'IdV: Verify please call visited'
      IDV_SETUP_ERROR_VISITED = 'IdV: Verify setup errors visited'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Range<Time>] time_range
    def initialize(
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5
    )
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    def as_emailable_reports
      Reporting::EmailableReport.new(
        title: 'LG-99 Metrics',
        table: lg99_metrics_table,
        filename: 'lg99_metrics',
      )
    end

    def lg99_metrics_table
      [
        ['Metric', 'Total'],
        ['Unique users seeing LG-99', lg99_unique_users_count.to_s],
      ]
    rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ]
    end

    def to_csv
      CSV.generate do |csv|
        lg99_metrics_table.each do |row|
          csv << row
        end
      end
    end

    # event name => set(user ids)
    # @return Hash<String,Set<String>>
    def data
      @data ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_results.each do |row|
          event_users[row['name']] << row['user_id']
        end

        event_users
      end
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        event_names: quote(Events.all_events),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id as user_id,
        | filter name in %{event_names}
      QUERY
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end

    def lg99_unique_users_count
      @lg99_unique_users_count ||=
        (data[Events::IDV_PLEASE_CALL_VISITED] + data[Events::IDV_SETUP_ERROR_VISITED]).count
    end
  end
end
