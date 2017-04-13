module Spree
  Order.class_eval do

    state_machine.after_transition to: :complete, do: :update_iugu_order

    def update_iugu_order
      if payments.valid.any? { |payment| payment.payment_method.is_a?(Spree::PaymentMethod::IuguCreditCard) }
        updater.update
      end
    end

  end
end
