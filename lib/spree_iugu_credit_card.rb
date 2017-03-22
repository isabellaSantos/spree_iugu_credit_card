require 'spree_core'
require 'spree_iugu_credit_card/engine'

Spree::PermittedAttributes.source_attributes.push [:portions]
