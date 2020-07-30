require 'net/http'
require 'openssl'
require 'time'
require 'faraday'
require 'cgi'

class Sendsafely
  attr_reader :thread, :package_code, :key_code

  API='api/v2.0'

  def initialize(uri, key_id, key_secret)
    @uri = uri
    @key_id = key_id
    @key_secret = key_secret
  end

  def link(link)
  end

  def get_package_info(link)
    @thread, @package_code, @key_code = link.scan(/thread=([\w-]+)&packageCode=(\w+)#keyCode=([\w-]+)/).first

    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+0000")

    output = Faraday.new("#{@uri}/#{API}/package/#{@thread}", headers: {
                             'ss-api-key' => @key_id,
                             'ss-request-timestamp' => timestamp,
                             'ss-request-signature' => OpenSSL::HMAC.hexdigest("SHA256", @key_secret, @key_id+"/#{API}/package/#{@thread}"+timestamp),
                           }).get.body
  end

  def download_urls(file_id, package_code)
    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+0000")

    resp = Faraday.post("#{@uri}/#{API}/package/#{@thread}/file/#{file_id}/download-urls/") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['ss-api-key'] = @key_id
      req.headers['ss-request-timestamp'] = timestamp

      req.body = {
        # https://ruby-doc.org/stdlib-2.4.3/libdoc/openssl/rdoc/OpenSSL/KDF.html#method-c-pbkdf2_hmac
        # pbkdf2_hmac(pass, salt:, iterations:, length:, hash:)
        'checksum' => OpenSSL::KDF.pbkdf2_hmac(@key_code, salt: package_code, iterations: 1024, length: 32, hash: 'SHA256').unpack('H*').first,
        'startSegment' => 1,
        'endSegment' => 25
      }.to_json

      req.headers['ss-request-signature'] = OpenSSL::HMAC.hexdigest("SHA256", @key_secret, @key_id+"/#{API}/package/#{@thread}/file/#{file_id}/download-urls/"+timestamp+req.body)
    end
    #output = Faraday.new("#{@uri}/#{API}/package/#{@thread}/file/#{file_id}/download-urls/", headers: {
                           #}).get.body

  end

  #
  # In theory there is a way to perform the same with net/http, but this keeps failing for me, even with all examples/documentation
  # https://stackoverflow.com/questions/44839503/ruby-send-get-request-with-headers
  def net_http_get_package_info
    thread = @thread
    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S\+0000")

    uri = URI("#{@uri}/#{API}/package/#{@thread}/")

    req = Net::HTTP::Get.new(uri)
    req['Content-Type'] = 'application/json'
    req['ss-api-key'] = @key_id
    req['ss-request-timestamp'] = timestamp
    req['ss-request-signature'] = OpenSSL::HMAC.hexdigest("SHA256", @key_secret, @key_id+"/#{API}/package/#{thread}"+timestamp)

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) {|http|
      http.request(req)
    }

    puts res.body
  end


end
