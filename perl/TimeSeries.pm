package TimeSeries;

use Exporter 'import';
@EXPORT = qw(
    encode
    encode_pad
    decode
    encode_filename decode_filename
    encode_chunkname
    itag_to_interval_seconds
    tz_hhmm2sec
    checkdir
    ASSERT
    time_to_year_ysec
    );

use Time::Local qw(timegm);

package TimeSeries::Base32;

my @code = ( 0..9, 'a'..'h', 'j', 'k', 'm', 'n', 'p'..'t', 'v'..'z'); 
my %decode;
my $i = 0;
$decode{$_} = $i++ foreach @code;

sub encode { # encode number into base-32 character string
    my $n = shift;
    my $b32 = '';
    while ( $n > 0 ) {
        $b32 = $code[ $n % 32 ] . $b32;
        $n = int( $n / 32 );
        }
    return $b32;
    }

sub decode { # return unencoded value
    my $b32 = shift;
    my $n = 0;
    $n = $n * 32 + $decode{$_} foreach split '', $b32;
    return $n;
    }

package TimeSeries;

sub encode { TimeSeries::Base32::encode( $_[0] ) }
sub decode { TimeSeries::Base32::decode( $_[0] ) }

sub encode_pad { # pad encoded string with 0 to specified width
    my $n = shift; # number
    my $w = shift; # width 
    return sprintf "%0${w}s", encode($n);
    }

## special functions for the TimeSeries application:

sub encode_filename {
    my $year = shift;
    my $from = shift;
    my $to = shift;
    my $suffix = shift;
    my $fname = $year;
    if ( $to ) {
        $fname .= sprintf "-%05s-%05s", encode($from), encode($to);
        }
    else {
        $fname .= sprintf "-%05s", encode($from);
        }
    $fname .= sprintf "-%05s", encode($to) if $to;
    $fname .= "-$suffix" if defined $suffix;
    return $fname;
    }

sub decode_filename {
    my $fname = shift;
    my ($year, $from, $to, $suffix, $intoffset) = split /-/, $fname;
    $suffix .= '-' . $intoffset if defined $intoffset;
    return $year, decode($from), decode($to), $suffix;
    }

sub encode_chunkname { ## returns chunkname as list of elements
    my $year32 = encode(shift);
    my $ysec32 = sprintf "%05s", encode(shift);
    my %opt = @_;
    my @chunk;
    if ( $opt{prefix} ) { # note: prefix is assumed to include trailing '-'
        $opt{prefix} = $opt{prefix} . '-' . $opt{suffix} if $opt{suffix};
        push @chunk, $opt{prefix};
        }
    elsif ( $opt{suffix} ) {
        push @chunk, $opt{suffix};
        }
    push @chunk, $year32 . substr $ysec32, 0, 1;
    push @chunk, substr $ysec32, 1;
    ## note that a 'chunkroot' is NOT provided here; the client should add it
    return @chunk;
    }

sub tz_hhmm2sec { ## translate timezone offset to seconds...
    my $tz = shift || 0;
    if ( $tz =~ m/^(-)?(\d\d)(\d\d)$/ ) {
        $tz = $2 + $3/60;
        $tz = -$tz if defined $1;
        }
    return $tz * 3600;
    }

sub itag_to_interval_seconds {
    my $itag = shift;  # 1h, 1h-0s

    ## now break down the interval and offset values to seconds...
    my ($interval, $iunit, undef, $offset, $ounit) =
        $itag =~ m/^(\d+)([smhdwty])(-(-?\d+)([smhdwty]))?/;
    
    my $time_units = { # factor to convert to seconds
            s => 1,
            m => 60,   # seconds in a minute
            h => 3600,  # ... hour
            d => 86400,  # ... day
            w => 604800,  # ... week
            t => 2592000,  # ... month... really 30 days
            y => 31536000,  # ... year... really 365 days
            };
    $interval *= $time_units->{$iunit};
    $offset *= $time_units->{$ounit} if defined $offset;
    
  # print "DEBUG interval: $interval\n";
  # print "DEBUG offset: $offset\n" if defined $offset;
    return $interval, $offset;
    }

sub checkdir { # check a directory, mkdir if necessary
    my @path = @_;
    unless ( -d join '/', @path ) {
        checkdir(@path[ 0..-2 ]); # recursively check parent directory...
        ## ASSERT: parent dir exists
        mkdir join('/', @path) or die "failed to mkdir " . join('/', @path);
        }
    ## ASSERT: the directory path exists
    }

sub ASSERT { # 
    my $truth = shift;
    my $msg = shift;
    die qq(failed assertion: $msg\n) unless $truth;
    }

sub time_to_year_ysec { ## derive year and seconds-into-year from time
    my $time = shift; # time in unix epoch seconds
    my $year = (gmtime($time))[5] + 1900;
    my $ysec = $time - timegm(0,0,0,1,0,$year); # seconds into year
    return ($year, $ysec);
    }

1;

