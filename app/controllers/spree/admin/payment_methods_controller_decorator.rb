module Spree
  module Admin
    PaymentMethodsController.class_eval do

      before_action :set_tax_value, only: :update

      private

      def set_tax_value
        return if params[:tax_value].nil?
        tax_value = {}
        params[:tax_value].each_with_index do |tax, i|
          portion = i + 1
          tax.gsub! ',', '.'
          tax_value[portion.to_s] = tax
        end
        params[:payment_method_iugu_credit_card][:preferred_tax_value_per_months] = tax_value
      end

    end
  end
end
