package ThinObject;

use 5.00;
use strict;
use warnings;

our $VERSION = '0.02';

use constant LIB => ( $ENV{HOME} . '/lib', '/usr/local/lib', '/usr/lib' );
use constant ROOT => qw( tob thinob ThinObject );

my @libroot; # list of all possible valid class library path roots
foreach my $lib ( LIB ) {
    foreach my $root ( ROOT ) {
        push @libroot, "$lib/$root";
        }
    }
my $libroot_pattern = '^(' . join('|', @libroot) . ')/';

sub confirm_class { # NOT a method...
    my $class_path = shift; # absolute path, i.e., /libroot/class/path
    my $fatal = shift;
    $class_path =~ tr{/}{/}s; # squeeze any // to / in path
    unless ( $class_path =~ s{$libroot_pattern}{} ) {
        die "INVALID CLASS PATH: $class_path\n" if $fatal;
        warn "INVALID CLASS PATH: $class_path\n";
        return undef;
        }
    return $class_path; # NOTE: libroot has been removed
    }

sub new {
    my $class = shift;
    my $self = {};
    $self->{ob} = $self->{tob} = shift or die "no object specified\n";
    if ( -d $self->{tob} && -e $self->{tob} . '/^' ) { # it's a thinobject
        } 
    else {
        $self->{tob} = _deref_symlink($self->{tob}) if -l $self->{tob};
        $self->{tob} =~ s{([^/]+)$}{.$1}; # dot the object...
        }
    bless $self, $class;
    return undef unless $self->exists(); # not a thinobject
  # die qq(object "$self->{ob}" not found\n) unless $self->exists();
    ## _scandir() sets the following parameters:
    $self->{param} = {};
    $self->{method} = {};
    $self->{listing} = []; # hidden directory listing
    $self->{scanned} = []; # list of directories scanned
  # $self->_scandir($self->{tob}); # recurse for parameters
    return $self;
    }

sub _deref_symlink { # call readlink() recursively...
    ## note that this is not an object method, just an ordinary function
    my $f = shift or die;
    my $count = 0;
    while ( -l $f ) {
        my ($path) = $f =~ m{^(.*/)};
        $f = readlink $f;
        next if $f =~ m{^/}; # absolute path
        $f = $path . $f;     # relative path
        }
    ## simplify /x/y/../foo to /x/foo
    # ... NOTE: note sure why s///g didn't work in the following subst:
    $f =~ s{[^/]+/+\.{2}/}{} while $f =~ m{\.{2}};    return $f;
    }

sub print_debug { 
    my $self = shift;
    print "DEBUG:",
        "\tob:", $self->{ob}, "\t", $self->ob_type(), "\n",
        "\ttob:", $self->{tob}, "\t", $self->tob_type(), "\n",
        ;
    print "\thash method: $_\n" foreach keys %{$self->{AUTO_HASH}};
    print "\tlist method: $_\n" foreach keys %{$self->{AUTO_LIST}};
    }

sub rescan { # force _scandir() to be called again on next need...
    my $self = shift;
    $self->{scanned} = undef;
    }

