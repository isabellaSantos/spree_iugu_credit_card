module Spree
  FrontendHelper.class_eval do

    def iugu_portion_label(item)
      formatted_value = Spree::Money.new(item[:value], currency: current_currency)
      label = Spree.t(:iugu_portion_item, times: item[:portion], value: formatted_value)
      label += ' ' + Spree.t(item[:tax_message])
    end

  end
end
