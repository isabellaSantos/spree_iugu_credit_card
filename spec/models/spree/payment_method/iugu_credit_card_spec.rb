require 'spec_helper'

describe Spree::PaymentMethod::IuguCreditCard, type: :model do

  let(:object) { create(:iugu_cc_payment_method) }
  let!(:credit_card) { create(:iugu_credit_card) }
  let!(:payment) { create(:iugu_cc_payment) }

  before { Iugu.api_key = '' }

  it 'payment_source_class should be CreditCard' do
    expect(object.payment_source_class).to eq Spree::CreditCard
  end

  context 'authorize' do
    let(:token_request) do
      {
        url: 'https://api.iugu.com/v1/payment_token',
        body: hash_including({'method' => 'credit_card'}),
        filename: 'create_token'
      }
    end

    it 'should create token and make the payment on Iugu' do
      charge_request = {
        body: hash_including({'token' => 'ABC19A61A78A4665914426EA752B0001'}),
        filename: 'create_charge'
      }
      stub_iugu token_request
      stub_iugu charge_request
      stub_iugu({ filename: 'fetch_invoice_in_analysis', method: :get,
        url: "https://api.iugu.com/v1/invoices/ABCDEFGHIJKLMNOPQRSTUVWXYZ000001", body: '{}' })
      object.update_attributes(auto_capture: false)
      response = object.authorize '1599', credit_card, payment.gateway_options

      expect(response.success?).to be_truthy
      expect(response.authorization).to eq 'ABCDEFGHIJKLMNOPQRSTUVWXYZ000001'
    end

    context 'error' do
      it 'should not purchase when Iugu return an error when create the token' do
        token_request = {
          url: 'https://api.iugu.com/v1/payment_token',
          body: hash_including({'method' => 'credit_card'}),
          filename: 'create_token_error'
        }
        stub_iugu token_request

        object.update_attributes(auto_capture: false)
        response = object.authorize '1599', credit_card, payment.gateway_options
        expect(response.success?).to be_falsey
      end

      it 'should not purchase when Iugu return error' do
        charge_request = {
          body: hash_including({'token' => 'ABC19A61A78A4665914426EA752B0001'}),
          filename: 'create_charge_error'
        }
        stub_iugu token_request
        stub_iugu charge_request
        stub_iugu({ filename: 'fetch_invoice', method: :get,
          url: "https://api.iugu.com/v1/invoices/ABCDEFGHIJKLMNOPQRSTUVWXYZ000001", body: '{}' })

        object.update_attributes(auto_capture: false)
        response = object.authorize '1599', credit_card, payment.gateway_options
        expect(response.success?).to be_falsey
      end
    end
  end

  context 'purchase' do
    let(:token_request) do
      {
        url: 'https://api.iugu.com/v1/payment_token',
        body: hash_including({'method' => 'credit_card'}),
        filename: 'create_token'
      }
    end

    it 'should create token and make the payment on Iugu' do
      charge_request = {
        body: hash_including({'token' => 'ABC19A61A78A4665914426EA752B0001'}),
        filename: 'create_charge'
      }
      stub_iugu token_request
      stub_iugu charge_request
      stub_iugu({ filename: 'fetch_invoice', method: :get,
        url: "https://api.iugu.com/v1/invoices/ABCDEFGHIJKLMNOPQRSTUVWXYZ000001", body: '{}' })
      object.update_attributes(auto_capture: true)
      response = object.purchase '1599', credit_card, payment.gateway_options

      expect(response.success?).to be_truthy
      expect(response.authorization).to eq 'ABCDEFGHIJKLMNOPQRSTUVWXYZ000001'
    end

    context 'error' do
      it 'should not purchase when Iugu return an error when create the token' do
        token_request = {
          url: 'https://api.iugu.com/v1/payment_token',
          body: hash_including({'method' => 'credit_card'}),
          filename: 'create_token_error'
        }
        stub_iugu token_request

        object.update_attributes(auto_capture: true)
        response = object.purchase '1599', credit_card, payment.gateway_options
        expect(response.success?).to be_falsey
      end

      it 'should not purchase when Iugu return error' do
        charge_request = {
          body: hash_including({'token' => 'ABC19A61A78A4665914426EA752B0001'}),
          filename: 'create_charge_error'
        }
        stub_iugu token_request
        stub_iugu charge_request
        stub_iugu({ filename: 'fetch_invoice', method: :get,
          url: "https://api.iugu.com/v1/invoices/ABCDEFGHIJKLMNOPQRSTUVWXYZ000001", body: '{}' })

        object.update_attributes(auto_capture: true)
        response = object.purchase '1599', credit_card, payment.gateway_options
        expect(response.success?).to be_falsey
      end
    end
  end

  context 'capture' do
    it 'should capture successfully' do
      response_code = '1'
      stub_iugu({ filename: 'fetch_invoice_in_analysis', method: :get,
        url: "https://api.iugu.com/v1/invoices/#{response_code}", body: '{}' })
      stub_iugu({ filename: 'fetch_invoice', method: :post, body: '{}',
                  url: "https://api.iugu.com/v1/invoices/#{response_code}/capture",
                  headers: {'Accept'=>'*/*',
                            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                            'Authorization'=>'Basic Og==',
                            'Content-Type'=>'application/x-www-form-urlencoded',
                            'User-Agent'=>'Iugu RubyLibrary'} })

      response = object.capture 10, response_code, payment.gateway_options
      expect(response.success?).to be_truthy
    end
  end

  context 'void' do
    it 'should void successfully' do
      response_code = '1'
      stub_iugu({ filename: 'fetch_invoice', method: :get,
        url: "https://api.iugu.com/v1/invoices/#{response_code}", body: '{}' })
      stub_iugu({ filename: 'refund_invoice', method: :post, body: '{}',
                  url: "https://api.iugu.com/v1/invoices/#{response_code}/refund" })

      response = object.void response_code, payment.gateway_options
      expect(response.success?).to be_truthy
    end

    it 'should return error when Iugu does not refund' do
      response_code = '1'
      stub_iugu({ filename: 'fetch_invoice', method: :get,
        url: "https://api.iugu.com/v1/invoices/#{response_code}", body: '{}' })
      stub_iugu({ filename: 'refund_invoice_error', method: :post, body: '{}',
                  url: "https://api.iugu.com/v1/invoices/#{response_code}/refund" })

      response = object.void response_code, payment.gateway_options
      expect(response.success?).to be_falsey
    end
  end

  context 'cancel' do
    it 'should void successfully' do
      response_code = '1'
      stub_iugu({ filename: 'fetch_invoice', method: :get,
        url: "https://api.iugu.com/v1/invoices/#{response_code}", body: '{}' })
      stub_iugu({ filename: 'refund_invoice', method: :post, body: '{}',
                  url: "https://api.iugu.com/v1/invoices/#{response_code}/refund" })

      response = object.cancel response_code
      expect(response.success?).to be_truthy
    end

    it 'should return error when Iugu does not refund' do
      response_code = '1'
      stub_iugu({ filename: 'fetch_invoice', method: :get,
        url: "https://api.iugu.com/v1/invoices/#{response_code}", body: '{}' })
      stub_iugu({ filename: 'refund_invoice_error', method: :post, body: '{}',
                  url: "https://api.iugu.com/v1/invoices/#{response_code}/refund" })

      response = object.cancel response_code
      expect(response.success?).to be_falsey
    end
  end

  context 'calculating portions' do
    it 'should calculate portions without tax' do
      object.preferred_portions_without_tax = 5
      object.preferred_maximum_portions = 5
      portions = object.portions_options 100

      expect(portions[0]).to eq({portion: 1, value: 100.0, total: 100.0, tax_message: :iugu_without_tax})
      expect(portions[1]).to eq({portion: 2, value: 50.0, total: 100.0, tax_message: :iugu_without_tax})
      expect(portions[2]).to eq({portion: 3, value: 33.333333333333336, total: 100.0, tax_message: :iugu_without_tax})
      expect(portions[3]).to eq({portion: 4, value: 25.0, total: 100.0, tax_message: :iugu_without_tax})
      expect(portions[4]).to eq({portion: 5, value: 20.0, total: 100.0, tax_message: :iugu_without_tax})
    end

    it 'should return the number of portions respecting the minimum value' do
      object.preferred_portions_without_tax = 10
      object.preferred_maximum_portions = 10
      object.preferred_minimum_value = 20
      portions = object.portions_options 50

      expect(portions.size).to eq 2
    end

    it 'should calculate portions with tax' do
      order = create(:order, total: 100.0)
      object.preferred_portions_without_tax = 1
      object.preferred_maximum_portions = 6
      object.preferred_minimum_value = 10
      object.preferred_tax_value_per_months = {
        '1' => 0.0,
        '2' => 1.0,
        '3' => 1.5,
        '4' => 2.0,
        '5' => 2.5,
        '6' => 3.0
       }
      portions = object.portions_options 100

      expect(portions[0]).to eq({portion: 1, value: 100.0, total: 100.0, tax_message: :iugu_without_tax})
      expect(portions[1]).to eq({portion: 2, value: 50.5, total: 101.00, tax_message: :iugu_with_tax})
      expect(portions[2]).to eq({portion: 3, value: 33.833333333333336, total: 101.5, tax_message: :iugu_with_tax})
      expect(portions[3]).to eq({portion: 4, value: 25.5, total: 102.0, tax_message: :iugu_with_tax})
      expect(portions[4]).to eq({portion: 5, value: 20.5, total: 102.5, tax_message: :iugu_with_tax})
      expect(portions[5]).to eq({portion: 6, value: 17.166666666666668, total: 103.0, tax_message: :iugu_with_tax})
    end
  end
end
