require 'net/http'
require 'uri'
require 'json'

module AppCenter
  class BaseAPI
    BASE_URL = 'https://api.appcenter.ms/v0.1/apps/'

    def initialize(owner_name, app_name, api_token)
      @owner_name = owner_name
      @app_name = app_name
      @api_token = api_token
    end

    def call_api(url, request)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        puts "Error: #{response.code} - #{response.message}"
      end
    end
  end

  class ReleaseUploader < BaseAPI
    def upload_release
      url = URI("#{BASE_URL}#{@owner_name}/#{@app_name}/uploads/releases")
      request = Net::HTTP::Post.new(url)
      request['accept'] = 'application/json'
      request['X-API-Token'] = @api_token
      request['Content-Type'] = 'application/json'
      request['Content-Length'] = '0'

      call_api(url, request)
    end
  end

  class MetadataUploader < BaseAPI
    FILE_SIZE_COMMAND = "wc -c $RELEASE_FILE_LOCATION | awk '{print $1}'"

    def initialize(response)
      super(response.owner_name, response.app_name, response.api_token)
      @response = response
    end

    def upload_metadata(file_name, content_type)
      file_size_bytes = `#{FILE_SIZE_COMMAND}`.strip
      metadata_url = URI("#{BASE_URL}#{@owner_name}/#{@app_name}/uploads/releases/#{@response.id}")
      request = Net::HTTP::Post.new(metadata_url)
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request.body = {
        file_name: file_name,
        file_size: file_size_bytes,
        token: @response.url_encoded_token,
        content_type: content_type
      }.to_json

      call_api(metadata_url, request)
    end
  end

  class ChunkUploader < BaseAPI
    CHUNK_SIZE = 4194304 # 4 MB

    def upload_chunks(file_path)
      chunk_number = 0
      Dir.foreach(file_path) do |file|
        next if file == '.' || file == '..'

        chunk_number += 1
        content_length = File.size(file)
        upload_chunk_url = URI("https://file.appcenter.ms/upload/upload_chunk/#{@response.package_asset_id}?token=#{URI.encode_www_form_component(@response.url_encoded_token)}&block_number=#{chunk_number}")
        request = Net::HTTP::Post.new(upload_chunk_url)
        request.body = File.read(file)
        request['Content-Length'] = content_length.to_s
        request['Content-Type'] = 'application/octet-stream'

        call_api(upload_chunk_url, request)
      end
    end
  end

  class FinishUploader < BaseAPI
    def finish_upload
      finish_url = URI("https://file.appcenter.ms/upload/finished/#{@response.package_asset_id}?token=#{URI.encode_www_form_component(@response.url_encoded_token)}")
      request = Net::HTTP::Post.new(finish_url)

      call_api(finish_url, request)
    end
  end

  class StatusChecker < BaseAPI
    def check_status
      status_url = URI("#{BASE_URL}#{@owner_name}/#{@app_name}/uploads/releases/#{@response.id}")
      request = Net::HTTP::Get.new(status_url)

      call_api(status_url, request)
    end
  end

  class ReleaseDistributor < BaseAPI
    def distribute_release(distribution_group)
      distribute_url = URI("#{BASE_URL}#{@owner_name}/#{@app_name}/releases/#{@response.release_id}")
      request = Net::HTTP::Patch.new(distribute_url)
      request.body = { destinations: [{ name: distribution_group }] }.to_json
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'
      request['X-API-Token'] = @api_token

      call_api(distribute_url, request)
    end
  end
end

