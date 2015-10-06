$deps = [
    'mariadb-server',
]

$hosts = hiera('hosts')

file { '/home/vagrant/devstack':
   ensure => 'link',
   target => '/opt/devstack',
}

package { $deps:
    ensure   => installed,
}

# Warm Maria up, so initial password is non-empty
# Ref: https://gist.github.com/333007187d69fe2fe282
#
service { 'mariadb.service':
    ensure => 'running',
    require => Package[$deps],
}
file { '/tmp/setup_mysql.txt':
    ensure  => present,
    owner   => 'vagrant',
    group   => 'vagrant',
    content => template('/vagrant/puppet/templates/setup_mysql.erb'),
}
exec { 'Warmup mysql':
    command => '/usr/bin/mysql --user=root --password="" mysql < /tmp/setup_mysql.txt',
    user    => 'vagrant',
    onlyif  => ['/usr/bin/test -f /usr/bin/mysql'],
    require => [File['/tmp/setup_mysql.txt'], Service['mariadb.service']],
}

vcsrepo { '/opt/devstack':
    ensure   => present,
    provider => git,
    user     => 'vagrant',
    # source   => 'https://github.com/flavio-fernandes/devstack.git',
    source   => 'https://github.com/openstack-dev/devstack.git',
    revision => 'stable/liberty',
    before   => File['/opt/devstack/local.conf'],
}

file { '/opt/devstack/local.conf':
    ensure  => present,
    owner   => 'vagrant',
    group   => 'vagrant',
    content => template('/vagrant/puppet/templates/control.local.conf.erb'),
}

