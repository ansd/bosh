module Bosh::Director
  # Remote procedure call client wrapping NATS
  class NatsRpc

    def initialize(nats_uri, nats_server_ca_path, nats_client_private_key_path, nats_client_certificate_path)
      @nats_uri = nats_uri
      @nats_server_ca_path = nats_server_ca_path
      @nats_client_private_key_path = nats_client_private_key_path
      @nats_client_certificate_path = nats_client_certificate_path

      @logger = Config.logger
      @lock = Mutex.new
      @inbox_name = "director.#{Config.process_uuid}"
      @requests = {}
      @subscribed = nil
    end

    # Returns a lazily connected NATS client
    def nats
      begin
        @nats ||= connect
      rescue Exception => e
        raise "An error has occurred while connecting to NATS: #{e}"
      end
    end

    # Publishes a payload (encoded as JSON) without expecting a response
    def send_message(client, payload)
      message = JSON.generate(payload)
      @logger.debug("SENT: #{client} #{message}")

      EM.schedule do
        nats.publish(client, message)
      end
    end

    # Sends a request (encoded as JSON) and listens for the response
    def send_request(client, request, &callback)
      request_id = generate_request_id
      request["reply_to"] = "#{@inbox_name}.#{request_id}"

      sanitized_log_message = sanitize_log_message(request)
      request_body = JSON.generate(request)

      @logger.debug("SENT: #{client} #{sanitized_log_message}")
      EM.schedule do
        @requests[request_id] = callback
        if @subscribed
          nats.publish(client, request_body)
        else
          nats.flush do
            nats.publish(client, request_body)
          end
        end
      end
      request_id
    end

    # Stops listening for a response
    def cancel_request(request_id)
      @lock.synchronize { @requests.delete(request_id) }
    end

    def generate_request_id
      SecureRandom.uuid
    end

    private

    def connect
      # double-check locking to reduce synchronization
      resubscribe = false

      if @nats.nil?
        NATS.on_error do |e|
          password = @nats_uri[/nats:\/\/.*:(.*)@/, 1]
          redacted_message = password.nil? ? "NATS client error: #{e}" : "NATS client error: #{e}".gsub(password, '*******')
          @logger.error(redacted_message)
        end
        NATS.on_disconnect do |reason|
          @logger.error("NATS client disconnected. @nats: #{@nats}. inbox_name: #{@inbox_name}. subject_id: #{@subject_id}. reason: #{reason}")
        end
        options = {
          :uri => @nats_uri,
          :ssl => true,
          :tls => {
            :private_key_file => @nats_client_private_key_path,
            :cert_chain_file  => @nats_client_certificate_path,
            # Can enable verify_peer functionality optionally by passing
            # the location of a ca_file.
            :verify_peer => true,
            :ca_file => @nats_server_ca_path
          }
        }
        @nats = NATS.connect(options)
        @subject_id = nil
        @subscribed = nil
        subscribe_inbox
      end
      @nats
    end

    # subscribe to an inbox, if not already subscribed
    def subscribe_inbox
      # double-check locking to reduce synchronization
      if @subject_id.nil?
        # nats lazy-load needs to be outside the synchronized block
        @subject_id = nats.subscribe("#{@inbox_name}.>") do |message, _, subject|
          handle_response(message, subject)
          @subscribed = true
        end
      end
    end

    def handle_response(message, subject)
      @logger.debug("RECEIVED: #{subject} #{message}")
      begin
        request_id = subject.split(".").last
        callback = @lock.synchronize { @requests.delete(request_id) }
        if callback
          message = message.empty? ? nil : JSON.parse(message)
          callback.call(message)
        end
      rescue Exception => e
        @logger.warn(e.message)
      end
    end

    def sanitize_log_message(request)
      if request[:method].to_s == 'upload_blob'
        cloned_request = Bosh::Common::DeepCopy.copy(request)
        cloned_request[:arguments].first['checksum'] = '<redacted>'
        cloned_request[:arguments].first['payload'] = '<redacted>'
        JSON.generate(cloned_request)
      else
        JSON.generate(request)
      end
    end

  end
end
