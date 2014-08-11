#This file is intended as the single entry point for RoadForest server code
require 'roadforest/application'
require 'roadforest/interfaces'

module RoadForest
  def self.serve(services)
    require 'webrick/accesslog'

    application = RoadForest::Application.new(services)

    logfile = services.logger
    logfile.info("#{Time.now.to_s}: Starting Roadforest server")

    application.configure do |config|
      config.adapter_options = {
        :Logger => WEBrick::Log.new(logfile, WEBrick::BasicLog::DEBUG ),
        :AccessLog => [
          [logfile, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
          [logfile, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
      ]
      }
      yield config if block_given?
    end
    application.run
  end

  module SSL
    class << self
      def enable(config, key, cert)
        require 'webrick/https'
        key = OpenSSL::PKey::RSA.new(File.read(key))
        cert = OpenSSL::X509::Certificate.new(File.read(cert))
        config.adapter_options.merge!( :SSLEnable => true, :SSLPrivateKey => key, :SSLCertificate => cert,
                                      :SSLCertName => [["CN", WEBrick::Utils::getservername]]
                                     )
      end
      def add_ca_cert(config, cert_file)
        config.adapter_options.merge!( :SSLCACertificateFile => cert_file)
      end

      module ClientCert
        def client_cert
          wreq = @body.instance_variable_get("@request")
          wreq.client_cert
        end
      end

      def add_client_verify(config)
        Webmachine::Request.instance_eval{include(ClientCert)}
        config.adapter_options.merge!( :SSLEnable => true, :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER)
      end
    end
  end
end
