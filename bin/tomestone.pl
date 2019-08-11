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
if( !GetOptions( \%opts, 'cache!', 'commit' ) ) {
    die("Invalid incantation\n");
}

main();
exit(0);

sub main {

  my $xivapi = XIVAPI->new(cacheDir => $ENV{'CACHE_DIR'}, cache => $opts{'cache'});

    my %config = (
        'RDM' => { stats => ['Intelligence'], shops => [ 1769972, 1769975 ] },
        'BLM' => { stats => ['Intelligence'], shops => [ 1769972, 1769975 ] },
        'SMN' => { stats => ['Intelligence'], shops => [ 1769972, 1769975 ] },
    );

    my $obj = $xivapi->getApiData('https://xivapi.com/character/10001355?extended=1' => 'abacab' );
    message(
        "Current Class: '$obj->{'Character'}{'ActiveClassJob'}{'Job'}{'Name'}'"
    );
    my $job  = $obj->{'Character'}{'ActiveClassJob'}{'Job'}{'Abbreviation'};
    my $gear = $obj->{'Character'}{'GearSet'}{'Gear'};

    foreach my $shop ( @{ $config{$job}{'shops'} } ) {
        $obj = $xivapi->getApiData( "https://xivapi.com/specialshop/$shop" => "specialshop$shop" );

        my %shop;
        my %slotMap;
        foreach my $key ( sort keys %{$obj} ) {
            next unless( $key =~ /([a-zA-Z]+)(\d+)$/ );
            my $name       = $1;
            my $internalId = $2;

            if( $name eq 'ItemCost' ) {
                $shop{$internalId}{$name} = $obj->{$key}{'Name'};
            }

            if( $name eq 'CountCost' ) {
                $shop{$internalId}{$name} = $obj->{$key};
            }

            if( $name eq 'ItemReceive' ) {
                my $itemId = $obj->{$key}{'ID'};
                if( defined($itemId) ) {
                    $shop{$internalId}{$name} = $obj->{$key}{'Name'};
                    $shop{$internalId}{'ItemId'} = $itemId;
                    $shop{$internalId}{'ItemSlot'}
                        = $obj->{$key}{'EquipSlotCategoryTargetID'};
                    my $item
                        = $xivapi->getApiData("https://xivapi.com/item/$itemId" => "item$itemId" );
                    $shop{$internalId}{'ItemStats'} = $item->{'Stats'};

                    if( $item->{'ClassJobCategory'}{$job} == 1 ) {
                        $slotMap{ $obj->{$key}{'EquipSlotCategoryTargetID'} }
                            = $internalId;
                    }
                }
            }
        }

        my @table;
        foreach my $key ( keys %{$gear} ) {
            next if( $key eq 'SoulCrystal' );
            my $itemRef = $gear->{$key}{'Item'};
            my $itemId  = $itemRef->{'ID'};
            my $rarity  = $itemRef->{'Rarity'};

            my @row = ( $key, $itemId, $itemRef->{'Name'} );

            my $item
                = $xivapi->getApiData( "https://xivapi.com/item/$itemId" => "item$itemId"  );
            my $slot = $item->{'EquipSlotCategoryTargetID'};

            next unless exists( $slotMap{$slot} );

            my $piece = $shop{ $slotMap{$slot} };
            foreach my $stat ( @{ $config{$job}{stats} } ) {
                my $value = 0;
                if( $rarity == 1 ) {
                    $value = $item->{'Stats'}{$stat}{'HQ'};
                } else {
                    $value = $item->{'Stats'}{$stat}{'NQ'};
                }

                my $target = $piece->{'ItemStats'}{$stat}{'NQ'};
                my $delta  = $target - $value;
                my $rate
                    = $delta != 0
                    ? sprintf( '%.02f', $piece->{'CountCost'} / $delta )
                    : 0;

                push( @row, $value, $delta, $rate );
            }
            push( @row, $piece->{'ItemReceive'}, $piece->{'CountCost'} );
            foreach my $stat ( @{ $config{$job}{stats} } ) {
                my $value = $piece->{'ItemStats'}{$stat}{'NQ'};
                push( @row, $value );
            }

            push( @table, \@row );
        }

        message( $obj->{'Name'} );
        @table = sort {
            return 1                   if( $a->[5] <= 0 && $b->[5] > 0 );
            return -1                  if( $b->[5] <= 0 && $a->[5] > 0 );
            return $b->[5] <=> $a->[5] if( $a->[5] <= 0 && $b->[5] <= 0 );
            $a->[5] <=> $b->[5];
        } @table;

        foreach my $row (@table) {
            if( $row->[5] <= 0 ) {
                $_ = green($_) foreach @{$row};
            }
        }

        dump_table(
            table => [
                [   qw( slot name id ), @{ $config{$job}{stats} }, 'delta',
                    'rate', 'item', 'cost', 'value'
                ],
                @table
            ]
        );
    }

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

