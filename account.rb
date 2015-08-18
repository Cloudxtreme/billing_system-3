class Account
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Enumerize

  belongs_to :user, index: true

  field :card_first_six_sym, type: String
  field :card_last_four_sym, type: String
  field :card_expiration_date, type: String
  field :card_type, type: String
  field :issuer_bank_country, type: String
  field :token, type: String

  validates :card_first_six_sym, :card_last_four_sym, :card_type, :user, presence: true
end
