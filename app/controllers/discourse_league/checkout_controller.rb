require_relative '../../../lib/discourse_league/billing/gateways'
require_relative '../../../lib/discourse_league/gateways/braintree'

module DiscourseLeague
  class CheckoutController < ApplicationController

    def index
      render body: nil
    end

    def submit_payment
      gateway = DiscourseLeague::Billing::Gateways.new.gateway

      products = PluginStore.get("discourse_league", "levels") || []
      product = products.select{|level| level[:id] == params[:level_id]}

      if params[:update]
        subscriptions = PluginStore.get("discourse_league", "s:" + current_user.id.to_s) || []
        user_subscription = subscriptions.select{|subscription| subscription[:product_id].to_i == params[:level_id].to_i} || []

        if user_subscription.empty?
          return render_json_error("Subscription cannot be found.")
        end

        response = gateway.update_payment(current_user.id, product[0], user_subscription[0][:subscription_id], params[:nonce])

        if response[:response].success?
          render json: success_json
        else
          render_json_error(response[:message])
        end
      else
        if product[0][:recurring]
          response = gateway.subscribe(current_user.id, product[0], params[:nonce])
        else
          response = gateway.purchase(current_user.id, product[0], params[:nonce])
        end

        if response[:response].success?
          group = Group.find(product[0][:group].to_i)
          if !group.users.include?(current_user)
            group.add(current_user)
          else
            return render_json_error I18n.t('groups.errors.member_already_exist', username: current_user.username)
          end

          if group.save
            PostCreator.create(
              DiscourseLeague.contact_user,
              target_usernames: current_user.username,
              archetype: Archetype.private_message,
              title: I18n.t('league.private_messages.sign_up_success.title', {productName: product[0][:name]}),
              raw: product[0][:welcome_message]
            )
            render json: success_json
          else
            return render_json_error(group)
          end
        else
          render_json_error(response.message)
        end
      end
    end

    def submit_paypal
      gateway = DiscourseLeague::Billing::Gateways.new.paypal

      products = PluginStore.get("discourse_league", "levels")
      product = products.select{|level| level[:id] == params[:product_id]}

      response = gateway.setup_purchase(9700,
        ip: request.remote_ip,
        return_url: request.protocol + request.host_with_port + "/league/checkout/paypal?product=" + params[:product_id].to_s,
        cancel_return_url: request.protocol + request.host_with_port + "/league/checkout/paypal/cancelled",
        currency: "USD",
        allow_guest_checkout: true,
        items: [{name: "Discourse League", description: "Discourse League", quantity: "1", amount: 9700, category: "Digital"}]
      )
      if response.success?
        render_json_dump(gateway.redirect_url_for(response.token))
      else
        render_json_error(response.message)
      end
    end

    def paypal_success
      products = PluginStore.get("discourse_league", "levels")
      product = products.select{|level| level[:id] == params[:productID].to_i}

      gateway = DiscourseLeague::Billing::Gateways.new.paypal

      if product[0][:recurring]
        response = gateway.subscribe(current_user.id, product[0], :token => params[:token], :start_date => Time.now)
      else
        initial_payment = product[0][:initial_payment].to_i * 100  # Converts ammount to cents

        response = gateway.purchase(initial_payment, {:ip => request.remote_ip, :token => params[:token], :payer_id => params[:payerID]})

        # league_gateway = DiscourseLeague::Billing::Gateways.new(:user_id => current_user.id, :product_id => product[0][:id], :token => response.params["credit_card_token"])

        # league_gateway.store_transaction(response.authorization, product[0][:initial_payment].to_i, Time.now())
      end

      if response.success?
        group = Group.find(product[0][:group].to_i)
        if !group.users.include?(current_user)
          group.add(current_user)
        else
          return render_json_error I18n.t('groups.errors.member_already_exist', username: current_user.username)
        end

        if group.save
          render json: success_json
        else
          return render_json_error(group)
        end
      else
        render_json_error(response.message)
      end
    end

    def braintree_token
      braintree = DiscourseLeague::Gateways::BraintreeGateway.new()
      token = braintree.client_token
      render plain: token
    end

    private

      def validate_card
        byebug
        @credit_card = DiscourseLeague::Billing::CreditCard.new(
          :number => params[:card_number],
          :month => params[:expiration_month],
          :year => params[:expiration_year],
          :first_name => params[:first_name],
          :last_name => params[:last_name],
          :verification_value => params[:cvv]
        )
        valid_card = @credit_card.validate

        if !valid_card.empty?
          @errors = ""
          @errors += I18n.t('league.errors.first_name') + " " + valid_card[:first_name][0] + "<br>" if !valid_card[:first_name].nil?
          @errors += I18n.t('league.errors.last_name') + " " + valid_card[:last_name][0] + "<br>" if !valid_card[:last_name].nil?
          @errors += I18n.t('league.errors.card_number') + " " + valid_card[:number][0] + "<br>" if !valid_card[:number].nil?
          @errors += I18n.t('league.errors.expiration_month') + " " + valid_card[:month][0] + "<br>" if !valid_card[:month].nil?
          @errors += I18n.t('league.errors.expiration_year') + " " + valid_card[:year][0] + "<br>" if !valid_card[:year].nil?
          @errors += I18n.t('league.errors.cvv') + " " + valid_card[:verification_value][0] + "<br>" if !valid_card[:verification_value].nil?
        end
      end

  end
end