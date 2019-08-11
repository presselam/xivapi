#! /usr/bin/env perl

use 5.020;
use warnings;
use autodie;

use Cwd qw( abs_path );
use File::Basename;
use Getopt::Long;
use JSON;
use LWP;

use Toolkit;

BEGIN {
    $ENV{'BIN_DIR'}   = dirname( abs_path($0) );
    $ENV{'APP_DIR'}   = dirname( $ENV{'BIN_DIR'} );
    $ENV{'LIB_DIR'}   = "$ENV{'APP_DIR'}/lib";
    $ENV{'CACHE_DIR'} = "$ENV{'APP_DIR'}/cache";
    if( !-d $ENV{'CACHE_DIR'} ) {
        mkdir( $ENV{'CACHE_DIR'} );
    }
}
use lib $ENV{'LIB_DIR'};
use XIVAPI;

my %opts = ( 'cache' => 1 );
if( !GetOptions( \%opts, 'cache!', 'item=s@' ) ) {
    die("Invalid incantation\n");
}

main();
exit(0);

sub main {

  printObject(\%opts);
  my @items = sort keys %{{map{ lc($_) => undef} @{$opts{'item'}}}};

  my $xivapi = XIVAPI->new(cacheDir => $ENV{'CACHE_DIR'}, cache => $opts{'cache'});
  my $obj = $xivapi->search('recipe' => {NameCombined_en => \@items} => 'search1');
  printObject($obj->{'Results'});

}
  

__END__

=head1 NAME

quick.pl - [description here]

=head1 VERSION

This documentation refers to quick.pl version 0.0.1

=head1 USAGE

    quick.pl [options]

=head1 REQUIRED ARGUMENTS

=over

None

=back

=head1 OPTIONS

=over

None

=back

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Requires no configuration files or environment variables.


=head1 DEPENDENCIES

None.


=head1 BUGS

None reported.
Bug reports and other feedback are most welcome.


=head1 AUTHOR

Andrew Pressel C<< apressel@nextgenfed.com >>


=head1 COPYRIGHT

Copyright (c) 2019, Andrew Pressel C<< <apressel@nextgenfed.com> >>. All rights reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License
(see http://www.perl.com/perl/misc/Artistic.html)


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