sub _scandir { # recursively scan object, class directories
    my $self = shift;
    my $dir = shift;
    push @{$self->{scanned}}, $dir;
    return undef unless -d $dir; # shouldn't happen?
    ## first, scan for tag=value files...
    unless ( opendir DIR, $dir ) {
        warn qq(unable to open directory "$dir"\n);
        return undef; # should handle this better...
        }
  # print "\nDEBUG open directory $dir!\n";
    push @{$self->{listing}}, []; # array ref for contents
    while ( my $file = readdir DIR ) {
        next if $file =~ m/^\.{1,2}$/; # ignore . and ..
      # print "DEBUG testing file $file...?\n";
        if ( -d "$dir/$file" ) {
            next if $file =~ m/^\.\.?$/; # ignore . and ..
          # print "DEBUG: pushing directory $file/\n";
            push @{$self->{listing}->[-1]}, $file . '/';
            next; # skip directories for now, recurse later...
            }
      # print "DEBUG: pushing file $file\n";
        push @{$self->{listing}->[-1]}, $file;
        if ( my ($tag, $value) = $file =~ m/^([^=]+)=([^=]+)$/ ) {
            ## first-encountered parameters rule:
            $self->{param}->{$tag} = $value
                unless exists $self->{param}->{$tag};
            }
      # if ( -x "$dir/$file" && $dir =~ m{(ISA|SUPER)$} ) { # method?
        if ( -x "$dir/$file" && $dir =~ m{\^$} ) { # method?
            my $method = $file;
            while ( exists $self->{method}->{$method} ) {
                $method = "SUPER::$method";
                }
            my $path = "$dir/$file"; # strip out the tob path... (kludgish...)
            $path =~ s|^$self->{tob}/||;
            $self->{method}->{$method} = $path;
            }

      # ## not sure about these auto-generated methods, so I commented them out
      # elsif ( my ($type, $method) = $file =~ m/^([@%])(.+)/ ) {
      #     $self->{AUTO_HASH}->{$method} = \&hash if $type eq '%';
      #     $self->{AUTO_LIST}->{$method} = \&list if $type eq '@';
      #     }
        }
    closedir DIR;
    ## next, check for default parameter file '%' ...
    if ( -e $dir . '/%' ) { # read default properties file
        unless ( open PARAMS, '<', $dir . '/%' ) {
            warn qq(failed to open parameter file "$dir/\%"\n);
            }
        else {
            while ( <PARAMS> ) {
                chomp;
                next if m/^\s*$/ || m/^\s*#/; # skip blank and comment lines
                if ( my ( $tag, $value ) = m/^\s*(\S+)\s*=\s*(\S.*)/ ) {
                    $self->{param}->{$tag} = $value
                        unless exists $self->{param}->{$tag};
                    }
                else {
                    warn qq(unknown entry "$_" in $dir/\%\n);
                    }
                }
            }
        close PARAMS;
        }
    ## last, recurse into class or superclass directories
  # print "DEBUG: recursing into $dir/^/...\n";
    if ( -e $dir . '/^' ) {
        $self->_scandir( $dir . '/^' );
        }
  # print "DEBUG: ... done recursing\n";
    }

sub method { # list all methods, or execute(?) a given method
    my $self = shift;
    my $m = shift;
    $self->_scandir($self->{tob}) unless @{$self->{scanned}};
    return $self->show_methods() unless defined $m;
    return undef unless exists $self->{method}->{$m};
    return $self->{method}->{$m};
    }

sub show_methods { # list all methods
    my $self = shift;
    return ( sort keys %{$self->{method}} );
    }

sub param { # access to object parameters
    my $self = shift;
    $self->_scandir($self->{tob}) unless @{$self->{scanned}};
    my $tag = shift; 
    return ( keys %{$self->{param}} ) unless defined $tag;
    my $value = shift; # override or define tag value
    if ( defined $value ) {
        $self->{param}->{$tag} = $value;
        ## QUESTION: should this new value be made persistent??
        ## for now I'm not doing that...
        }
    return $self->{param}->{$tag};
    }

sub listing { # return list of properties from object or class
    my $self = shift;
    $self->_scandir($self->{tob}) unless @{$self->{scanned}};
    my $property = shift; 
    return sort @{$self->{listing}->[0]} unless defined $property;
    ## property should match a class in the object's hierarchy
    # first find the class "level":
    my $i = 0;
  # print "DEBUG: classes: ", join ', ', @{$self->{isa}}, "\n";
  # print "DEBUG: test $i > ", scalar $#{$self->{isa}}, " ???\n";
  # print "DEBUG: test $self->{isa}->[$i] eq $property ???\n";
    until ( $i > $#{$self->{isa}} || $self->{isa}->[$i] eq $property ) {
      # print "DEBUG: $i = $self->{isa}->[$i]\n";
        $i++;
        }
  # print "DEBUG: index = $i after search\n";
    return undef if $i > @{$self->{isa}};
  # print "DEBUG: contents of $self->{isa}->[$i]:\n";
    return sort @{$self->{listing}->[++$i]};
    return undef;
    }

sub listfiles { # use readdir to scan the object files
    my $self = shift;
    my $dir = shift || '.';
    opendir DIR, $self->tob() . '/' .$dir or die $!;
    my @files;
    foreach ( readdir DIR ) {
        next if m/^\./; # skip dot-files or directories
        push @files, $_;
        }
    return @files;
    }

