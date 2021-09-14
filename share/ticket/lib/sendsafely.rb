require 'net/http'
require 'openssl'
require 'time'
require 'faraday'
require 'mixlib/shellout'

class Sendsafely
  attr_reader :thread, :package_code, :key_code

  # DEBUG - reading attributes
  attr_reader :info, :response

  API='api/v2.0'

  def initialize(config, **opts)
    @sendsafely_url = config.sendsafely_url
    @sendsafely_key_id = config.sendsafely_key_id
    @sendsafely_key_secret = config.sendsafely_key_secret
    @opts = opts

    @parts_dir = "#{Dir.pwd}/parts/"
    Dir.mkdir(@parts_dir) unless Dir.exist?(@parts_dir)
  end

  #
  # Downloading a package
  # https://sendsafely.zendesk.com/hc/en-us/articles/360027599232-SendSafely-REST-API
  def download_package(link)
    puts "Fetching files for #{link}"
    # Step 1 - Retrieve Package Information
    output = self.get_package_info(link)
    puts "DEBUG: #{output}"

    @info = JSON.parse(output)
    @server_secret = @info['serverSecret']

    # Step 2 - Download File Parts
    # For each file in the "files" array contained in the Package Information response from Step 1, you will need to do the following:

    @info['files'].each do |file|
      puts file.inspect if @opts[:verbose]
      file_id = file['fileId']
      filename = file['fileName']
      puts " * Processing '#{filename}', parts(#{file['parts']})"

      start_segment=1
      end_segment=25

      while start_segment <= file['parts']
        # a. Get Download Urls for each File Part
        @response = self.download_urls(file_id, @package_code, start_segment, end_segment)
        body = JSON.parse(@response.body)


        # b. Download and Decrypt File Parts
        # Each file part will need to be individually downloaded and decrypted using PGP.
        # You will need to use the "Server Secret" (included in the Package Information response from Step 1) and the keycode (Client Secret) in order to compute the required decryption key.
        if body['response'] == 'SUCCESS'
          #puts body['downloadUrls'] if @opts[:verbose]
          body['downloadUrls'].each do |download_url|
            puts download_url.inspect if @opts[:verbose]
            response = self.download_file_part(file_id, download_url)

            # Only perform decryption if file had to be downloaded
            self.decrypt_file_part("#{file_id}-#{download_url['part']}", @server_secret+@key_code) unless response == false
          end
        end

        start_segment += 25
        end_segment += 25
      end

      # c. Re-assemble Decrypted File Parts
      # The decrypted file parts should be re-assembled in order (sequentially based on the file part number) to construct the decrypted file.
      self.concatenate(file)
    end
  end


  def get_package_info(link)
    @thread, @package_code, @key_code = link.scan(/thread=([\w-]+)&packageCode=([\w-]+)#keyCode=([\w-]+)/).first
    puts "Processing Sendsafely link #{@thread}/#{@package_code}"

    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+0000")

    req = Faraday.new("#{@sendsafely_url}/#{API}/package/#{@thread}", headers: {
                             'ss-api-key' => @sendsafely_key_id,
                             'ss-request-timestamp' => timestamp,
                             'ss-request-signature' => OpenSSL::HMAC.hexdigest("SHA256", @sendsafely_key_secret, @sendsafely_key_id+"/#{API}/package/#{@thread}"+timestamp),
                           }).get

    if req.success?
      req.body
    else
      puts "Error fetching info from sendsafely"
      puts "Status: #{req.status}\nBody: #{req.body}"
    end
  end

  # Each file is split into multiple smaller "parts" for faster processing. The number of "parts" associated with each file is included as a property within the files array from Step 1.
  # Each part has its own URL, which can be obtained from the download-urls endpoint:
  #
  # https://bump.sh/doc/sendsafely-rest-api#operation-post-package-parameter-file-parameter-download-urls
  def download_urls(file_id, package_code, start_segment=1, end_segment=25)
    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+0000")

    resp = Faraday.post("#{@sendsafely_url}/#{API}/package/#{@thread}/file/#{file_id}/download-urls/") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['ss-api-key'] = @sendsafely_key_id
      req.headers['ss-request-timestamp'] = timestamp

      req.body = {
        # Use the following inputs for your PBKDF2 function:
        # Hashing Algorithm - SHA-256
        # Password  - Use the keycode for this value
        # Salt - Use the Package Code for this value
        # Iteration Count - 1024
        # Key Length - 32 bytes
        # https://ruby-doc.org/stdlib-2.4.3/libdoc/openssl/rdoc/OpenSSL/KDF.html#method-c-pbkdf2_hmac
        # pbkdf2_hmac(pass, salt:, iterations:, length:, hash:)
        'checksum' => OpenSSL::KDF.pbkdf2_hmac(@key_code, salt: package_code, iterations: 1024, length: 32, hash: 'SHA256').unpack('H*').first,
        'startSegment' => start_segment,
        'endSegment' => end_segment
        # NOTE: Up to 25 download URLS for each file can be obtained at once. You can use the startSegment parameter to tell the server which file part you would like as the starting point for each request. Note that each URL contains a time-stamped authentication token that is only valid for 60 minutes, so in general you should not obtain these URLs until you are ready to use them.
      }.to_json

      req.headers['ss-request-signature'] = OpenSSL::HMAC.hexdigest("SHA256", @sendsafely_key_secret, @sendsafely_key_id+"/#{API}/package/#{@thread}/file/#{file_id}/download-urls/"+timestamp+req.body)
    end
  end

  def download_file_part(file_id, download_url)
    basename = "#{file_id}-#{download_url['part']}"
    filename = "#{@parts_dir}#{basename}"
    overwrite_message = ""


    if File.exist?(filename)
      if @opts[:force]
        overwrite_message = ", overwriting existing file"
      else
        puts "   * Skipping #{basename}, already exists..."
        return false
      end
    end
    puts "   * Downloading #{basename}#{overwrite_message}"

    response = Faraday.get download_url['url']
    if response.status == 200
      File.open("#{filename}", 'w') do |file|
        file.write response.body
      end
    end
    response.status
  end

  #When decrypting each file part, make sure you use the following PGP options:
  #
  #    Symmetric-Key Algorithm should be 9 (AES-256)
  #    Compression Algorithm should be 0 (Uncompressed)
  #    Hash Algorithm should be 8 (SHA-256)
  #    Passphrase:  Server Secret concatenated with a random 256-bit Client Secret
  #    S2k-count: 65535
  #    Mode: b (62)
  def decrypt_file_part(filename, secret)
    puts filename.inspect if @opts[:verbose]
    #(1..file['parts']).each do |n|

      puts "   * Decrypting #{filename}"
      part = "#{@parts_dir}#{filename}"


      cmd = ["gpg","--batch","--yes","--passphrase",secret,"--output","#{part}.decrypted","--decrypt",part]
      decrypt_out = shellout(cmd)

      results= {
        results: decrypt_out.stdout,
        error: decrypt_out.stderr,
        status: decrypt_out.exitstatus
      }
    #end
  end

  def concatenate(file)
    File.open(file['fileName'], 'w') do |output|
      (1..file['parts']).each do |n|
        part =File.open("#{@parts_dir}#{file['fileId']}-#{n}.decrypted", 'r').read
        #puts part.size
        output.write part
        #IO.binread("#{file['fileId']}-#{n}.decrypted")
      end
    end
  end

  private

  def shellout(cmd, options = {})
    shell = Mixlib::ShellOut.new(cmd, options)
    shell.run_command
    shell
  end

  # In theory there is a way to perform the same with net/http, but this keeps failing for me, even with all examples/documentation
  # https://stackoverflow.com/questions/44839503/ruby-send-get-request-with-headers
  def net_http_get_package_info
    thread = @thread
    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S\+0000")

    uri = URI("#{@sendsafely_url}/#{API}/package/#{@thread}/")

    req = Net::HTTP::Get.new(uri)
    req['Content-Type'] = 'application/json'
    req['ss-api-key'] = @sendsafely_key_id
    req['ss-request-timestamp'] = timestamp
    req['ss-request-signature'] = OpenSSL::HMAC.hexdigest("SHA256", @sendsafely_key_secret, @sendsafely_key_id+"/#{API}/package/#{thread}"+timestamp)

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) {|http|
      http.request(req)
    }

    puts res.body
  end
end
