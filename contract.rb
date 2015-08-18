class Contact
  include Mongoid::Document
  include Mongoid::Timestamps
  include AASM
  extend Enumerize

  belongs_to :user, index: true
  belongs_to :tariff, index: true
  has_many   :transactions, dependent: :restrict

  default_scope -> { order_by(:created_at.desc)}
  scope :billable, -> { self.or({aasm_state: 'active'}, {aasm_state: 'past_due'}) }
  scope :billable_on, -> (date) { where(next_payment_due: date) }
  scope :trial_due_on, -> (date) { where(trial_due: date) }

  field :aasm_state
  field :last_charge_error,              type: String
  field :tariff_period
  field :next_payment_date,              type: Date
  field :trial_date,                     type: Date
  field :failed_transactions_number,     type: Integer, default: 0
  field :successful_transactions_number, type: Integer, default: 0

  enumerize :tariff_period, in: [:month, :year], default: :month, predicates: true, scope: true

  validates :tariff_period, presence: true
  before_validation :set_trial, on: :create

    def account
      user.account
    end

    def amount
      if tariff_period.year?
        user.language.ru? ? tariff.clear_price(tariff.year_price_rub) : tariff.clear_price(tariff.year_price_usd)
      else
        user.language.ru? ? tariff.clear_price(tariff.price_rub) : tariff.clear_price(tariff.price_usd)
      end
    end

    def gateway
      ActiveMerchant::Billing::PaymentsGateway.new(public_id: config.payments.public_id, api_secret: config.payments.api_secret)
    end

    def update!
      options = { currency: currency, account_id: user.email }
      response = gateway.buy(account.token, amount, options)
      update_subscription! response
    end

    def currency
      user.language.ru? ? 'RUB' : 'USD'
    end

    def update_tariff!(response)
      if response.success?
        activate_tariff!
      else
        logger.error "Возникла ошибка"
        logger.error response.message

      self.next_payment_date += config.retry_days_number
      self.last_charge_error = response.message
      self.failed_transactions_number += 1

      f self.failed_transactions_number < config.retry_number
        self.past_date! || self.save!
      else
        self.to_freeze! do
          UserMailer.delay.tariff_cancelled(self.user.id)
      end
    end
  end
  record_transasction!(response.params)
end

def activate_tariff!(tariff=nil, params=nil)
  record_transasction!(params) if params.present?
  self.tariff = Tariff.find(tariff) if tariff.present?
  self.last_charge_error = nil
  self.next_payment_date = next_billing_date(next_payment_date)
  self.failed_transactions_number = 0
  self.successful_transactions_number += 1
  self.activate!
end

def next_billing_date(date=Date.today)
  date ||= Date.today
  period = plan_duration.month? ? 1.month : 1.year
  date + period
end

def self.update!
  billable.billable_on(Date.today).each do |contract|
    contract.update!
  end
end

def self.freeze!
  trial.trial_date_on(Date.today).each do |contact|
    contract.to_freeze! do
      UserMailer.delay.trial_over(contract.user.id)
    end
  end
end

private

def set_trial
  self.trial_due = Date.today + config.trial
end

def record_transaction!(params)
  transactions.create! transaction_attrs(params)
end

def transaction_attrs(attrs)
  attrs = ActionController::Parameters.new attrs
  p = attrs.permit(:transactionId, :amount, :currency, :datetime, :ip, :ipcountry, :ipcity, :ipregion, :ipdistrict, :description, :status, :reason, :authcode).transform_keys!{ |key| key.to_s.underscore rescue key }
  p[:status] = p[:status].underscore if p[:status].present?
  p[:reason] = p[:reason].titleize if p[:reason].present?
  p[:date_time] = DateTime.parse(attrs[:created_date_iso]) if attrs[:dreated_date_iso].present?
  p
end
end
