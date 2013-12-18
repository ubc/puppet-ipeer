class ipeer::web(
  $instances = {},
  $timezone = 'America/Vancouver',
) {
  
#  file { "/www_config":
#    ensure => "directory",
#  }
  
#  mount { "/www_config":
#    device => "10.93.0.3:/data/ipeer/config",
#    fstype => "nfs4",
#    ensure  => "mounted",
#    options => "defaults",
#    atboot  => "true",
#  }
  
  #################################
  # services
  
  if ! defined (Class["nginx"]) {
    class { 'nginx': }
  }
  
  # vhosts and locations are defined in ipeer::instance defined type
  nginx::resource::upstream { 'ipeer':
    ensure  => present,
    members => [
      '127.0.0.1:9001', 
    ],
  }
  
  # php environment  
  if ! defined (php::ini['/etc/php.ini']) {
    php::ini { '/etc/php.ini':
        display_errors => 'Off',
        memory_limit   => '256M',
        date_timezone  => $timezone,
    }
  }
  
  if ! defined (Class["php::cli"]) {
    include php::cli
  }
  
  if ! defined (php::module['pecl-apc']) {
    php::module { 'pecl-apc': }
    php::module::ini { 'pecl-apc':
      settings => {
          'apc.enabled'      => '1',
          'apc.shm_segments' => '1',
          'apc.shm_size'     => '32M',
      }
    }
  }

  if ! defined (php::module['xml']) {
    php::module { 'xml': }
  }

  if ! defined (php::module['gd']) {
    php::module { 'gd': }
  }

  if ! defined (php::module['ldap']) {
    php::module { 'ldap': }
  }

  if ! defined (php::module['mysql']) {
    php::module { 'mysql': }
  }

  
  include php::fpm::daemon
  php::fpm::conf { 'ipeer':
      listen  => '127.0.0.1:9001',
      user    => 'nginx',
      # For the user to exist
      require => Package['nginx'],
  }
  
  # php session directory
  if ! defined (File['/var/lib/php/session']) {
    file { '/var/lib/php/session':
      ensure => "directory",
      owner => 'nginx',
      group => 'nginx',
      mode => '0775',
      require => Package['nginx'],
    }
  }

  validate_hash($instances)
  create_resources('ipeer::instance',$instances)
}
