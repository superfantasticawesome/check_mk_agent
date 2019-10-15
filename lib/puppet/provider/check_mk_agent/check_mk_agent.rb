# https://checkmk.com/cms_web_api_references.html
require 'puppet/resource_api/simple_provider'
require "net/http"
require "uri"
require "json"
require "timeout"

# Implementation for the check_mk_agent type using the Resource API.
class Puppet::Provider::CheckMkAgent::CheckMkAgent < Puppet::ResourceApi::SimpleProvide
  def method_debug(message, level = 'debug')
    method = (caller[0] =~ /`([^']*)'/ and $1)
    message = "#{self.class.name}::#{method}(): #{message}"
    case level
    when 'info'
      Puppet.notice "#{message}"
    when 'warn'
      Puppet.warning "#{message}"
    when 'error'
      Puppet.err "#{message}"
    else
      Puppet.debug "#{message}"
    end
  end

  def get(context, name)
    method_debug("Retrieving state for #{context.type.attributes.keys.inspect}")
    [symbolize_keys(get_state({}))]
  end

  def create(context, name, should)
    register(name, should)
  end

  def update(context, name, should)
    deregister(name, false)
    register(name, should)
  end

  def delete(context, name)
    deregister(name, true)
  end

  def state_file
    '/opt/puppetlabs/puppet/cache/state/check_mk_agent.yaml'
  end

  def stringify_keys(h)
    h = Hash[h.map { |k,v| k.kind_of?(Symbol) ? [k.to_s, v] : [k, v] }]
  end

  def symbolize_keys(h)
    h = Hash[h.map { |k,v| k.kind_of?(String) ? [k.to_sym, v] : [k, v] }]
  end

  def get_state(state)
    File.exists?(self.state_file) ? YAML.load(File.read(self.state_file)) : state
  end

  def set_state(state)
    File.open(self.state_file, 'w') { |f| f.write(state.to_yaml) }
  end

  def check_mk_server_uri(name, params)
    "#{params['scheme']}://#{name}/#{params['site']}"
  end

  def register(name, changes)
    changes = stringify_keys(changes)
    check_mk_server = check_mk_server_uri(name, changes)
    query, data = get_request(changes, 'add_host')
    response = api_request(check_mk_server, query, data)
    if response['result'] && response['result'].include?('already exists')
      method_debug("Agent registration exists on '#{name}' but local state out of sync.", 'warn')
    elsif response['result_code'] == 0
      ['discover_services', 'activate_changes'].each do |action|
        query, data = get_request(changes, action)
        api_request(check_mk_server, query, data)
        set_state(changes)
      end
    end
  end

  def deregister(name, delete)
    current_state = get_state({})
    check_mk_server = check_mk_server_uri(name, current_state)
    query, data = get_request(current_state, 'delete_host')
    api_request(check_mk_server, query, data)
    File.delete(self.state_file) if delete
  end

  def get_request(changes, action)
    query = {
      "_username" => changes['username'],
      "_secret"   => changes['secret'],
      "action"    => "#{action}"
    }
    mode = {
      "mode"                  => 'dirty',
      "allow_foreign_changes" => '1'
    }
    query = query.merge(mode) if action == 'activate_changes'
    if action.include?('add_host')
      data = {
        "hostname"       => Facter['hostname'].value,
        "folder"         => changes['folder'],
        "create_folders" => '1',
        "attributes"     => {
          "ipaddress"          => Facter['ipaddress'].value,
          "site"               => changes['site'],
          "alias"              => changes['agent_alias'],
          "tag_agent"          => changes['tag_agent'],
          "tag_address_family" => changes['tag_address_family'],
          "tag_criticality"    => changes['tag_criticality']
        }
      }
    elsif action.include?('delete_host') || action.include?('discover_services')
      data = {
        "hostname" => Facter['hostname'].value,
      }
    else
      data = {
        "sites" => [changes['site']],
      }
    end
    method_debug("#{query} #{data}")
    return query, data
  end

  def api_request(host, query, data)
    uri = URI.parse("#{host}/check_mk/webapi.py?")
    uri.query = URI.encode_www_form(query)
    data = "request=#{data.to_json}"
    if port_reachable(uri.host, uri.port)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?
      request = Net::HTTP::Post.new(uri.request_uri)
      request.content_type = 'application/x-www-form-urlencoded'
      request.body = data
      response = http.request(request)
      method_debug("#{response.body}")
      return JSON.parse(response.body)
    else
      raise Puppet::Error, "The Check MK server '#{uri.host}' is not responding on port #{uri.port}"
    end
  end

  def port_reachable(host, port)
    timeout = 2
    result = false
    socket = nil
    begin
      Timeout::timeout(timeout) do
        socket = TCPSocket.open(host, port)
        result = true
      end
    rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT
    rescue Timeout::Error
    ensure
      if socket
        socket.shutdown rescue nil
        socket.close rescue nil
      end
    end
    return result
  end
end
