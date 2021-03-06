module Aquatone
  class Collector
    class Error < StandardError; end
    class InvalidMetadataError < Error; end
    class MetadataNotSetError < Error; end
    class MissingKeyRequirement < Error; end

    attr_reader :domain, :hosts

    DEFAULT_PRIORITY = 1

    def self.meta
      @meta || fail(MetadataNotSetError, "Metadata has not been set")
    end

    def self.meta=(meta)
      validate_metadata(meta)
      @meta = meta
    end

    def self.descendants
      collectors = ObjectSpace.each_object(Class).select { |klass| klass < self }
      collectors.sort { |x, y| x.priority <=> y.priority }
    end

    def self.sluggified_name
      return meta[:slug].downcase if meta[:slug]
      meta[:name].strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub("--", "-")
    end

    def initialize(domain)
      check_key_requirements!
      @domain = domain
      @hosts  = []
    end

    def run
      fail NotImplementedError
    end

    def execute!
      run
      hosts
    end

    def self.priority
      meta[:priority] || DEFAULT_PRIORITY
    end

    protected

    def add_host(host)
      host.downcase!
      return unless Aquatone::Validation.valid_domain_name?(host)
      @hosts << host unless @hosts.include?(host)
    end

    def get_request(uri, options={})
      Aquatone::HttpClient.get(uri, options)
    end

    def post_request(uri, body=nil, options={})
      options = {
        :body => body
      }.merge(options)
      Aquatone::HttpClient.post(uri, options)
    end

    def url_escape(string)
      CGI.escape(string)
    end

    def random_sleep(seconds)
      random_sleep = ((1 - (rand(30) * 0.01)) * seconds.to_i)
      sleep(random_sleep)
    end

    def get_key(name)
      Aquatone::KeyStore.get(name)
    end

    def has_key?(name)
      Aquatone::KeyStore.key?(name)
    end

    def failure(message)
      fail Error, message
    end

    def check_key_requirements!
      return unless self.class.meta[:require_keys]
      keys = self.class.meta[:require_keys]
      keys.each do |key|
        fail MissingKeyRequirement, "Key '#{key}' has not been set" unless has_key?(key)
      end
    end

    def self.validate_metadata(meta)
      fail InvalidMetadataError, "Metadata is not a hash" unless meta.is_a?(Hash)
      fail InvalidMetadataError, "Metadata is empty" if meta.empty?
      fail InvalidMetadataError, "Metadata is missing key: name" unless meta.key?(:name)
      fail InvalidMetadataError, "Metadata is missing key: author" unless meta.key?(:author)
      fail InvalidMetadataError, "Metadata is missing key: description" unless meta.key?(:description)
    end
  end
end
