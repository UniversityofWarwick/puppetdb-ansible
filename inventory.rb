#!/usr/bin/env ruby

require 'puppetdb'
require 'yaml'
require 'json'
require 'optparse'
require 'pp'

$node_deployment = ENV['NODE_DEPLOYMENT']
unless $node_deployment
  puts "NODE_DEPLOYMENT must be set"
  exit 1
end

class Inventory

  def initialize(settings)
    @client = PuppetDB::Client.new({
      :server => settings['server'],
      :pem => {
        'cert'    => settings['ssl_cert'],
        'key'     => settings['ssl_key'],
        'ca_file' => settings['ssl_ca']
      }
    })
  end
    
    
  def fetch_host_by_fqdn(fqdn)
    response = @client.request('facts', [:'and',
      [:'=', 'name', 'fqdn'],
      [:'=', 'value', fqdn]
    ])
    (response.data[0] || {})['certname']
  end

  def fetch_hosts_metadata(certnames)
    if certnames.empty?
      {}
    else
      query = [:or] + certnames.map {|certname|
        ['=','certname',certname]
      }
      response = @client.request('facts', query)
      what = response.data.group_by { |fact|
        fact['certname'] 
      }.map { |certname, facts|
        [
          certname, 
          Hash[facts.map { |fact| [ fact['name'], fact['value'] ] }]
        ]
      }
      Hash[what]
    end
  end

  def process(mode, hostname=nil)
    
    data = {}
    if mode == :list
   
      response = @client.request(
        'resources',
        [:and,
          ['=', 'type', 'Nodes::Exported_metadata'],
          ['=', ['parameter','node_deployment'], $node_deployment]
        ]
      )
      
      items = response.data
      certnames = items.map do |item|
        item['certname']
      end

      nodes = if certnames.empty?
        []
      else
        nodes_query = [:or] + certnames.map { |certname|
          ['=', 'name', certname] 
        }

        nodes_response = @client.request('nodes', nodes_query)
        nodes_response.data
      end

      data = {
        'all' => {
          'hosts' => nodes.map { |res| res['name'] }.uniq
        },
        '_meta' => {
          'hostvars' => fetch_hosts_metadata(certnames) 
        }
      }
      
      items.each do |item|
        host = item['certname']
        params = item['parameters']
        app = params['node_app']
        tier = params['node_tier']
        deployment = params['node_deployment']
        group_name = "#{app}_#{tier}"
        data[group_name] ||= {}
        data[group_name]['hosts'] ||= []
        data[group_name]['hosts'].push(host)
      end
    
    elsif mode == :host
    
      clientcert = fetch_host_by_fqdn(hostname)

      if clientcert
    
        response = @client.request("nodes/#{clientcert}/facts", [:'and',
          [:'~', 'name', '.*'],
        ])
        facts = response.data
        data[hostname] = Hash[facts.map { |fact|
          [ fact['name'], fact['value'] ]
        }]

      end
    
    else
      data['error'] = 'No mode selected'
    end
    
    
    puts data.to_json
    
    if data['error']
      exit 1
    end

  end

end


SETTINGS_FILE = 'settings.yml'

settings = YAML.load(File.open(SETTINGS_FILE))

inv = Inventory.new(settings)

mode = nil
hostname = nil
OptionParser.new do |opts|
  opts.on('-l', '--list', 'List all hosts') do |l|
    mode = :list
  end
  opts.on('-h', '--host HOST', 'Single host detail') do |host|
    mode = :host
    hostname = host
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!(ARGV)

inv.process(mode, hostname)