sub AUTOLOAD {
    my $self = shift;
    my $method = $ThinObject::AUTOLOAD;
    $method =~ s/^\S+:://; # lose the package prefix 
    if ( exists $self->{AUTO_LIST}->{"$method"} ) {
        # NOTE: calling as a function, but providing $self as if a method call...
        return $self->{AUTO_LIST}->{$method}($self, '@'.$method, @_);
        }
    if ( exists $self->{AUTO_HASH}->{"$method"} ) {
        return $self->{AUTO_HASH}->{$method}($self, '%'.$method, @_);
        }
    }

sub hash { # return hash of tag=value entries (lines) from a property (file)
    my $self = shift;
    my $property = shift;
  # print "DEBUG hash($property) in $self->{tob}\n";
    open HASH, "<", $self->{tob} . "/$property" or die $!; # return undef;
    my %hash;
    while ( <HASH> ) {
        chomp;
        next if m/^\s*$/;
        my ( $tag, $value ) = m/^\s*(\S+)\s*=\s*(\S.*)/;
        $hash{$tag} = $value;
        }
    my $key = shift;
    return sort keys %hash unless defined $key;
  # return \%hash unless defined $key;
    return $hash{$key};
    }

sub list { # return list of entries (lines) from a selected property (file)
    my $self = shift;
    my $property = shift;
  # print "DEBUG list($property) in $self->{tob}\n";
    open LIST, "<", $self->{tob} . "/$property" or return undef;
    my @list;
    while ( <LIST> ) {
        chomp;
        next if m/^\s*$/;
        push @list, $_;
        }
    return \@list;
    }

sub get_property { # read the value of a file named with leading '@'
    my $self = shift;
    my $prop = shift; # argument w/o the '@'
    return $self->list_properties() unless defined $prop;
    open PROP, "<", $self->{tob} . "/\@$prop" or return undef;
    chomp ( my @value = <PROP> );
    return @value;
    }

sub set_property { # write the value of a file
    my $self = shift;
    my $prop = shift;
    my @value = @_;
    open PROP, ">", $self->{tob} . "/\@$prop" or return undef;
    return undef unless @value;
    foreach ( @value ) {
        print PROP "$_\n";
        }
    return 1;
    }

sub list_properties { # read the value of a file named with leading '@'
    my $self = shift;
    $self->_scandir($self->{tob}) unless @{$self->{scanned}};
    my @props;
    foreach my $d ( @{$self->{listing}} ) {
        foreach my $f ( @$d ) {
            push @props, $f if $f =~ s/^\@//;
            }
        }
    return @props;
    }

sub exists { 
    my $self = shift;
    return -e $self->{ob} && -e $self->{tob} && -e $self->{tob} . '/^';
    }

sub ob_type { 
    my $self = shift;
    return 'FILE' if -f $self->{ob};
    return 'DIRECTORY' if -d $self->{ob};
    }

sub tob_type { 
    my $self = shift;
    return 'FILE' if -f $self->{tob};
    return 'DIRECTORY' if -d $self->{tob};
    }

sub name { 
    my $self = shift;
    return $self->{ob};
    }

sub tob { 
    my $self = shift;
    return $self->{tob};
    }

sub isa { 
    my $self = shift;
    return @{$self->{isa}} if defined $self->{isa};
    my $isa = "$self->{tob}/^";
    return 'ThinObject' unless -e $isa;
    return 'unknown' unless -l $isa;
    my $class = _deref_symlink($isa);
  # my $libroot = LIBROOT;
  # warn "INVALID CLASS\n" unless $isa =~ s{$libroot_check_pattern}{};
  # warn "INVALID CLASS\n" unless $isa = confirm_class($isa);
    $isa = confirm_class($class);
    $self->{isa} = [ $isa ];
    $class .= '/^';
    while ( -e $class ) {
        unless ( -l $class && -d $class ) {
            warn qq(INVALID SUPERCLASS "$class"\n);
            last;
            }
        $class = _deref_symlink($class);
        $isa = confirm_class($class);
      # warn qq(INVALID CLASS "$isa"\n) unless $isa =~ s{$libroot}{};
        push @{$self->{isa}}, $isa;
        $class .= '/^';
        }
    return @{$self->{isa}};
    }

