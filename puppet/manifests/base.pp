$deps = [
    'autoconf',
    'automake',
    'curl',
    'debhelper',
    'gcc',
    'libssl-dev',
    'git',
    'tcpdump',
    'wget',
    'tar',
    'libxml2-dev',
    'libxslt1-dev',
    'xbase-clients',
    'emacs',
    'wireshark'
]

$hosts = hiera('hosts')

$ovs_version = '2.3.2'

file { '/etc/hosts':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    content => template('/vagrant/puppet/templates/hosts.erb')
}

package { $deps:
    ensure   => installed,
}

exec {"Download Open vSwitch":
    command => "wget http://openvswitch.org/releases/openvswitch-${ovs_version}.tar.gz",
    cwd     => "/home/vagrant",
    creates => "/home/vagrant/openvswitch-${ovs_version}.tar.gz",
    path    => $::path,
    user    => 'vagrant'
}

exec { 'Extract Open vSwitch':
    command => "tar -xvf openvswitch-${ovs_version}.tar.gz",
    cwd     => '/home/vagrant',
    creates => "/home/vagrant/openvswitch-${ovs_version}",
    user    => 'vagrant',
    path    => $::path,
    timeout => 0,
    require => Exec['Download Open vSwitch']
}

exec { 'Compile Open vSwitch':
    command => 'fakeroot debian/rules binary',
    cwd     => "/home/vagrant/openvswitch-${ovs_version}",
    creates => "/home/vagrant/openvswitch-common_${ovs_version}-1_amd64.deb",
    user    => 'root',
    path    => $::path,
    timeout => 0,
    require => [Exec['Extract Open vSwitch'], Package[$deps]]
}

package { 'openvswitch-common':
    ensure   => installed,
    provider => dpkg,
    source   => "/home/vagrant/openvswitch-common_${ovs_version}-1_amd64.deb",
    require  => Exec['Compile Open vSwitch']
}

package { 'openvswitch-switch':
    ensure   => installed,
    provider => dpkg,
    source   => "/home/vagrant/openvswitch-switch_${ovs_version}-1_amd64.deb",
    require  => Package['openvswitch-common']
}

package { 'openvswitch-datapath-dkms':
    ensure   => installed,
    provider => dpkg,
    source   => "/home/vagrant/openvswitch-datapath-dkms_${ovs_version}-1_all.deb",
    require  => Package['openvswitch-switch']
}

package { 'openvswitch-pki':
    ensure   => installed,
    provider => dpkg,
    source   => "/home/vagrant/openvswitch-pki_${ovs_version}-1_all.deb",
    require  => Package['openvswitch-datapath-dkms']
}
