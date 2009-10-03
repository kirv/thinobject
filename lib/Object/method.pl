#!/usr/bin/perl -w
use strict;
use ThinObject;
my $ob = shift;
my $method = shift;
$ob = ThinObject->new($ob);
if ( defined $method ) {
    my @value = $ob->method($method);
    exit unless @value;
    print "$_\n" foreach @value;
    }
else {
    foreach $method ( $ob->method() ) {
        print "$method\n";
        }
    }
