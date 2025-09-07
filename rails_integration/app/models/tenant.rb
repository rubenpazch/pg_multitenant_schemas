# frozen_string_literal: true

# Example tenant model for Rails integration testing
class Tenant < ApplicationRecord
  validates :subdomain, presence: true, uniqueness: true
end
