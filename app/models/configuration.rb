# frozen_string_literal: true

class Configuration < ApplicationRecord
  validates :key,
            presence: true,
            inclusion: { in: ->(_) { configurations.keys } },
            uniqueness: { case_sensitive: false }

  validates :value,
            presence: true,
            allow_blank: true

  after_commit :run_service

  def default
    Configuration.configurations.dig(key, :default)
  end

  def minimum
    Configuration.configurations.dig(key, :minimum)
  end

  def maximum
    Configuration.configurations.dig(key, :maximum)
  end

  def allowed_values
    Configuration.configurations.dig(key, :allowed_values)
  end

  def category
    Configuration.configurations.dig(key, :category) || "other"
  end

  def dependencies
    self.class.dependencies(key)
  end

  def all_dependencies
    self.class.all_dependencies(key)
  end

  def dependents
    self.class.dependents(key)
  end

  def all_dependents
    self.class.all_dependents(key)
  end

  def dependencies_satisfied?
    self.class.dependencies_satisfied?(key)
  end

  def all_dependencies_satisfied?
    self.class.all_dependencies_satisfied?(key)
  end

  def self.dependencies(key)
    Configuration.configurations.dig(key, :dependencies) || []
  end

  def self.all_dependencies(key, include_key: false)
    dependencies(key)
      .flat_map { |dependency| all_dependencies(dependency, include_key: true) }
      .tap { |dependencies| dependencies << key if include_key }
      .uniq
  end

  def self.dependents(key)
    Configuration
      .configurations
      .select { |_, config| config[:dependencies]&.include?(key) }
      .keys
  end

  def self.all_dependents(key, include_key: false)
    dependents(key)
      .flat_map { |dependency| all_dependents(dependency, include_key: true) }
      .tap { |dependencies| dependencies << key if include_key }
      .uniq
  end

  def self.dependencies_satisfied?(key)
    dependencies(key)
      .map { |dependency| find_or_create(dependency) }
      .all? { |dependency| dependency.value.present? }
  end

  def self.all_dependencies_satisfied?(key)
    all_dependencies(key)
      .map { |dependency| find_or_create(dependency) }
      .all? { |dependency| dependency.value.present? }
  end

  def self.find_or_create(key)
    "Configuration::#{configurations[key][:type].camelize}"
      .constantize
      .create_with(value: configurations[key][:default])
      .find_or_create_by!(key:)
  end

  def self.get(key)
    return unless all_dependencies_satisfied?(key)

    find_or_create(key)
      .value
  end

  def self.set(key, value)
    "Configuration::#{configurations[key][:type].camelize}"
      .constantize
      .create_with(value:)
      .find_or_create_by!(key:)
      .update!(value:)
  end

  def self.configurations
    @@app_configurations ||= load_paths.each_with_object({}) do |path, configurations| # rubocop:disable Style/ClassVars
      configurations.merge!(YAML
        .load_file(path)
        .to_h { |c| [c["key"], c.except("key").symbolize_keys] })
    end
  end

  def self.load_paths
    @@app_load_paths ||= [Rails.root.join("config/configurations.yml")] # rubocop:disable Style/ClassVars
  end

  def self.load_paths=(paths)
    @@app_load_paths = paths # rubocop:disable Style/ClassVars
    @@app_configurations = nil # rubocop:disable Style/ClassVars
  end

  private

  def run_service
    self
      .class
      .configurations
      .dig(key, :service)
      &.constantize
      &.call
  end

  class String < Configuration
    before_save { self.value = value.to_s }

    validates :value,
              inclusion: { in: ->(record) { record.allowed_values } },
              if: -> { allowed_values.present? }

    def self.policy_class = ConfigurationPolicy
  end

  class Integer < Configuration
    before_save { self.value = value.to_i }

    validates :value,
              numericality: { greater_than_or_equal_to: ->(record) { record.minimum }, message: :greater_than_or_equal_to },
              if: -> { minimum.present? }

    validates :value,
              numericality: { less_than_or_equal_to: ->(record) { record.maximum }, message: :less_than_or_equal_to },
              if: -> { maximum.present? }

    def self.policy_class = ConfigurationPolicy
  end

  class Float < Configuration
    before_save { self.value = value.to_f }

    validates :value,
              numericality: { greater_than_or_equal_to: ->(record) { record.minimum }, message: :greater_than_or_equal_to },
              if: -> { minimum.present? }

    validates :value,
              numericality: { less_than_or_equal_to: ->(record) { record.maximum }, message: :less_than_or_equal_to },
              if: -> { maximum.present? }

    def self.policy_class = ConfigurationPolicy
  end

  class Boolean < Configuration
    before_save { self.value = ActiveModel::Type::Boolean.new.cast(value) }

    def self.policy_class = ConfigurationPolicy
  end
end

# == Schema Information
#
# Table name: configurations
#
#  id         :uuid             not null, primary key
#  key        :string           not null, uniquely indexed
#  type       :string           default("Configuration::String"), not null
#  value      :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_configurations_on_key  (key) UNIQUE
#
