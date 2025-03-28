# frozen_string_literal: true

class AddUserEmailForm
  include ActiveModel::Model
  include FormAddEmailValidator
  include ActionView::Helpers::TranslationHelper

  attr_reader :email, :in_select_email_flow
  alias_method :in_select_email_flow?, :in_select_email_flow

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(in_select_email_flow: false)
    @in_select_email_flow = in_select_email_flow
  end

  def user
    @user ||= User.new
  end

  def submit(user, params)
    @user = user
    @email = params[:email]
    @email_address = email_address_record(@email)
    @request_id = params[:request_id]
    if valid?
      process_successful_submission
    else
      @success = false
    end

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def email_address_record(email)
    record = EmailAddress.where(user_id: user.id).find_with_email(email) ||
             EmailAddress.new(user_id: user.id, email: email)

    record.confirmation_token = SecureRandom.uuid
    record.confirmation_sent_at = Time.zone.now

    record
  end

  private

  attr_writer :email
  attr_reader :success, :email_address, :request_id

  def process_successful_submission
    @success = true
    email_address.save!
    SendAddEmailConfirmation.new(user)
      .call(email_address:, in_select_email_flow: in_select_email_flow?, request_id:)
  end

  def extra_analytics_attributes
    {
      user_id: existing_user.uuid,
      domain_name: email&.split('@')&.last,
      in_select_email_flow: in_select_email_flow?,
    }
  end

  def existing_user
    @existing_user ||= User.find_with_email(email) || AnonymousUser.new
  end
end
