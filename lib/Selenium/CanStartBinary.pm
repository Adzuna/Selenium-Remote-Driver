package Selenium::CanStartBinary;

# ABSTRACT: Teach a WebDriver how to start its own binary aka no JRE!
use Selenium::CanStartBinary::ProbePort qw/find_open_port_above probe_port/;
use Selenium::Firefox::Binary qw/setup_firefox_binary_env/;
use Selenium::Waiter qw/wait_until/;
use Selenium::Firefox::Profile;
use Moo::Role;

=head1 NAME

CanStartBinary - Role that a Selenium::Remote::Driver can consume to start a binary

=head1 SYNOPSIS

    package ChromeDriver {
        use Moo;
        with 'Selenium::CanStartBinary';
        extends 'Selenium::Remote::Driver';
        has 'binary' => ( is => 'ro', default => 'chromedriver' );
        has 'binary_port' => ( is => 'ro', default => 9515 );
        1
    };

    my $chrome_via_binary = ChromeDriver->new;

=head1 DESCRIPTION

This role takes care of the details for starting up a Webdriver
instance. It does not do any downloading or installation of any sort -
you're still responsible for obtaining and installing the necessary
binaries into your C<$PATH> for this role to find.

The role determines whether or not it should try to do its own magic
based on whether or not the consuming class is instantiated with a
C<remote_server_addr> and/or C<port>. If they're missing, we assume
the user wants to use the Webdrivers directly and act
accordingly. We'll go find the proper associated binary (or you can
specify it with L</binary_path>), figure out what arguments it wants,
set up any necessary environments, and start up the binary.

There's a number of TODOs left over - namely Windows support is
severely lacking, and we're pretty naive when we attempt to locate the
executables on our own.

In the following documentation, C<required> refers to when you're
consuming the role, not the C<required> when you're instantiating a
class that has already consumed the role.

=attr binary

Required: Specify the path to the executable in question, or the name
of the executable for us to find via L<File::Which/which>.

=cut

requires 'binary';

=attr binary_port

Required: Specify a default port that for the webdriver binary to try
to bind to. If that port is unavailable, we'll probe above that port
until we find a valid one.

=cut

requires 'binary_port';

=attr port

The role will attempt to determine the proper port for us. Consuming
roles should set a default port in L</binary_port> at which we will
begin searching for an open port.

Note that if we cannot locate a suitable L</binary>, port will be set
to 4444 so we can attempt to look for a Selenium server at
C<127.0.0.1:4444>.

=cut

has 'port' => (
    is => 'lazy',
    builder => sub {
        my ($self) = @_;

        if ($self->binary) {
            return find_open_port_above($self->binary_port);
        }
        else {
            return '4444'
        }
    }
);

has 'binary_mode' => (
    is => 'lazy',
    init_arg => undef,
    builder => 1,
    predicate => 1
);

has 'try_binary' => (
    is => 'lazy',
    default => sub { 0 },
    trigger => sub {
        my ($self) = @_;
        $self->binary_mode if $self->try_binary;
    }
);

sub BUILDARGS {
    # There's a bit of finagling to do to since we can't ensure the
    # attribute instantiation order. To decide whether we're going into
    # binary mode, we need the remote_server_addr and port. But, they're
    # both lazy and only instantiated immediately before S:R:D's
    # remote_conn attribute. Once remote_conn is set, we can't change it,
    # so we need the following order:
    #
    #     parent: remote_server_addr, port
    #     role:   binary_mode (aka _build_binary_mode)
    #     parent: remote_conn
    #
    # Since we can't force an order, we introduced try_binary which gets
    # decided during BUILDARGS to tip us off as to whether we should try
    # binary mode or not.
    my ( $class, %args ) = @_;

    if ( ! exists $args{remote_server_addr} && ! exists $args{port} ) {
        $args{try_binary} = 1;

        # Windows may throw a fit about invalid pointers if we try to
        # connect to localhost instead of 127.1
        $args{remote_server_addr} = '127.0.0.1';
    }

    return { %args };
}

sub _build_binary_mode {
    my ($self) = @_;

    my $executable = $self->binary;
    return unless $executable;

    my $port = $self->port;
    return unless $port != 4444;
    if (ref($self) eq 'Selenium::Firefox') {
        setup_firefox_binary_env($port);
    }
    my $command = $self->_construct_command($executable, $port);

    system($command);
    my $success = wait_until { probe_port($port) } timeout => 10;
    if ($success) {
        return 1;
    }
    else {
        die 'Unable to connect to the ' . $executable . ' binary on port ' . $port;
    }
}

sub shutdown_binary {
    my ($self) = @_;

    if ($self->has_binary_mode && $self->binary_mode) {
        my $port = $self->port;
        my $ua = $self->ua;

        $ua->get('127.0.0.1:' . $port . '/wd/hub/shutdown');
    }
}

    my ($self) = @_;

}

sub _construct_command {
    my ($self, $executable, $port) = @_;

    # Handle spaces in executable path names
    $executable = '"' . $executable . '"';

    my %args;
    if ($executable =~ /chromedriver(\.exe)?"$/i) {
        %args = (
            port => $port,
            'url-base' => 'wd/hub'
        );
    }
    elsif ($executable =~ /phantomjs(\.exe)?"$/i) {
        %args = (
            webdriver => '127.0.0.1:' . $port
        );
    }
    elsif ($executable =~ /firefox(-bin|\.exe)"$/i) {
        $executable .= ' -no-remote ';
    }

    my @args = map { '--' . $_ . '=' . $args{$_} } keys %args;

    # Handle Windows vs Unix discrepancies for invoking shell commands
    my ($prefix, $suffix) = ($self->_command_prefix(), $self->_command_suffix());
    return join(' ', ($prefix, $executable, @args, $suffix) );
}

sub _command_prefix {
    my ($self) = @_;

    if ($^O eq 'MSWin32') {
        my $title = ref($self) . ':' . $self->binary_port;
        return 'start "' . $title . '" /MAX '
    }
    else {
        return '';
    }
}

sub _command_suffix {
    # TODO: allow users to specify whether & where they want driver
    # output to go

    if ($^O eq 'MSWin32') {
        return ' > /nul 2>&1 ';
    }
    else {
        return ' > /dev/null 2>&1 &';
    }
}

=head1 SEE ALSO

Selenium::Chrome
Selenium::Firefox
Selenium::PhantomJS

=cut

1;
