package Selenium::Remote::Driver::ActionChains; 
# ABSTRACT: Action chains for Selenium::Remote::Driver
use Moo; 

has 'driver' => ( 
    is => 'ro', 
);

has 'actions' => ( 
    is => 'lazy', 
    builder => sub { [] },
);

sub perform { 
    my $self = shift; 
    foreach my $action (@{$self->actions}) { 
        $action->();
    }
}

sub click { 
    my $self = shift; 
    my $element = shift; 
    if ($element) { 
       $self->move_to_element($element); 
    }
    # left click
    push @{$self->actions}, sub { $self->driver->click(0) };
    $self; 
}

sub click_and_hold { 
    my $self = shift; 
    my $element = shift; 
    if ($element) { 
       $self->move_to_element($element); 
    }
    push @{$self->actions}, sub { $self->driver->button_down };
    $self; 
}

sub context_click { 
    my $self = shift; 
    my $element = shift; 
    if ($element) { 
       $self->move_to_element($element); 
    }
    # right click
    push @{$self->actions}, sub { $self->driver->click(2) }; 
    $self; 
}


sub double_click { 
    my $self = shift; 
    my $element = shift; 
    if ($element) { 
       $self->move_to_element($element); 
    }
    push @{$self->actions}, sub { $self->driver->double_click };
    $self; 
}

sub release { 
    my $self = shift; 
    my $element = shift; 
    if ($element) { 
       $self->move_to_element($element); 
    }
    push @{$self->actions}, sub { $self->driver->button_up };
    $self; 
}

sub drag_and_drop { 
    my $self = shift; 
    my ($source,$target) = @_;
    $self->click_and_hold($source);
    $self->release($target);
    $self; 
}

sub move_to_element {
    my $self    = shift;
    my $element = shift;
    push @{ $self->actions },
      sub { $self->driver->move_to( element => $element ) };
    $self;
}


1;
