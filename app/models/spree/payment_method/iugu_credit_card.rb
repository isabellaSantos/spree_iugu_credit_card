module Spree
  class PaymentMethod::IuguCreditCard < PaymentMethod

    preference :test_mode, :boolean, default: true
    preference :account_id, :string, default: ''
    preference :api_key, :string, default: ''
    preference :maximum_portions, :integer, default: 12
    preference :minimum_value, :decimal, default: 0.0
    preference :portions_without_tax, :integer, default: 1
    preference :min_value_without_tax, :decimal, default: 0.0
    preference :tax_value_per_months, :hash, default: {}

    def auto_capture
      true
    end

    def payment_source_class
      Spree::CreditCard
    end

    def authorize(amount, source, *args)
      self.purchase(amount, source, args)
    end

    def purchase(amount, source, *args)
      return ActiveMerchant::Billing::Response.new(false, Spree.t(:iugu_credit_card_portion), {}, authorization: '') if source.portions.nil?

      Iugu.api_key = preferred_api_key
      gateway_options = args.first
      billing_address = gateway_options[:billing_address]
      order_number, payment_number = gateway_options[:order_id].split('-')
      order = Spree::Order.friendly.find order_number

      # Create token
      name = source.name.split(' ')
      firstname = name.first
      lastname = name[1..-1].join(' ')
      token_params = {
        account_id: preferred_account_id,
        method: 'credit_card',
        test: preferred_test_mode,
        data: {
          number: source.number,
          verification_value: source.verification_value,
          first_name: firstname,
          last_name: lastname,
          month: source.month,
          year: source.year
        }
      }
      token = Iugu::PaymentToken.create(token_params)

      if token.errors.present?
        if token.errors.is_a? Hash
          message = token.errors.inject(Array.new) { |arr, i| arr += i[1] }.join('. ')
        else
          message = token.errors
        end
        return ActiveMerchant::Billing::Response.new(false, message, {}, authorization: '')
      else
        # Pegando o DDD e o telefone
        if billing_address[:phone].include?('(')
          phone_prefix = billing_address[:phone][1..2]  rescue ''
          phone = billing_address[:phone][5..-1] rescue ''
        else
          phone_prefix = nil
          phone = billing_address[:phone]
        end

        # Make request
        params = {
          token: token.id,
          email: gateway_options[:email],
          months: source.portions,
          items: [],
          payer: {
            name: billing_address[:name],
            phone_prefix: phone_prefix,
            phone: phone,
            email: gateway_options[:customer],
            address: format_billing_address(billing_address)
          }
        }

        order.line_items.each do |item|
          params[:items] << {
              description: item.variant.name,
              quantity: item.quantity,
              price_cents: item.single_money.cents
          }
        end

        if order.shipment_total > 0
          params[:items] << {
              description: Spree.t(:shipment_total),
              quantity: 1,
              price_cents: order.display_ship_total.cents
          }
        end

        order.all_adjustments.eligible.each do |adj|
          params[:items] << {
              description: adj.label,
              quantity: 1,
              price_cents: adj.display_amount.cents
          }
        end

        charge = Iugu::Charge.create(params)

        if charge.errors.present?
          if charge.errors.is_a?(Hash)
            message = charge.errors.inject(Array.new) { |arr, i| arr += i[1] }.join('. ')
          else
            message = charge.errors
          end
          ActiveMerchant::Billing::Response.new(false, message, {}, authorization: '')
        else
          ActiveMerchant::Billing::Response.new(true, Spree.t("iugu_credit_card_success"), {}, authorization: charge.invoice_id)
        end
      end
    end

    def void(response_code, _gateway_options)
      invoice = Iugu::Invoice.fetch response_code
      if invoice.status == 'paid'
        if invoice.refund
          ActiveMerchant::Billing::Response.new(true, Spree.t('iugu_credit_card_void'), {}, authorization: response_code)
        else
          ActiveMerchant::Billing::Response.new(false, invoice.errors, {}, {})
        end
      end
    end

    def cancel(response_code)
      invoice = Iugu::Invoice.fetch response_code
      if invoice.status == 'paid'
        if invoice.refund
          ActiveMerchant::Billing::Response.new(true, Spree.t('iugu_credit_card_cancel'), {}, authorization: response_code)
        else
          ActiveMerchant::Billing::Response.new(false, invoice.errors, {}, {})
        end
      end
    end

    def format_billing_address(address)
      country = Spree::Country.find_by(iso: address[:country])
      {
        street: address[:address1],
        city: address[:city],
        state: address[:state],
        country: country.try(:name),
        zip_code: address[:zip]
      }
    end

    def portions_options(amount)
      ret = []
      portions_number = preferred_maximum_portions
      minimum_value = preferred_minimum_value

      (1..portions_number).each do |number|
        tax = preferred_tax_value_per_months[number.to_s].to_f || 0.0
        if tax <= 0 or (number <= preferred_portions_without_tax and amount >= preferred_min_value_without_tax)
          value = amount.to_f / number
          tax_message = :iugu_without_tax
        else
          value = (amount.to_f * ((1 + tax / 100) ** number)) / number
          tax_message = :iugu_with_tax
        end

        if value >= minimum_value
          value_total = value * number
          ret.push({portion: number, value: value, total: value_total, tax_message: tax_message})
        end
      end
      ret
    end

  end
end
