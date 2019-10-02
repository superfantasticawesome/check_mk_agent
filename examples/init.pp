# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include check_mk_agent
#
class check_mk_agent {
  Enum[absent, present] $ensure,
  String $check_mk_server,
  String $site,
  String $agent_ssh_key,
  String $username,
  String $secret,
  Enum[http, https] $scheme,
  String $folder,
  String $tag_agent,
  String $tag_criticality,
  String $tag_address_family,
  String $package,
  String $package_source,
){
  $curl_opts = $scheme ? {
    'https' => '-k',
    default => '',
  }

  if $ensure == 'present' and $package_source == 'server' {
    exec { 'download_package':
      command => "curl ${curl_opts} ${scheme}://${check_mk_server}/${site}/check_mk/agents/${package} -o /tmp/${package}",
      unless  => 'rpm -qa | grep check-mk-agent',
      path    => '/usr/bin:/usr/sbin:/bin',
      notify  => Package['check-mk-agent'],
    }
  }

  package { 'check-mk-agent':
    ensure   => "${ensure}",
    provider => 'yum',
    source   => $package_source ? {
      'server' => "/tmp/${package}",
      default  => undef,
    },
  }

  user { 'check_mk_agent':
    ensure     => "${ensure}",
    comment    => 'Check_MK Agent',
    shell      => '/usr/bin/check_mk_agent',
    home       => '/var/lib/check_mk_agent',
    managehome => true,
    password   => '!!',
    require    => Package['check-mk-agent'],
  }

  file { ['/var/lib/check_mk_agent', '/var/lib/check_mk_agent/.ssh']:
    ensure  => $ensure ? {
      'present' => 'directory',
      default   => 'absent',
    },
    owner   => 'check_mk_agent',
    require => User['check_mk_agent'],
  }

  ssh_authorized_key { "check_mk_agent@${facts['networking']['hostname']}":
    ensure => "${ensure}",
    user   => 'check_mk_agent',
    type   => 'ssh-rsa',
    key    => "${agent_ssh_key}",
  }

  check_mk_agent { "${check_mk_server}":
    ensure             => "${ensure}",
    username           => "${username}",
    secret             => "${secret}",
    scheme             => "${scheme}",
    site               => "${site}",
    folder             => "${folder}",
    tag_agent          => "${tag_agent}",
    tag_criticality    => "${tag_criticality}",
    tag_address_family => "${tag_address_family}",
  }
}
