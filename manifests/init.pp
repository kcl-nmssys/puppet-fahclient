/*
Folding@Home client
Xand Meaden, King's College London

@param user
  Folding@Home username

@param passkey
  Folding@home user's passkey

@param team_id
  Folding@home team ID number

@param ensure
  Ensure absent or present (default)

@param cause
  Which Folding@Home cause to support (ANY includes COVID-19)

@param power
  How much CPU/GPU resource to use

@param bigpackets
  How much memory resource to use

@param gpu
  Whether to use GPU

@param gpu_slots
  How many GPU slots to use

@param package_source_path
  URL or local file path to package file (.rpm or .deb)
  On RedHat-based distros this can be a URL, on Debian-based it must be a local file
  If set to undef, package will be installed for a pre-configured repo

*/
class fahclient (
  String $user,
  String $passkey,
  Integer $team_id,
  Enum['absent', 'present'] $ensure          = 'present',
  Pattern[/^[A-Z]+$/] $cause                 = 'ANY',
  Enum['light', 'medium', 'full'] $power     = 'medium',
  Enum['big', 'normal', 'small'] $bigpackets = 'normal',
  Boolean $gpu                               = true,
  Integer $gpu_slots                         = 0,
  Optional[String] $package_source_path      = $fahclient::params::package_source,
) {

  if $ensure == 'present' {
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

    package {
      'fahclient':
        ensure   => 'present',
        provider => $package_provider,
        source   => $package_source,
        notify   => Exec['Disable fahclient legacy service'];
    }

    exec {
      'Disable fahclient legacy service':
        user        => 'root',
        command     => '/etc/init.d/FAHClient stop; /usr/bin/mv /etc/init.d/FAHClient /usr/local/sbin',
        provider    => 'shell',
        refreshonly => true;
    }

    file {
      '/lib/systemd/system/fahclient.service':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/fahclient/fahclient.service',
        notify  => Exec['Setup fahclient systemd service'];

      '/etc/fahclient/config.xml':
        ensure  => 'present',
        owner   => 'fahclient',
        group   => 'root',
        mode    => '0640',
        content => template('fahclient/config.xml.erb'),
        notify  => Service['fahclient'],
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
      'Setup fahclient systemd service':
        user        => 'root',
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true;
    }

    service {
      'fahclient':
        ensure  => 'running',
        enable  => true,
        require => Exec['Setup fahclient systemd service'];
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
  }
}
