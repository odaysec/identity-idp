# frozen_string_literal: true

module Idv
  module HybridMobile
    # Controller responsible for taking a `document-capture-session` UUID and configuring
    # the user's Session to work when they're forwarded on to document capture.
    class EntryController < ApplicationController
      include Idv::AvailabilityConcern
      include HybridMobileConcern

      def show
        return handle_invalid_document_capture_session if !validate_document_capture_session_id

        return handle_invalid_document_capture_session if !validate_document_capture_user_id

        case document_capture_session.doc_auth_vendor
        when Idp::Constants::Vendors::SOCURE, Idp::Constants::Vendors::SOCURE_MOCK
          redirect_to idv_hybrid_mobile_socure_document_capture_url
        when Idp::Constants::Vendors::MOCK, Idp::Constants::Vendors::LEXIS_NEXIS
          redirect_to idv_hybrid_mobile_document_capture_url
        end
      end

      private

      # This is the UUID present in the link sent to the user via SMS.
      # It refers to a DocumentCaptureSession instance in the DB.
      def document_capture_session_uuid
        params['document-capture-session']
      end

      # This is the effective user for whom we are uploading documents.
      def document_capture_user_id
        session[:doc_capture_user_id]
      end

      def request_id
        params.fetch(:request_id, '')
      end

      def update_sp_session
        return if sp_session[:issuer] || request_id.blank?
        StoreSpMetadataInSession.new(session: session, request_id: request_id).call
      end

      def validate_document_capture_session_id
        result = Idv::DocumentCaptureSessionForm.new(document_capture_session_uuid).submit

        if result.success?
          reset_session

          session[:doc_capture_user_id] = result.extra[:for_user_id]
          session[:document_capture_session_uuid] = document_capture_session_uuid

          update_sp_session

          true
        end
      end

      def validate_document_capture_user_id
        !!document_capture_user_id
      end
    end
  end
end
