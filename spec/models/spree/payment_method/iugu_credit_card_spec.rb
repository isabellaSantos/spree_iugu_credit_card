require 'spec_helper'

describe Spree::PaymentMethod::IuguCreditCard, type: :model do

  let(:object) { create(:iugu_cc_payment_method) }
  let!(:credit_card) { create(:iugu_credit_card) }
  let!(:payment) { create(:iugu_cc_payment) }

  before { Iugu.api_key = '' }

  it 'payment_source_class should be CreditCard' do
    expect(object.payment_source_class).to eq Spree::CreditCard
  end

  it 'payment method should be auto captured' do
    expect(object.auto_capture).to be_truthy
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

        response = object.purchase '1599', credit_card, payment.gateway_options
        expect(response.success?).to be_falsey
      end
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

end
