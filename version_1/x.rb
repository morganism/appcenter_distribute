 require 'net/http'
 require 'uri'
 require 'json'

 module AppCenter
   class BaseAPI
     BASE_URL = 'https://api.appcenter.ms/v0.1/apps/'

     def initialize(o_n, app_name, api_token)
       @o_n = o_n
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
       url = URI("#{BASE_URL}#{@o_n}/#{@app_name}/uploads/releases")
       request = Net::HTTP::Post.new(url)
       request['accept'] = 'application/json'
       request['X-API-Token'] = @api_token
       request['Content-Type'] = 'application/json'
       request['Content-Length'] = '0'

       call_api(url, request)
     end
   end
 end

