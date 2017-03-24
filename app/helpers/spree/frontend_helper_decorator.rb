module Spree
  FrontendHelper.class_eval do

    def iugu_portion_label(item)
      formatted_value = Spree::Money.new(item[:value], currency: current_currency)
      if item[:tax_message] == :iugu_without_tax
        label = Spree.t(:iugu_portion_item_without_tax, times: item[:portion], value: formatted_value)
      else
        formatted_total_value = Spree::Money.new(item[:total], currency: current_currency)
        label = Spree.t(:iugu_portion_item_with_tax, times: item[:portion],
                                                     value: formatted_value,
                                                     total: formatted_total_value)
      end
      label
    end

  end
end
