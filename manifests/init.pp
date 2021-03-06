# Folding@Home client
#
# @param user
#   Folding@Home username
#
# @param passkey
#   Folding@home user's passkey
#
# @param team_id
#   Folding@home team ID number
#
# @param ensure
#   Ensure absent or present (default)
#
# @param version
#   Which version to install (optional)
#
# @param cause
#   Which Folding@Home cause to support (ANY, COVID_19, etc)
#
# @param power
#   How much CPU/GPU resource to use
#
# @param gpu
#   Whether to use GPU
#
# @param gpu_slots
#   How many GPU slots to use
#
# @param cpu_slots
#   How many CPU slots to use
#
# @param cpus_per_slot
#   How many CPUs per CPU slot
#
# @param package_source_path
#   URL or local file path to package file (.rpm or .deb)
#   On RedHat-based distros this can be a URL, on Debian-based it must be a local file
#   If set to undef, package will be installed for a pre-configured repo
#
# @param uid
#   Optional fixed uid for fahclient user
#
# @param gid
#   Optional fixed gid for fahclient user
#
# @param manage_service
#   Whether to manage service
#
# @param service_ensure
#   Whether service should be running or stopped
#
# @param service_enable
#   Whether to enable service
#
class fahclient (
  String $user,
  String $passkey,
  Integer $team_id,
  Enum['absent', 'present'] $ensure          = 'present',
  Optional[String] $version                  = undef,
  Pattern[/^[A-Z0-9_]+$/] $cause             = 'ANY',
  Enum['light', 'medium', 'full'] $power     = 'medium',
  Boolean $gpu                               = true,
  Integer $gpu_slots                         = 0,
  Integer $cpu_slots                         = 1,
  Integer $cpus_per_slot                     = $facts['processorcount'] / $cpu_slots,
  Optional[String] $package_source_path      = $fahclient::params::package_source_path,
  Optional[Integer] $uid                     = undef,
  Optional[Integer] $gid                     = undef,
  Boolean $manage_service                    = true,
  Enum['running', 'stopped'] $service_ensure = 'running',
  Boolean $service_enable                    = true,
) {

  if $ensure == 'present' {
    if $version {
      $package_ensure = $version
    } else {
      $package_ensure = 'present'
    }

    if $package_source_path {
      case $facts['os']['family'] {
        'RedHat': {
          $package_provider = 'rpm'
        }
        'Debian': {
          $package_provider = 'dpkg'
        }
        default: {
          fail('OS not supported')
        }
      }
      $package_source = $package_source_path
    } else {
      case $facts['os']['family'] {
        'RedHat': {
          $package_provider = 'yum'
        }
        'Debian': {
          $package_provider = 'apt'
        }
        default: {
          fail('OS not supported')
        }
      }
      $package_source = undef
    }

    if $uid and $gid {
      group {
        'fahclient':
          ensure => 'present',
          gid    => $gid;
      }

      user {
        'fahclient':
          ensure  => 'present',
          uid     => $uid,
          comment => 'Folding@home Client',
          shell   => '/sbin/nologin',
          home    => '/var/lib/fahclient',
          require => Group['fahclient'],
          before  => Package['fahclient'];
      }
    }

    package {
      'fahclient':
        ensure   => $package_ensure,
        provider => $package_provider,
        source   => $package_source;
    }

    file {
      '/lib/systemd/system/fahclient.service':
        ensure => 'present',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/fahclient/fahclient.service',
        notify => Exec['Setup fahclient systemd service'];

      '/etc/fahclient/config.xml':
        ensure  => 'present',
        owner   => 'fahclient',
        group   => 'root',
        mode    => '0640',
        content => template('fahclient/config.xml.erb'),
        require => Package['fahclient'];

      ['/etc/fahclient', '/var/lib/fahclient']:
        ensure => 'directory',
        owner  => 'fahclient',
        group  => 'root',
        mode   => '0750';

      '/var/run/fahclient.pid':
        owner => 'root',
        group => 'root',
        mode  => '0644';
    }

    exec {
      'Disable fahclient legacy service':
        user     => 'root',
        command  => '/etc/init.d/FAHClient stop; /bin/mv /etc/init.d/FAHClient /usr/local/sbin',
        provider => 'shell',
        creates  => '/usr/local/sbin/FAHClient';

      'Setup fahclient systemd service':
        user        => 'root',
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true;
    }

    if $manage_service {
      service {
        'fahclient':
          ensure    => $service_ensure,
          enable    => $service_enable,
          subscribe => File['/etc/fahclient/config.xml'],
          require   => Exec['Disable fahclient legacy service', 'Setup fahclient systemd service'];
      }
    }
  } else {
    package {
      'fahclient':
        ensure => 'absent';
    }

    file {
      ['/etc/fahclient/config.xml', '/etc/systemd/system/multi-user.target.wants/fahclient']:
        ensure => 'absent';
    }

    user {
      'fahclient':
        ensure => 'absent';
    }

    group {
      'fahclient':
        ensure => 'absent';
    }
  }
}