sub ls { # wrap the shell command ls
    my $self = shift;
    my @args = @_;
    my $result = `ls @args $self->{tob}`;
    chomp $result;
    return $result;
    }

sub find { # wrap the shell command find
    my $self = shift;
    my @args = @_;
    foreach ( @args ) {
        die "find(@args): -exec option not allowed\n" if m/exec/;
        }
    my $result = `find $self->{tob} @args`;
    chomp $result;
    return $result;
  # return `(cd $self->{tob}; find)`;
    }

sub OLD_init_param { # read params from class & object "%<method>" file
    my $self = shift;
    my ($method_classdir, $method) = $0 =~ m{(.+)/([^/]+)};

    my $method_class = readlink $method_classdir;
  # my $libroot = LIBROOT;
  # warn "INVALID CLASS\n" unless $method_class =~ s{$libroot}{};
    $method_class = confirm_class($method_class);
    $method_class =~ s{/}{::}g; # change class foo/bar to foo::bar

    $self->{option} = {};

    # look for class and method params, first in class, then in object:
    foreach my $hashfile (
        $method_classdir . '/%' . $method_class,
        $method_classdir . '/%' . $method,
        $self->{tob} . '/%' . $method_class,
        $self->{tob} . '/%' . $method,
        ) {
        next unless -e $hashfile;
        unless ( open PARAMS, "<", $hashfile ) {
            warn "init_params(): error opening $hashfile, $!\n";
            next;
            }
        while ( <PARAMS> ) {
            chomp;
            next if m/^\s*$/; # skip blank lines
            my ( $tag, $value ) = m/^\s*(\S+)\s*=\s*(\S.*)/;
            $self->{option}->{$tag} = $value;
            }
        close PARAMS;
        }
    }

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

ThinObject - Perl extension for the ThinObject system of persistent objects.

=head1 SYNOPSIS

  use ThinObject;
  my $tob = ThinObject->new("path/object");
  print $tob->ls;

=head1 DESCRIPTION

ThinObject is a scheme, a set of conventions, to realize object oriented 
behaviors on the linux filesystem.  An object is an ordinary file or 
directory with a so-named hidden dot-file (or directory) storing key 
object data.

This ThinObject module provides a base object for perl programs, including
some simple methods.

=head1 METHODS

=over

=item new(PATHNAME)

create a new object instance in memory, given the pathname of an existing 
object

=item print_debug()

print debug string showing base object properties

=item exists()

return true if object exists, or false

=item ob_type()

return object type, FILE or DIRECTORY

=item tob_type()

return dot-object type, FILE or DIRECTORY

=item name()

return object name

=item path()

return object path

=item list(PROPERTY)

return list of entries from property (file) 

TODO: support list( PROPERTY, n), where n identifies the nth entry (1 being
the first entry), but also a range or list using n..m or n,m,p,q,...

=item hash(PROPERTY)

return hash reference of key=value entries from property (file) 

TODO: support hash(PROPERTY, key ) and hash(PROPERTY, key=value)

=item method_option()

=item method_option(KEY)

=item method_option(KEY, VALUE)

Reads hash values from class and option properties with the method name
following the "%" character.  The first form returns all keys in the
hash; the second returns the value of the given key; the last sets the
key value and returns it.


=item auto-generated methods

If a property/file name begins with "%" or "@", the hash() or list() method
is called by using the name (with the leading "type" character) directly.

=item ls(OPTIONS)

wrap shell C<ls> with options

=item find(OPTIONS)

wrap shell C<find> with options.  Option -exec is not allowed.

=back

=head1 TODO

=over

=item has(), or hasa()

return list of contained objects, as TYPE NAME

=item has(TYPE), or hasa(TYPE)

return list of contained objects of specified TYPE

=back

=head1 SEE ALSO

If you have a mailing list set up for your module, mention it here.

http://www.thinobject.org MIGHT be set up as a place to store, discuss,
and maintain this system.

=head1 AUTHOR

Ken Irving, E<lt>fnkci@uaf.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ken Irving

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


cut
