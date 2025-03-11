# frozen_string_literal: true

module Idv
  class IdTypePolicy
    def initialize(idv_session:)
      @idv_session = idv_session
    end

    def allow_passport?
      # IdentityConfig.store.dos_passport_enabled && # TODO: update once flag defined
      lexis_nexis? && passport_option_available?
    end

    private

    attr_reader :idv_session

    def lexis_nexis?
      vendor = idv_session&.bucketed_doc_auth_vendor&.to_sym
      vendor == :lexis_nexis || vendor == :mock
    end

    def passport_option_available?
      true # ab_test_bucket(:PASSPORT) == :available # TODO: update once AB test defined
    end
  end
end
