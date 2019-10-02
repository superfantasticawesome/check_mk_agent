require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'check_mk_agent',
  docs: <<-EOS,
@summary The check_mk type
@example
check_mk_agent { $check_mk_server:
  ensure   => 'present',
  username => 'automation',
  secret   => 'n7dfc9e4-0e50-4f52-9269-01x0fe2d6z7a',
}

This type provides Check MK agent registration with the given monitoring server.
EOS
  features: ['simple_get_filter'],
  attributes: {
    ensure: {
      type:    'Enum[present, absent]',
      desc:    'Whether the agent should be registered with the Check MK monitoring server.',
      default: 'present',
    },
    name: {
      type:      'String',
      desc:      'The hostname of the Check MK monitoring server.',
      behaviour: :namevar,
    },
    site: {
      type:      'String',
      desc:      'The Check MK site name.',
      behaviour: :parameter,
    },
    username: {
      type:      'String',
      desc:      'The username credential.',
      behaviour: :parameter,
    },
    secret: {
      type:      'String',
      desc:      'The secret credential.',
      behaviour: :parameter,
    },
    scheme: {
      type:    'String',
      desc:    'The http protocol. Defaults to https.',
      default: 'https',
    },
    agent_alias: {
      type:    'String',
      desc:    'The agent alias. Defaults to empty string value.',
      default: '',
    },
    folder: {
      type: 'String',
      desc: 'The folder placement for the agent.',
    },
    tag_agent: {
      type:    'String',
      desc:    'The agent tag. Defaults to cmk-agent.',
      default: 'cmk-agent',
    },
    tag_criticality: {
      type:    'String',
      desc:    'The agent environment. Defaults to prod.',
      default: 'prod',
    },
    tag_address_family: {
      type:    'String',
      desc:    'The agent IP address family. Defaults to ip-v4-only.',
      default: 'ip-v4-only',
    },
  },
  autorequire: {
    user:    'check_mk_agent',
    package: 'check-mk-agent',
  },
)
