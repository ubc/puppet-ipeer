class ipeer::balancer (
  $port = 80,
  $server_name = undef,  
  $ssl = false,
  $ssl_cert = undef,
  $ssl_key = undef,
  $ssl_port = 443,
  $proxy_cache_path = false,
  $proxy_cache_levels      = 1,
  $proxy_cache_keys_zone   = 'd2:100m',
  $proxy_cache_max_size    = '500m',
  $proxy_cache_inactive    = '20m',
  $proxy_cache = false,
  $proxy_cache_valid = false,
) {
  include epel

  class { 'selinux':
    mode => 'disabled'
  }

  class { 'nginx': 
    confd_purge => true,
    proxy_cache_path      => $proxy_cache_path,
    proxy_cache_levels    => $proxy_cache_levels,
    proxy_cache_keys_zone => $proxy_cache_keys_zone,
    proxy_cache_max_size  => $proxy_cache_max_size,
    proxy_cache_inactive  => $proxy_cache_inactive,
  }

  $app_members = query_nodes("fqdn~\"$domain\" and Class[ipeer::web]", 'ipaddress')

  nginx::resource::upstream { 'ipeer_app_cluster':
   ensure  => present,
   members => $app_members,
  }

  #nginx::resource::upstream { 'ipeer_static_cluster':
  # ensure  => present,
  # members => $static_members,
  #}

  nginx::resource::vhost { 'ipeer_balancer':
    ensure   => present,
    proxy    => 'http://ipeer_app_cluster',
    listen_port => $port,
    server_name => $server_name,
    proxy_set_header => ['Host $host', 'X-Real-IP $remote_addr', 'X-Forwarded-For $proxy_add_x_forwarded_for', 'X-Queue-Start "t=${msec}000"'],
    vhost_cfg_prepend => { 'add_header' => "X-Load-Balancer ${hostname}" },
    ssl => $ssl,
    ssl_cert => $ssl_cert,
    ssl_key  => $ssl_key,
    ssl_port => $ssl_port,
    proxy_cache  =>  $proxy_cache,
    proxy_cache_valid => $proxy_cache_valid,
  }

  #nginx::resource::location { 'ipeer_static_file':
  #  ensure => present,
  #  location => '/ipeer2_course_files',
  #  vhost => 'ipeer_balancer',
  #  proxy => 'http://ipeer_static_cluster',
  #  priority => 450,
  #}

  firewall { '100 allow http access':
    port   => [$port],
    proto  => tcp,
    action => accept,
  }
 
  if $ssl { 
    firewall {'110 allow https access':
      port   => [$ssl_port],
      proto  => tcp,
      action => accept,
    }
  }
}

