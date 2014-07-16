class Report < ActiveRecord::Base
  attr_accessor :delete_image
  serialize :observations, Array

  # RELATIONS #
  has_many :dispatches, dependent: :destroy
  has_many :logs,       dependent: :destroy
  has_many :responders, through:   :dispatches

  # CALLBACKS #
  has_attached_file :image
  before_validation :clean_image, :clean_observations
  after_validation :set_completed, if: :archived_or_completed?, on: :update
  after_commit :push_reports

  # CONSTANTS #
  AGEGROUP    = [
    'Youth (0-17)', 'Young Adult (18-34)', 'Adult (35-64)', 'Senior (65+)'
  ]
  SETTING     = ['Public Space', 'Workplace', 'School', 'Home', 'Other']
  OBSERVATION = [
    'At-risk of harm', 'Under the influence', 'Anxious',
    'Depressed', 'Aggarvated', 'Threatening'
  ]
  GENDER      = %w(Male Female Other)
  ETHNICITY   = [
    'Hispanic or Latino', 'American Indian or Alaska Native', 'Asian',
    'Black or African American', 'Native Hawaiian or Pacific Islander',
    'White', 'Other/Unknown'
  ]
  STATUS      = %w(archived completed pending)

  # VALIDATIONS #
  validates :address, presence: true
  validates_inclusion_of :status, in: STATUS
  validates_inclusion_of :gender, in: GENDER, allow_blank: true
  validates_inclusion_of :age, in: AGEGROUP, allow_blank: true
  validates_inclusion_of :race, in: ETHNICITY, allow_blank: true
  validates_inclusion_of :setting, in: SETTING, allow_blank: true

  # SCOPE #
  scope :accepted, lambda {
    includes(:dispatches).where(status: 'pending').merge(Dispatch.accepted)
      .order('reports.created_at DESC').references(:dispatches)
  }

  scope :completed, -> { where(status: %w(completed archived)) }

  scope :pending, lambda {
    includes(:dispatches).where(status: 'pending').references(:dispatches)
      .where.not(id: accepted.map(&:id)).where("dispatches.status = 'pending'")
  }

  scope :unassigned, lambda {
    includes(:dispatches).where(status: 'pending')
      .where.not(id: pending.map(&:id).concat(accepted.map(&:id)))
  }

  # INSTANCE METHODS #
  def accepted_dispatches
    dispatches.accepted
  end

  def multi_accepted_responders?
    accepted_dispatches.count > 1
  end

  def primary_responder
    return false if accepted_dispatches.blank?
    accepted_dispatches.first.responder
  end

  def current_status
    return status unless status == 'pending'
    if Dispatch.accepted(id).present?
      'active'
    elsif current_pending?
      'pending'
    else
      'unassigned'
    end
  end

  def current_pending?
    Report.pending.include?(self)
  end

  def dispatch(responder)
    dispatches.create(responder: responder)
  end

  def accepted?
    Responder.accepted(id).any?
  end

  def archived?
    status == 'archived'
  end

  def completed?
    status == 'completed'
  end

  def archived_or_completed?
    archived? || completed?
  end

  def complete
    update_attributes(status: 'completed')
  end

  def set_completed
    return false unless %w(archived completed).include?(status)
    touch(:completed_at) unless completed_at.present?
    dispatches.pending.each { |i| i.update_attributes(status: 'rejected') }
    Dispatch.accepted(id).each { |i| i.update_attributes(status: 'completed') }
  end

  private

  def clean_image
    image.clear if delete_image == '1'
  end

  def clean_observations
    observations.delete_if(&:blank?) if observations_changed?
  end

  def push_reports
    Push.refresh
  end
end
