# Definition: ipeer::instance
#
# This class installs iPeer instance
#
# Parameters:
#   static_cache cache for static files. false: no cache, other value, e.g. 7d for 7 days

define ipeer::instance (
  $server_domain,
  $doc_base = "/www_data/html",
  $port = 80,
  $revision = undef,
  $mount_device = undef,
  $mount_path = "/www_data",
  $mount_fstype = "nfs4",
  $owner = 'root',
  $group = 'root',
  $default = false,
  $auth_module = 'default',
  $ldap_host = 'ldaps://yourschool.edu.ca/',
  $ldap_port = 636,
  $ldap_serviceUsername = 'uid=ipeer, ou=Special Users, o=yourschool.edu.ca',
  $ldap_servicePassword = 'secret',
  $ldap_baseDn = 'ou=Campus Login, o=yourshool.edu.ca',
  $ldap_usernameField = 'username',
  $ldap_attributeSearchFilters = '',
  $ldap_attributeMap = '',
  $ldap_fallbackInternal = true,
  $session_handling = 'php',
  $ssl = false,
  $ssl_cert = undef,
  $ssl_key = undef,
  $ssl_port = 443,
  $proxy_cache = false,
  $proxy_cache_valid = false,
  $static_cache = false, 
  $apc_password = 'password',
  $db_name = 'ipeer',
  $db_username = 'ipeer',
  $db_password = 'ipeer',  
  $db_host = 'localhost',
  $local_config = true,
  $import_sample_data = false
) {

  $parent_path = dirname($doc_base)
  if ! defined(Exec["mkdir_dir_$parent_path"]) {
    exec { "mkdir_dir_$parent_path":
      path    => [ '/bin', '/usr/bin' ],
      command => "mkdir -p ${parent_path}",
      unless  => "test -d ${parent_path}",
    }
  }

  if $mount_device {
    mount { $mount_path:
      device => $mount_device,
      fstype => $mount_fstype,
      ensure  => "mounted",
      options => "defaults",
      atboot  => "true",
    }
  }

  # if $revision is defined, checkout the source code
  if $revision {
    if ! defined(Class["git"]) {
      include git
    }

    vcsrepo { "$doc_base":
      ensure   => present,
      provider => git,
      require  => [ Package["git"] ],
      source   => "https://github.com/ubc/iPeer.git",
      revision => $revision,
      before => File["$doc_base"],
    }
  } 

  file { "$doc_base":
    ensure => "directory",
    owner => $owner,
    group => $group,
    mode => "0644",
    ignore => ["$doc_base/app/tmp", "build/"],
    require => Package['nginx'],
#    recurse => true,
  } ->

  # TODO: change access to web user
  file { ["$doc_base/app/tmp", "$doc_base/app/tmp/cache", "$doc_base/app/tmp/logs", "$doc_base/app/tmp/sessions"]:
    ensure => "directory",
    mode => "0777",
  }

  nginx::resource::vhost {$server_domain:
    ensure         => present,
    www_root	   => "$doc_base/app/webroot",
    listen_port    => $port,
    server_name => $default ? {
      true  => [$server_domain, $fqdn],
      false => [$server_domain],
    },
    vhost_cfg_prepend => { 'add_header' => "X-APP-Server ${hostname}" },
    ssl => $ssl,
    ssl_cert => $ssl_cert,
    ssl_key  => $ssl_key,
    ssl_port => $ssl_port,
    proxy_cache  =>  $proxy_cache,
    proxy_cache_valid => $proxy_cache_valid,
    use_default_location => false,
    proxy_set_header => ['Host $host', 'X-Real-IP $remote_addr', 'X-Forwarded-For $proxy_add_x_forwarded_for']
  }

  nginx::resource::location { "php_root_$server_domain":
    ensure => present,
    vhost => $server_domain,
    location => '/',
    www_root => "$doc_base/app/webroot",
    location_custom_cfg_prepend => {'if (-f $request_filename)' => '{ break; }',
      'if (-d $request_filename)' => '{ break; }',
      'rewrite' => '^(.+)$ /index.php?url=$1 last;'}
  }

  if $static_cache {
    nginx::resource::location { "static_$server_domain":
      ensure => present,
      www_root	   => "$doc_base/app/webroot",
      vhost => $server_domain,
      location => '~ ^/(img|js|css)/',
      location_cfg_append => { 'access_log' => 'off', 'expires' => $static_cache, 'add_header' => 'Cache-Control public'}
    }
  }
  
  nginx::resource::location { "php_$server_domain":
    ensure => present,
    vhost => $server_domain,
    location => '~ \.php$',
    fastcgi        => 'ipeer',
    fastcgi_script => "$doc_base/app/webroot\$fastcgi_script_name",
    location_cfg_prepend => { fastcgi_read_timeout => 600 },
  }

  if ! defined(Firewall["100 allow $port access"]) {
    firewall { "100 allow $port access":
      port   => $port,
      proto  => tcp,
      action => accept,
    }
  }

  # setup iPeer db config file
  #File <<| tag == $domain |>> ->
  file {"$doc_base/app/config/database.php":
    ensure => present,
    content => template('ipeer/database.php.erb'),
    tag => $domain
  }

    @@mysql::db { "${db_name}_${fqdn}":
      user => $db_username,
      password => $db_password,
      dbname => $db_name,
      host => $db_host ? {
          'localhost' => $db_host,
          default => $fqdn,
      },
      grant => ['ALL'],
      sql => $import_sample_data ? {
          false => '',
          true => "$doc_base/app/config/sql/ipeer_samples_data.sql",
      },
      tag => $domain,
    }

  # make sure the installed.txt exists
  file {"$doc_base/app/config/installed.txt":
    ensure => present,
  }

  # setup authentication config file
  file {"$doc_base/app/config/guard.php":
    ensure => present,
    content => template('ipeer/guard.php.erb'),
  }

  # setup core config override file
  if $local_config {
    file {"$doc_base/app/config/config.local.php":
      ensure => present,
      content => template('ipeer/config.local.php.erb'),
    }
  }

  # link apc.php
  file {"$doc_base/app/webroot/apc.php":
    ensure => present,
    content => template('ipeer/apc.php.erb'),
  }
}
