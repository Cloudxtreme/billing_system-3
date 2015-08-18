def buy
  update_card = current_user.account.present?

  options = {
    ip: request.ip,
    account_id: current_user.email,
    name: params[:name],
    json_data: { tariff: params[:tariff], update_card: update_card }.to_json,
    currency: current_contract.currency,
    description: "Card Details"
  }

  сurrent_contract.tariff = Tariff.find(params[:tariff]) if params[:tariff].present?
  amount = update_card ? 1 : current_contract.amount

  response = gateway.buy(params[:cryptogram], amount, options, true)

  @params = parametrize(response.params)

  if response.success?
    resp = { json: success_transaction(@params)}
  else
    if @params and @params["first"].present?
      resp = { json: { response: @params, type: '3ds'}, status: 422 }
    else
      resp = { json: { response: @params, type: 'error'}, status: 422 }
    end

  end
    render resp
end

  private

  def gateway
    ActiveMerchant::Billing::PaymentsGateway.new(public_id: config.payments.public_id, api_secret: config.payments.api_secret)
  end


