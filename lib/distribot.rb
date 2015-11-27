
require 'active_support/core_ext/object'
require 'active_support/json'
require 'bunny'
require 'redis'

require 'distribot/workflow'
require 'distribot/phase'
require 'distribot/handler'
require 'distribot/workflow_created_handler'

module Distribot

  @@config = OpenStruct.new()
  @@did_configure = false

  def self.configure(&block)
    @@did_configure = true
    block.call(configuration)
    # Now set defaults for things that aren't defined:
    configuration.redis_prefix ||= 'distribot'
    configuration.queue_prefix ||= 'distribot'
  end

  def self.configuration
    unless @@did_configure
      self.configure do
      end
    end
    @@config
  end

  def self.bunny
    @@bunny ||= Bunny.new( configuration.rabbitmq_url )
  end

  def self.bunny_channel
    unless defined? @@channel
      bunny.start
    end
    @@channel ||= bunny.create_channel
    @@channel
  end

  def self.redis
    # Redis complains if we pass it a nill url. Better to not pass a url at all:
    @@redis ||= configuration.redis_url ? Redis.new( configuration.redis_url ) : Redis.new
  end

  def self.debug=(value)
    @@debug = value ? true : false
  end

  def self.debug
    @@debug ||= false
  end

  def self.redis_id(type, id)
    "#{configuration.redis_prefix}-#{type}:#{id}"
  end

  def self.queue(name)
    bunny_channel.queue(name, auto_delete: true, durable: true)
  end

  def self.publish!(queue_name, json)
#    begin
      queue_obj = queue(queue_name)
    # rescue StandardError => e
    #   puts "ERROR: #{e} --- #{e.backtrace.join("\n")}"
    #   raise e
    # end
    bunny_channel.default_exchange.publish json, routing_key: queue_obj.name
  end
end
