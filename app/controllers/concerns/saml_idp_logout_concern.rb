require 'saml_idp/logout_response_builder'

module SamlIdpLogoutConcern
  extend ActiveSupport::Concern

  private

  def sign_out_with_flash
    track_logout_event
    sign_out if user_signed_in?
    flash[:success] = t('devise.sessions.signed_out')
    redirect_to root_url
  end

  def handle_valid_sp_logout_request
    render_template_for(
      Base64.strict_encode64(logout_response),
      saml_request.response_url,
      'SAMLResponse',
    )
    sign_out if user_signed_in?
  end

  def handle_valid_sp_remote_logout_request(user_id)
    # Remotely invalidate the user's current session, see config/initializers/session_limitable.rb
    User.find(user_id).update!(unique_session_id: nil)

    render inline: logout_response, content_type: 'text/xml'
  end

  def find_user_from_session_index
    uuid = saml_request.session_index
    issuer = saml_request.issuer
    agency_id = ServiceProvider.find_by(issuer: issuer).agency_id
    user_id = AgencyIdentity.find_by(agency_id: agency_id, uuid: uuid)&.user_id
    # ensure that the user has authenticated to that SP
    ServiceProviderIdentity.find_by(user_id: user_id, service_provider: issuer)&.user_id
  end

  def logout_response
    encode_response(
      current_user,
      signature: saml_response_signature_options,
    )
  end

  def track_logout_event
    sp_initiated = saml_request.present?
    analytics.track_event(
      Analytics::LOGOUT_INITIATED,
      sp_initiated: sp_initiated,
      oidc: false,
      saml_request_valid: sp_initiated ? valid_saml_request? : true,
    )
  end

  def track_remote_logout_event
    analytics.track_event(
      Analytics::REMOTE_LOGOUT_INITIATED,
      service_provider: saml_request&.issuer,
      saml_request_valid: valid_saml_request?,
    )
  end

  def saml_response_signature_options
    endpoint = SamlEndpoint.new(request)
    {
      x509_certificate: endpoint.x509_certificate,
      secret_key: endpoint.secret_key,
    }
  end
end
