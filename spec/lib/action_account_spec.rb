require 'rails_helper'
require 'tableparser'
require 'action_account'

RSpec.describe ActionAccount do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:argv) { [] }

  subject(:action_account) { ActionAccount.new(argv:, stdout:, stderr:) }

  describe 'command line flags' do
    let(:argv) { ['review-pass', user.uuid] }
    let(:user) { create(:user) }

    describe '--help' do
      before { argv << '--help' }
      it 'prints a help message' do
        action_account.run

        expect(stdout.string).to include('Options:')
      end

      it 'prints help to stderr', aggregate_failures: true do
        action_account.run

        expect(stderr.string).to include('*Task*: `help`')
        expect(stderr.string).to include('*UUIDs*: N/A')
      end
    end

    describe '--csv' do
      before { argv << '--csv' }
      it 'formats output as CSV' do
        action_account.run

        expect(CSV.parse(stdout.string)).to eq(
          [
            ['uuid', 'status'],
            [user.uuid, 'Error: User does not have a pending fraud review'],
          ],
        )
      end
    end

    describe '--table' do
      before { argv << '--table' }
      it 'formats output as an ASCII table' do
        action_account.run

        expect(Tableparser.parse(stdout.string)).to eq(
          [
            ['uuid', 'status'],
            [user.uuid, 'Error: User does not have a pending fraud review'],
          ],
        )
      end
    end

    it 'logs UUIDs and the command name to STDERR formatted for Slack', aggregate_failures: true do
      action_account.run

      expect(stderr.string).to include('`review-pass`')
      expect(stderr.string).to include("`#{user.uuid}`")
    end

    describe '--json' do
      before { argv << '--json' }
      it 'formats output as JSON' do
        action_account.run

        expect(JSON.parse(stdout.string)).to eq(
          [
            {
              'uuid' => user.uuid,
              'status' => 'Error: User does not have a pending fraud review',
            },
          ],
        )
      end
    end

    describe '--include-missing' do
      let(:argv) { ['review-reject', 'does_not_exist@example.com', '--include-missing', '--json'] }
      it 'adds rows for missing values' do
        action_account.run

        expect(JSON.parse(stdout.string)).to eq(
          [
            {
              'uuid' => 'does_not_exist@example.com',
              'status' => 'Error: Could not find user with that UUID',
            },
          ],
        )
      end
    end

    describe '--no-include-missing' do
      let(:argv) do
        ['review-reject', 'does_not_exist@example.com', '--no-include-missing', '--json']
      end
      it 'does not add rows for missing values' do
        action_account.run

        expect(JSON.parse(stdout.string)).to be_empty
      end
    end
  end

  describe ActionAccount::ReviewReject do
    subject(:subtask) { ActionAccount::ReviewReject.new }

    describe '#run' do
      let(:user) { create(:profile, :fraud_review_pending).user }
      let(:user_without_profile) { create(:user) }

      let(:args) { [user.uuid, user_without_profile.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:) }
      subject(:result) { subtask.run(args:, config:) }

      it 'Reject a user that has a pending review', aggregate_failures: true do
        expect(result.table).to match_array(
          [
            ['uuid', 'status'],
            [user.uuid, "User's profile has been deactivated due to fraud rejection."],
            [user_without_profile.uuid, 'Error: User does not have a pending fraud review'],
            ['uuid-does-not-exist', 'Error: Could not find user with that UUID'],
          ],
        )

        expect(result.subtask).to eq('review-reject')
        expect(result.uuids).to match_array([user.uuid, user_without_profile.uuid])
      end
    end
  end

  describe ActionAccount::ReviewPass do
    subject(:subtask) { ActionAccount::ReviewPass.new }

    describe '#run' do
      let(:user) { create(:profile, :fraud_review_pending).user }
      let(:user_without_profile) { create(:user) }

      let(:args) { [user.uuid, user_without_profile.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:) }
      subject(:result) { subtask.run(args:, config:) }

      it 'Pass a user that has a pending review', aggregate_failures: true do
        expect(result.table).to match_array(
          [
            ['uuid', 'status'],
            [user.uuid, "User's profile has been activated and the user has been emailed."],
            [user_without_profile.uuid, 'Error: User does not have a pending fraud review'],
            ['uuid-does-not-exist', 'Error: Could not find user with that UUID'],
          ],
        )

        expect(result.subtask).to eq('review-pass')
        expect(result.uuids).to match_array([user.uuid, user_without_profile.uuid])
      end
    end
  end
end
