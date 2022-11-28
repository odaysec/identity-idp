require 'rails_helper'

describe Analytics do
  let(:analytics_attributes) do
    {
      user_id: current_user.uuid,
      new_event: true,
      new_session_path: true,
      new_session_success_state: true,
      success_state: success_state,
      path: path,
      session_duration: nil,
      locale: I18n.locale,
      git_sha: IdentityConfig::GIT_SHA,
      git_branch: IdentityConfig::GIT_BRANCH,
      event_properties: {},
    }.merge(request_attributes)
  end

  let(:request_attributes) do
    {
      user_ip: FakeRequest.new.remote_ip,
      user_agent: FakeRequest.new.user_agent,
      browser_name: 'Unknown Browser',
      browser_version: '0.0',
      browser_platform_name: 'Unknown',
      browser_platform_version: '0',
      browser_device_name: 'Unknown',
      browser_mobile: false,
      browser_bot: false,
      hostname: FakeRequest.new.host,
      pid: Process.pid,
      service_provider: 'http://localhost:3000',
      trace_id: nil,
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }
  let(:current_user) { build_stubbed(:user, uuid: '123') }
  let(:request) { FakeRequest.new }
  let(:path) { 'fake_path' }
  let(:success_state) { 'GET|fake_path|Trackable Event' }

  subject(:analytics) do
    Analytics.new(
      user: current_user,
      request: request,
      sp: 'http://localhost:3000',
      session: {},
      ahoy: ahoy,
    )
  end

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      stub_const(
        'IdentityConfig::GIT_BRANCH',
        'my branch',
      )

      expect(ahoy).to receive(:track).with('Trackable Event', analytics_attributes)

      analytics.track_event('Trackable Event')
    end

    it 'does not track unique events and paths when an event fails' do
      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(
          new_event: nil,
          new_session_path: nil,
          new_session_success_state: nil,
          event_properties: { success: false },
        ),
      )

      analytics.track_event('Trackable Event', { success: false })
    end

    it 'tracks the user passed in to the track_event method' do
      tracked_user = build_stubbed(:user, uuid: '456')

      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(user_id: tracked_user.uuid),
      )

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end

    context 'tracing headers' do
      let(:amazon_trace_id) { SecureRandom.hex }
      let(:request) do
        FakeRequest.new(headers: { 'X-Amzn-Trace-Id' => amazon_trace_id })
      end

      it 'includes the tracing header as trace_id' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(trace_id: amazon_trace_id))

        analytics.track_event('Trackable Event')
      end
    end

    context 'analytics ID' do
      let(:request_url) { 'http://localhost:3000/authorize?inherited_proofing_auth=key' }
      let(:service_provider) { { request_url: request_url } }
      let(:session) { { sp: service_provider } }

      let(:analytics) do
        Analytics.new(
          user: current_user,
          request: request,
          sp: 'http://localhost:3000',
          session: session,
          ahoy: ahoy,
        )
      end

      it 'adds analytics ID for inherited proofing sessions' do
        expect(ahoy).to receive(:track).with(
          'Trackable Event',
          analytics_attributes.merge({ analytics_id: 'Inherited Proofing' }),
        )

        analytics.track_event('Trackable Event')

        expect(session).to include({ analytics_id: 'Inherited Proofing' })
      end

      it 'uses the analytics ID from the session variable, overriding request_url' do
        session[:analytics_id] = 'Analytics ID From Session'

        expect(ahoy).to receive(:track).with(
          'Trackable Event',
          analytics_attributes.merge({ analytics_id: 'Analytics ID From Session' }),
        )

        analytics.track_event('Trackable Event')

        expect(session).to include({ analytics_id: 'Analytics ID From Session' })
      end

      it 'allows the caller to set the analytics ID in event_properties (legacy usage)' do
        session[:analytics_id] = 'Analytics ID From Session'
        analytics_attributes[:analytics_id] = 'Analytics ID From Caller'
        analytics_attributes[:event_properties][:analytics_id] = 'Analytics ID From Caller'

        expect(ahoy).to receive(:track).with('Trackable Event', analytics_attributes)

        analytics.track_event(
          'Trackable Event',
          { analytics_id: 'Analytics ID From Caller' },
        )

        expect(session).to include({ analytics_id: 'Analytics ID From Caller' })
      end

      it 'does not set the session analytics ID if analytics ID is not specified' do
        request_url = 'http://localhost:3000/authorize?some_param'
        service_provider = { request_url: request_url }
        session = { sp: service_provider }
        analytics.instance_variable_set(:@session, session)

        expect(ahoy).to receive(:track).with('Trackable Event', analytics_attributes)

        analytics.track_event('Trackable Event')

        expect(session).not_to include(:analytics_id)
      end
    end

    it 'includes the locale of the current request' do
      locale = :fr
      allow(I18n).to receive(:locale).and_return(locale)

      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(locale: locale),
      )

      analytics.track_event('Trackable Event')
    end

    # relies on prepending the FakeAnalytics::PiiAlerter mixin
    it 'throws an error when pii is passed in' do
      allow(ahoy).to receive(:track)

      expect { analytics.track_event('Trackable Event') }.to_not raise_error

      expect { analytics.track_event('Trackable Event', first_name: 'Bobby') }.
        to raise_error(FakeAnalytics::PiiDetected)

      expect do
        analytics.track_event('Trackable Event', nested: [{ value: { first_name: 'Bobby' } }])
      end.to raise_error(FakeAnalytics::PiiDetected)

      expect { analytics.track_event('Trackable Event', decrypted_pii: '{"first_name":"Bobby"}') }.
        to raise_error(FakeAnalytics::PiiDetected)
    end

    it 'throws an error when it detects sample PII in the payload' do
      allow(ahoy).to receive(:track)

      expect { analytics.track_event('Trackable Event', some_benign_key: 'FAKEY MCFAKERSON') }.
        to raise_error(FakeAnalytics::PiiDetected)
    end

    it 'does not alert when pii_like_keypaths is passed' do
      allow(ahoy).to receive(:track) do |_name, attributes|
        # does not forward :pii_like_keypaths
        expect(attributes.to_s).to_not include('pii_like_keypaths')
      end

      expect do
        analytics.track_event(
          'Trackable Event',
          mfa_method_counts: { phone: 1 },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        )
      end.to_not raise_error
    end

    it 'does not alert when pii values are inside words' do
      expect(ahoy).to receive(:track)

      stub_const('Idp::Constants::MOCK_IDV_APPLICANT', zipcode: '12345')

      expect do
        analytics.track_event(
          'Trackable Event',
          some_uuid: '12345678-1234-1234-1234-123456789012',
        )
      end.to_not raise_error
    end
  end

  it 'tracks session duration' do
    freeze_time do
      analytics = Analytics.new(
        user: current_user,
        request: request,
        sp: 'http://localhost:3000',
        session: { session_started_at: 7.seconds.ago },
        ahoy: ahoy,
      )

      expect(ahoy).to receive(:track).with(
        'Trackable Event',
        analytics_attributes.merge(session_duration: 7.0),
      )

      analytics.track_event('Trackable Event')
    end
  end
end
