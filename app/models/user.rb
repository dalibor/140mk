class User < ActiveRecord::Base
  attr_accessible :atoken, :asecret

  has_many :subscriptions
  has_many :lists, :through => :subscriptions

  after_create :follow_user
  
  def authorized?
    atoken.present? && asecret.present?
  end
  
  def oauth
    @oauth ||= Twitter::OAuth.new(ConsumerConfig['consumer']['token'], ConsumerConfig['consumer']['secret'])
  end
  
  delegate :request_token, :access_token, :authorize_from_request, :to => :oauth
  
  def client
    @client ||= begin
      oauth.authorize_from_access(atoken, asecret)
      Twitter::Base.new(oauth)
    end
  end

  def set_attributes_from_twitter_account(account)
    self.twitter_id = account.id
    self.twitter_account_created_at = account.created_at
    self.name = account.name
    self.location = account.location
    self.url = account.url
    self.photo = account.profile_image_url
    self.description = account.description
  end

  def self.create_or_update(profile, oauth)
    user = User.find_or_initialize_by_screen_name(profile.screen_name)
    user.set_attributes_from_twitter_account(profile)
    user.atoken = oauth.access_token.token
    user.asecret = oauth.access_token.secret
    user.status == 1 ? user.save : user.activate!
    user
  end

  def activate!
    self.status = 1 # active
    self.save!
    follow_user
  end

  def deactivate!
    self.is_active = 0 # not active
    self.save!
    unfollow_user
  end

  private

  def follow_user
    unless TWITTER_HTTP_AUTH.friendship_exists?(TWITTER_HTTP_AUTH.username, screen_name)
      TWITTER_HTTP_AUTH.friendship_create(twitter_id, true)
    end
  rescue Twitter::General => e
    if e.message =~ /\(403\): Forbidden .*/
      self.status = 2 # protected account
      self.save
    else
      raise e
    end
  end

  def unfollow_user
    if TWITTER_HTTP_AUTH.friendship_exists?(TWITTER_HTTP_AUTH.username, screen_name)
      TWITTER_HTTP_AUTH.friendship_destroy(twitter_id)
    end
  end
end
