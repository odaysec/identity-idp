module Proofing
  module Resolution
    # Uses a combination of LexisNexis InstantVerify and AAMVA checks to verify that
    # a user's identity can be resolved against authoritative sources. This includes logic for when:
    #   1. The user is or is not within an AAMVA-participating jurisdiction
    #   2. The user has only provided one address for their residential and identity document
    #      address or separate residential and identity document addresses
    class ProgressiveProofer
      # @param [Hash] applicant_pii keys are symbols and values are strings, confidential user info
      # @param [Boolean] double_address_verification flag that indicates if user will have
      #   both state id address and current residential address verified
      # @param [String] request_ip IP address for request
      # @param [Boolean] should_proof_state_id based on state id jurisdiction, indicates if
      #   there should be a state id proofing request made to aamva
      # @param [String] threatmetrix_session_id identifies the threatmetrix session
      # @param [JobHelpers::Timer] timer indicates time elapsed to obtain results
      # @param [String] user_email email address for applicant
      # @return [ResultAdjudicator] object which contains the logic to determine proofing's result
      def proof(
        applicant_pii:,
        double_address_verification:,
        request_ip:,
        should_proof_state_id:,
        threatmetrix_session_id:,
        timer:,
        user_email:
      )
        device_profiling_result = proof_with_threatmetrix_if_needed(
          applicant_pii: applicant_pii,
          request_ip: request_ip,
          threatmetrix_session_id: threatmetrix_session_id,
          timer: timer,
          user_email: user_email,
        )

        # todo(LG-8693): Begin verifying both the user's residential address and identity document
        # address
        applicant_pii = with_state_id_address(applicant_pii) if double_address_verification

        resolution_result = proof_resolution(
          applicant_pii: applicant_pii,
          timer: timer,
        )
        state_id_result = proof_state_id_if_needed(
          applicant_pii: applicant_pii,
          timer: timer,
          resolution_result: resolution_result,
          should_proof_state_id: should_proof_state_id,
        )

        ResultAdjudicator.new(
          device_profiling_result: device_profiling_result,
          double_address_verification: double_address_verification,
          resolution_result: resolution_result,
          should_proof_state_id: should_proof_state_id,
          state_id_result: state_id_result,
        )
      end

      private

      def proof_with_threatmetrix_if_needed(
        applicant_pii:,
        user_email:,
        threatmetrix_session_id:,
        request_ip:,
        timer:
      )
        unless FeatureManagement.proofing_device_profiling_collecting_enabled?
          return threatmetrix_disabled_result
        end

        # The API call will fail without a session ID, so do not attempt to make
        # it to avoid leaking data when not required.
        return threatmetrix_disabled_result if threatmetrix_session_id.blank?

        return threatmetrix_disabled_result unless applicant_pii

        ddp_pii = applicant_pii.dup
        ddp_pii[:threatmetrix_session_id] = threatmetrix_session_id
        ddp_pii[:email] = user_email
        ddp_pii[:request_ip] = request_ip

        timer.time('threatmetrix') do
          lexisnexis_ddp_proofer.proof(ddp_pii)
        end
      end

      def proof_resolution(applicant_pii:, timer:)
        timer.time('resolution') do
          resolution_proofer.proof(applicant_pii)
        end
      end

      def proof_state_id_if_needed(
        applicant_pii:, timer:,
        resolution_result:,
        should_proof_state_id:
      )
        unless should_proof_state_id && user_can_pass_after_state_id_check?(resolution_result)
          return out_of_aamva_jurisdiction_result
        end

        timer.time('state_id') do
          state_id_proofer.proof(applicant_pii)
        end
      end

      def user_can_pass_after_state_id_check?(resolution_result)
        return true if resolution_result.success?
        # For failed IV results, this method validates that the user is eligible to pass if the
        # failed attributes are covered by the same attributes in a successful AAMVA response
        # aka the Get-to-Yes w/ AAMVA feature.
        return false unless resolution_result.failed_result_can_pass_with_additional_verification?

        attributes_aamva_can_pass = [:address, :dob, :state_id_number]
        results_that_cannot_pass_aamva =
          resolution_result.attributes_requiring_additional_verification - attributes_aamva_can_pass

        results_that_cannot_pass_aamva.blank?
      end

      def threatmetrix_disabled_result
        Proofing::DdpResult.new(
          success: true,
          client: 'tmx_disabled',
          review_status: 'pass',
        )
      end

      def out_of_aamva_jurisdiction_result
        Proofing::StateIdResult.new(
          errors: {},
          exception: nil,
          success: true,
          vendor_name: 'UnsupportedJurisdiction',
        )
      end

      def lexisnexis_ddp_proofer
        @lexisnexis_ddp_proofer ||=
          if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
            Proofing::Mock::DdpMockClient.new
          else
            Proofing::LexisNexis::Ddp::Proofer.new(
              api_key: IdentityConfig.store.lexisnexis_threatmetrix_api_key,
              org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
              base_url: IdentityConfig.store.lexisnexis_threatmetrix_base_url,
            )
          end
      end

      def resolution_proofer
        @resolution_proofer ||=
          if IdentityConfig.store.proofer_mock_fallback
            Proofing::Mock::ResolutionMockClient.new
          else
            Proofing::LexisNexis::InstantVerify::Proofer.new(
              instant_verify_workflow: IdentityConfig.store.lexisnexis_instant_verify_workflow,
              account_id: IdentityConfig.store.lexisnexis_account_id,
              base_url: IdentityConfig.store.lexisnexis_base_url,
              username: IdentityConfig.store.lexisnexis_username,
              password: IdentityConfig.store.lexisnexis_password,
              request_mode: IdentityConfig.store.lexisnexis_request_mode,
            )
          end
      end

      def state_id_proofer
        @state_id_proofer ||=
          if IdentityConfig.store.proofer_mock_fallback
            Proofing::Mock::StateIdMockClient.new
          else
            Proofing::Aamva::Proofer.new(
              auth_request_timeout: IdentityConfig.store.aamva_auth_request_timeout,
              auth_url: IdentityConfig.store.aamva_auth_url,
              cert_enabled: IdentityConfig.store.aamva_cert_enabled,
              private_key: IdentityConfig.store.aamva_private_key,
              public_key: IdentityConfig.store.aamva_public_key,
              verification_request_timeout: IdentityConfig.store.aamva_verification_request_timeout,
              verification_url: IdentityConfig.store.aamva_verification_url,
            )
          end
      end

      # Make a copy of pii with the user's state ID address overwriting the address keys
      def with_state_id_address(pii)
        pii.transform_keys(SECONDARY_ID_ADDRESS_MAP)
      end

      SECONDARY_ID_ADDRESS_MAP = {
        identity_doc_address1: :address1,
        identity_doc_address2: :address2,
        identity_doc_city: :city,
        identity_doc_address_state: :state,
        identity_doc_zipcode: :zipcode,
      }.freeze
    end
  end
end
