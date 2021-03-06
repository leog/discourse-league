require_relative '../../../lib/discourse_league/gateways/braintree'

module DiscourseLeague
  class WebhookController < ApplicationController
    skip_before_action :redirect_to_login_if_required
    layout false
    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token, only: [:braintree]
    def braintree
      braintree = DiscourseLeague::Gateways::BraintreeGateway.new()
      braintree.parse_webhook(request)
      render body: nil
    end

  end
end