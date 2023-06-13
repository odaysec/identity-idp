require_relative './script_base'

class ActionAccount
  attr_reader :argv, :stdout, :stderr

  def initialize(argv:, stdout:, stderr:)
    @argv = argv
    @stdout = stdout
    @stderr = stderr
  end

  def script_base
    @script_base ||= ScriptBase.new(
      argv:,
      stdout:,
      stderr:,
      subtask_class: subtask(argv.shift),
      banner: banner,
    )
  end

  def run
    script_base.run
  end

  def banner
    basename = File.basename($PROGRAM_NAME)
    <<~EOS
      #{basename} [subcommand] [arguments] [options]
        Example usage:

          * #{basename} review-reject uuid1 uuid2

          * #{basename} review-pass uuid1 uuid2

        Options:
    EOS
  end

  # @api private
  # A subtask is a class that has a run method, the type signature should look like:
  # +#run(args: Array<String>, config: Config) -> Result+
  # @return [Class,nil]
  def subtask(name)
    {
      'review-reject' => ReviewReject,
      'review-pass' => ReviewPass,
    }[name]
  end

  class ReviewReject
    def log_message(uuid, log, table, messages)
      table << [uuid, log]
      messages << uuid + ' : ' + log
      return table, messages
    end

    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status]

      messages = []

      users.each do |user|
        if !user.fraud_review_pending?
          table, messages = log_message(user.uuid, 'Error: User does not have a pending fraud review', table, messages)
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile.reject_for_fraud(notify_user: true)

          table, messages = log_message(user.uuid, "User's profile has been deactivated due to fraud rejection.", table, messages)
        else
          table, messages = log_message(user.uuid, 'User is past the 30 day review eligibility', table, messages)
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table, messages = log_message(missing_uuid, 'Error: Could not find user with that UUID', table, messages)
        end
      end

      ScriptBase::Result.new(
        subtask: 'review-reject',
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end
  end

  class ReviewPass
    def log_message(uuid, log, table, messages)
      table << [uuid, log]
      messages << uuid + ' : ' + log
      return table, messages
    end

    def run(args:, config:)
      uuids = args

      users = User.where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid status]

      messages = []
      users.each do |user|
        if !user.fraud_review_pending?
          table, messages = log_message(user.uuid, 'Error: User does not have a pending fraud review', table, messages)
        elsif FraudReviewChecker.new(user).fraud_review_eligible?
          profile = user.fraud_review_pending_profile
          profile.activate_after_passing_review

          if profile.active?
            event, _disavowal_token = UserEventCreator.new(current_user: user).
              create_out_of_band_user_event(:account_verified)

            UserAlerts::AlertUserAboutAccountVerified.call(
              user: user,
              date_time: event.created_at,
              sp_name: nil,
            )

            table, messages = log_message(user.uuid, "User's profile has been activated and the user has been emailed.", table, messages)
          else
            table, messages = log_message(user.uuid, "There was an error activating the user's profile. Please try again.", table, messages)
          end
        else
          table, messages = log_message(user.uuid, 'User is past the 30 day review eligibility.', table, messages)
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table, messages = log_message(missing_uuid, 'Error: Could not find user with that UUID', table, messages)
        end
      end

      ScriptBase::Result.new(
        subtask: 'review-pass',
        uuids: users.map(&:uuid),
        messages:,
        table:,
      )
    end
  end
end
