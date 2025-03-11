# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::IdTypePolicy do
  let(:bucketed_vendor) { 'lexis_nexis' }
  let(:passports_available) { true }
  let(:idv_session) { instance_double(Idv::Session, bucketed_doc_auth_vendor: bucketed_vendor) }
  subject { described_class.new(idv_session: idv_session) }

  before do
    allow(subject).to receive(:passport_option_available?).and_return(passports_available)
  end

  context 'when user is bucketed to lexis_nexis' do
    let(:bucketed_vendor) { 'lexis_nexis' }

    context 'when passports are enabled' do
      let(:passports_available) { true }

      it 'allows passports' do
        expect(subject.allow_passport?).to eq(true)
      end
    end

    context 'when passports are disabled' do
      let(:passports_available) { false }

      it 'does not allow passports' do
        expect(subject.allow_passport?).to eq(false)
      end
    end
  end

  context 'when user is bucketed to socure' do
    let(:bucketed_vendor) { 'socure' }

    context 'when passports are enabled' do
      let(:passports_available) { true }

      it 'does not allow passports' do
        expect(subject.allow_passport?).to eq(false)
      end
    end

    context 'when passports are disabled' do
      let(:passports_available) { false }

      it 'does not allow passports' do
        expect(subject.allow_passport?).to eq(false)
      end
    end
  end
end
