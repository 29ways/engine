class Site

  include Locomotive::Mongoid::Document

  ## fields ##
  field :name
  field :subdomain
  field :domains, :type => Array, :default => []
  field :meta_keywords
  field :meta_description

  ## associations ##
  references_many :pages
  references_many :layouts
  references_many :snippets
  references_many :theme_assets
  references_many :asset_collections
  references_many :content_types
  embeds_many :memberships

  ## validations ##
  validates_presence_of     :name, :subdomain
  validates_uniqueness_of   :subdomain
  validates_exclusion_of    :subdomain, :in => Locomotive.config.reserved_subdomains
  validates_format_of       :subdomain, :with => Locomotive::Regexps::SUBDOMAIN, :allow_blank => true
  validate                  :domains_must_be_valid_and_unique

  ## callbacks ##
  after_create :create_default_pages!
  before_save :add_subdomain_to_domains
  after_destroy :destroy_in_cascade!

  ## named scopes ##
  scope :match_domain, lambda { |domain| { :any_in => { :domains => [*domain] } } }
  scope :match_domain_with_exclusion_of, lambda { |domain, site|
      { :any_in => { :domains => [*domain] }, :where => { :_id.ne => site.id } }
    }

  ## methods ##

  def accounts
    Account.criteria.in(:_id => self.memberships.collect(&:account_id))
  end

  def admin_memberships
    self.memberships.find_all { |m| m.admin? }
  end

  def add_subdomain_to_domains
    self.domains ||= []
    (self.domains << "#{self.subdomain}.#{Locomotive.config.default_domain}").uniq!
  end

  def domains_without_subdomain
    (self.domains || []) - ["#{self.subdomain}.#{Locomotive.config.default_domain}"]
  end

  def domains_with_subdomain
    ((self.domains || []) + ["#{self.subdomain}.#{Locomotive.config.default_domain}"]).uniq
  end

  def to_liquid
    Locomotive::Liquid::Drops::Site.new(self)
  end

  protected

  def domains_must_be_valid_and_unique
    return if self.domains.empty?

    self.domains_without_subdomain.each do |domain|
      if not self.class.match_domain_with_exclusion_of(domain, self).empty?
        self.errors.add(:domains, :domain_taken, :value => domain)
      end

      if not domain =~ Locomotive::Regexps::DOMAIN
        self.errors.add(:domains, :invalid_domain, :value => domain)
      end
    end
  end

  def create_default_pages!
    %w{index 404}.each do |slug|
      self.pages.create({
        :slug => slug,
        :title => I18n.t("attributes.defaults.pages.#{slug}.title"),
        :body => I18n.t("attributes.defaults.pages.#{slug}.body"),
        :published => true
      })
    end
  end

  def destroy_in_cascade!
    %w{pages layouts snippets theme_assets asset_collections content_types}.each do |association|
      self.send(association).destroy_all
    end
  end

end
