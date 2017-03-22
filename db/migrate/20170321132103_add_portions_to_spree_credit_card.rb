class AddPortionsToSpreeCreditCard < ActiveRecord::Migration
  def change
    add_column :spree_credit_cards, :portions, :integer
  end
end
