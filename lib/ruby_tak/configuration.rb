# frozen_string_literal: true

require "xdg"
require "socket"

module RubyTAK
  class Configuration
    class ArgumentError < ::ArgumentError; end

    attr_reader :cot_ssl_port
    attr_accessor :ca_crt, :ca_key, :server_crt, :server_key, :server_p12, :hostname

    def initialize(env = ENV.to_h)
      @ca_crt = "#{subdirectory}-ca.crt"
      @ca_key = "#{subdirectory}-ca.key"
      @server_crt = "#{subdirectory}-server.crt"
      @server_key = "#{subdirectory}-server.key"
      @server_p12 = "#{subdirectory}-server.p12"
      @hostname = Socket.gethostname
      self.cot_ssl_port = env.fetch("PORT", 8089)
    end

    def ca_crt_path
      certs_dir.join(ca_crt)
    end

    def ca_key_path
      certs_dir.join(ca_key)
    end

    def server_crt_path
      certs_dir.join(server_crt)
    end

    def server_key_path
      certs_dir.join(server_key)
    end

    def server_p12_path
      certs_dir.join(server_p12)
    end

    def subdirectory
      "ruby_tak"
    end

    def cot_ssl_port=(value)
      port = Integer(value)
      raise ArgumentError, "cot_ssl_port must be between 1 and 65535" unless (1..65_535).cover?(port)

      @cot_ssl_port = port
    end

    def certs_dir
      @certs_dir ||= config_home.join("certs").tap(&:mkpath)
    end

    def data_package_dir
      @data_package_dir ||= data_home.join("data_packages").tap(&:mkpath)
    end

    private

    def config_home
      @config_home ||= Pathname.new(xdg.config_home).join(subdirectory).tap(&:mkpath)
    end

    def data_home
      @data_home ||= Pathname.new(xdg.data_home).join(subdirectory).tap(&:mkpath)
    end

    def xdg
      @xdg ||= XDG::Environment.new
    end
  end
end
