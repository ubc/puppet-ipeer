class ipeer::db(
  $root_password = 'secretpassword',
  $db_name = 'ipeer',
  $db_username = 'ipeer',
  $db_password = 'ipeer',  
) {
  class {'db::mysql':
    root_password => $root_password,
    databases => {
      "$db_name" => {
        user => $db_username,
        password => $db_password, 
      },
    }  
  }

  # export resource to be used by web instance
  $db_host = $fqdn
  @@file {"/etc/ipeerdb.${domain}.php":
    ensure => present,
    content => template('ipeer/database.php.erb'),
    tag => $domain
  }
}
