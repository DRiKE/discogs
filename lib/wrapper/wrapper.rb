# Core API wrapper class.

require 'uri'
require 'net/http'
require 'rexml/document'
require 'zlib'
require 'stringio'

require File.dirname(__FILE__) + "/resource"

class Discogs::Wrapper

  @@root_host = "http://api.discogs.com"

  attr_reader :user_agent

  def initialize(user_agent=nil)
    @user_agent = user_agent
  end

  def get_release(id)
    query_and_build "release/#{id}", Discogs::Release
  end

  def get_artist(name)
    query_and_build "artist/#{name}", Discogs::Artist, {:releases => "1"}
  end

  def get_label(name)
    query_and_build "label/#{name}", Discogs::Label
  end

  def search(term, options={})
    opts = { :type => :all, :page => 1 }.merge(options)
    params = { :q => term, :type => opts[:type], :page => opts[:page] }

    data = query_api("search", params)
    resource = Discogs::Search.new(data)

    resource.build_with_resp!
  end

 private

  def query_and_build(path, klass, params={})
    data = query_api(path, params)
    resource = klass.send(:new, data)
    resource.build!
  end

  # Queries the API and handles the response.
  def query_api(path, params={})              
    puts "MSP about to hit API"
    response = make_request(path, params)

    raise_unknown_resource(path) if response.code == "404"
    raise_internal_server_error if response.code == "500"

    # Unzip the response data, or just read it in directly
    # if the API responds without gzipping.
    response_body = nil
    begin       
        puts "MSP got response.body #{response.body}"
        inflated_data = Zlib::GzipReader.new(StringIO.new(response.body))
        response_body = inflated_data.read
        
        
    rescue Zlib::GzipFile::Error
        response_body = response.body
    end
       
    puts "MSP got response #{response_body}"
    response_body
  end

  # Generates a HTTP request and returns the response.
  def make_request(path, params={})
    puts "MSP make_request path: #{path}"
    uri = build_uri(path, params)   
    
    puts "MSP make_request uri : #{uri}"

    request = Net::HTTP::Get.new(uri.path + "?" + uri.query)
    request.add_field("Accept-Encoding", "gzip,deflate")
    # request.add_field("User-Agent", @user_agent)

    Net::HTTP.new(uri.host).start do |http|
      puts "MSP exec request : #{uri.host}"
      http.request(request)
    end
  end

  def build_uri(path, params={})
    parameters = { :f => "xml"}.merge(params)
    querystring = "?" + parameters.map { |key, value| "#{key}=#{value}" }.sort.join("&")

    URI.parse(File.join(@@root_host, sanitize_path(path, querystring)))
  end

  def sanitize_path(*path_parts)
    clean_path = path_parts.map { |part| part.gsub(/\s/, '+') }

    clean_path.join
  end

  def raise_unknown_resource(path='')
    puts "Unknown Discogs resource: #{path}"
    raise Discogs::UnknownResource, "Unknown Discogs resource: #{path}"
  end

  def raise_internal_server_error
    puts "The remote server cannot complete the request"
    raise Discogs::InternalServerError, "The remote server cannot complete the request"
  end

end
