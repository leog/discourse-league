module DiscourseLeague

  def self.contact_user
    user = User.find_by(username_lower: SiteSetting.league_contact_user.downcase) if SiteSetting.league_contact_user.present?
    user ||= (Discourse.site_contact_user || User.admins.real.order(:id).first)
  end

  class Engine < ::Rails::Engine
    isolate_namespace DiscourseLeague

    config.after_initialize do
  		Discourse::Application.routes.append do
  			mount ::DiscourseLeague::Engine, at: "/league"
  		end

      require_dependency 'current_user_serializer'
      class ::CurrentUserSerializer
        attributes :groups
      end 

      module ::Jobs

        class SubscriptionCanceled < Jobs::Base
          def execute(args)
            subscription = PluginStoreRow.where(plugin_name: "discourse_league")
              .where("key LIKE 's:%'")
              .where("value LIKE '%" + args[:id] + "%'")
              .first
            if subscription.nil?
              return
            end
            user_id = subscription.key[2..-1].to_i

            user = User.find(user_id)

            gateway = DiscourseLeague::Billing::Gateways.new.gateway
            response = gateway.unsubscribe(JSON.parse(subscription.value)[0]["subscription_id"])

            if response.success? && user

              league_gateway = DiscourseLeague::Billing::Gateways.new(:user_id => user_id, :product_id => JSON.parse(subscription.value)[0]["product_id"])
              league_gateway.unstore_subscription

              levels = PluginStore.get("discourse_league", "levels")
              level = levels.select{|level| level[:id] == JSON.parse(subscription.value)[0]["product_id"].to_i}

              group = Group.find(level[0][:group].to_i)
              if group.users.include?(user)
                group.remove(user)
              end

              if group.save
                PostCreator.create(
                  DiscourseLeague.contact_user,
                  target_usernames: user.username,
                  archetype: Archetype.private_message,
                  title: I18n.t('league.private_messages.subscription_canceled.title', {productName: level[0][:name]}),
                  raw: I18n.t('league.private_messages.subscription_canceled.message', {productName: level[0][:name]})
                )
              end
            end
          end
        end

        class SubscriptionChargedUnsuccessfully < Jobs::Base
          def execute(args)
            subscription = PluginStoreRow.where(plugin_name: "discourse_league")
              .where("key LIKE 's:%'")
              .where("value LIKE '%" + args[:id] + "%'")
              .first
            if subscription.nil?
              return
            end
            user_id = subscription.key[2..-1].to_i

            user = User.find(user_id)

            gateway = DiscourseLeague::Billing::Gateways.new.gateway
            response = gateway.unsubscribe(JSON.parse(subscription.value)[0]["subscription_id"])

            if response.success? && user

              league_gateway = DiscourseLeague::Billing::Gateways.new(:user_id => user_id, :product_id => JSON.parse(subscription.value)[0]["product_id"])
              league_gateway.unstore_subscription

              levels = PluginStore.get("discourse_league", "levels")
              level = levels.select{|level| level[:id] == JSON.parse(subscription.value)[0]["product_id"].to_i}

              group = Group.find(level[0][:group].to_i)
              if group.users.include?(user)
                group.remove(user)
              end

              if group.save
                PostCreator.create(
                  DiscourseLeague.contact_user,
                  target_usernames: user.username,
                  archetype: Archetype.private_message,
                  title: I18n.t('league.private_messages.subscription_charged_unsuccessfully.title', {productName: level[0][:name]}),
                  raw: I18n.t('league.private_messages.subscription_charged_unsuccessfully.message', {productName: level[0][:name]})
                )
              end
            end
          end
        end

        class SubscriptionChargedSuccessfully < Jobs::Base
          def execute(args)
            subscription = PluginStoreRow.where(plugin_name: "discourse_league")
              .where("key LIKE 's:%'")
              .where("value LIKE '%" + args[:id] + "%'")
              .first
            if subscription.nil?
              return
            end
            user_id = subscription.key[2..-1].to_i

            league_gateway = DiscourseLeague::Billing::Gateways.new(:user_id => user_id, :product_id => JSON.parse(subscription.value)[0]["product_id"])

            if args[:options][:credit_card]
              credit_card = {
                name: args[:options][:credit_card][:name],
                last_4: args[:options][:credit_card][:last_5],
                expiration: args[:options][:credit_card][:expiration],
                brand: args[:options][:credit_card][:brand],
                image: args[:options][:credit_card][:image]
              }
            else
              credit_card = {
                name: nil,
                last_4: nil,
                expiration: nil,
                brand: nil,
                image: nil
              }
            end
            if args[:options][:paypal]
              paypal = {
                email: args[:options][:paypal][:email],
                first_name: args[:options][:paypal][:first_name],
                last_name: args[:options][:paypal][:last_name],
                image: args[:options][:paypal][:image]
              }
            else
              paypal = {
                email: nil,
                first_name: nil,
                last_name: nil,
                image: nil
              }
            end

            league_gateway.store_transaction(args[:options][:transaction_id], args[:options][:transaction_amount], Time.now(), credit_card, paypal)

            league_gateway = DiscourseLeague::Billing::Gateways.new(:user_id => user_id, :product_id => JSON.parse(subscription.value)[0]["product_id"])

            value = JSON.parse(subscription.value)
            value[0]["subscription_end_date"] = args[:options][:paid_through]

            json = value.to_json
            subscription.value = json
            subscription.save
          end
        end

      end

    end

  end
end