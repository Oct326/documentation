class Status < ActiveRecord::Base
  belongs_to :account, inverse_of: :statuses

  belongs_to :thread, foreign_key: 'in_reply_to_id', class_name: 'Status'
  belongs_to :reblog, foreign_key: 'reblog_of_id', class_name: 'Status'

  has_one :stream_entry, as: :activity, dependent: :destroy

  has_many :favourites, inverse_of: :status, dependent: :destroy
  has_many :reblogs, foreign_key: 'reblog_of_id', class_name: 'Status'
  has_many :replies, foreign_key: 'in_reply_to_id', class_name: 'Status'
  has_many :mentioned_accounts, class_name: 'Mention', dependent: :destroy

  validates :account, presence: true
  validates :uri, uniqueness: true, unless: 'local?'

  def local?
    self.uri.nil?
  end

  def reblog?
    !self.reblog_of_id.nil?
  end

  def reply?
    !self.in_reply_to_id.nil?
  end

  def verb
    reblog? ? :share : :post
  end

  def object_type
    reply? ? :comment : :note
  end

  def content
    reblog? ? self.reblog.text : self.text
  end

  def target
    self.reblog
  end

  def title
    content.truncate(80, omission: "...")
  end

  def mentions
    m = []

    m << thread.account if reply?
    m << reblog.account if reblog?

    unless reblog?
      self.text.scan(Account::MENTION_RE).each do |match|
        uri = match.first
        username, domain = uri.split('@')
        account = Account.find_by(username: username, domain: domain)

        m << account unless account.nil?
      end
    end

    m
  end

  after_create do
    self.account.stream_entries.create!(activity: self)
  end
end