#! /usr/bin/env perl

use 5.020;
use warnings;
use autodie;

use Cwd qw( abs_path );
use File::Basename;
use Getopt::Long;
use LWP;
use JSON;

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

my %opts = (
    'lodestone' => 10001355,
    'cache'     => 1
);
if( !GetOptions(
        \%opts, 'job=s', 'lodestone=i', 'cache!', 'commit', 'verbose'
    )
    ) {
    die("Invalid incantation\n");
}

my $json = JSON->new->allow_nonref();
my %config = %{$json->decode(join('', <DATA>))};

main();
exit(0);

sub main {

    my $xivapi = XIVAPI->new(
        host     => 'https://xivapi.com',
        cacheDir => $ENV{'CACHE_DIR'},
        cache    => $opts{'cache'},
        verbose  => $opts{'verbose'},
    );

    my $obj = getCharacterSheet( $xivapi, \%config );

    message(
        "Current Class: '$obj->{'Character'}{'ActiveClassJob'}{'Job'}{'Name'}'"
    );

    my $job  = $obj->{'Character'}{'ActiveClassJob'}{'Job'}{'Abbreviation'};
    my $gear = $obj->{'Character'}{'GearSet'}{'Gear'};

    foreach my $shop ( @{ $config{$job}{'shops'} } ) {
        $obj = $xivapi->specialshop($shop);

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
                    my $item = $xivapi->item($itemId);
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
#            printObject($gear->{$key});
            my $itemRef = $gear->{$key}{'Item'};
            my $itemId  = $itemRef->{'ID'};
            my $ilvl = $itemRef->{'LevelItem'};
            my $rarity  = $itemRef->{'Rarity'};
            #            printObject($itemRef);

            my @row = ( $key, $ilvl, $itemRef->{'Name'} );

            my $item = $xivapi->item($itemId);
            my $slot = $item->{'EquipSlotCategoryTargetID'};

            next unless exists( $slotMap{$slot} );

            my $piece    = $shop{ $slotMap{$slot} };
            my $useValue = undef;
            my $useStat  = undef;
            foreach my $stat ( @{ $config{$job}{stats} } ) {
                if( !defined($useValue) ) {
                    $useStat = $stat;
                    if( $rarity == 1 ) {
                        $useValue = $item->{'Stats'}{$stat}{'HQ'};
                    } else {
                        $useValue = $item->{'Stats'}{$stat}{'NQ'};
                    }
                }

            }
            my $target = $piece->{'ItemStats'}{$useStat}{'NQ'} || 0;
            my $delta  = $target - $useValue;
            my $rate
                = $delta != 0
                ? sprintf( '%.02f', $piece->{'CountCost'} / $delta )
                : 0;

            push( @row, $useValue, $delta, $rate );

            push( @row, $piece->{'ItemReceive'}, $piece->{'CountCost'} );
            #            foreach my $stat ( @{ $config{$job}{stats} } ) {
            my $value = $piece->{'ItemStats'}{$useStat}{'NQ'};
            push( @row, $value );
            #            }

            push( @table, \@row );
        }

        message( $obj->{'Name'} );
        @table = sort {
            return 1                   if( $a->[5] <= 0 && $b->[5] > 0 );
            return -1                  if( $b->[5] <= 0 && $a->[5] > 0 );
            return $b->[5] <=> $a->[5] if( $a->[5] <= 0 && $b->[5] <= 0 );
            $a->[5] <=> $b->[5];
        } @table;

        my $need = 0;
        my $cost = 0;
        foreach my $row (@table) {
            if( $row->[5] <= 0 ) {
                $_ = green($_) foreach @{$row};
            } else {
                $need++;
                $cost += $row->[7];
            }
        }

        if( $need > 0 ) {
            dump_table(
                table => [
                    [qw( slot ilvl name current delta rate item cost value )],
                    @table
                ]
            );
            say("$need items to purchace");
            say("$cost total tomestones");
        }
    }

}

sub getCharacterSheet {
    my ( $api, $config ) = @_;

    my $retval = undef;
    my $job    = exists($opts{'job'}) ? uc( $opts{'job'} ) : undef;
    if($job) {
        $retval = $api->cached("character.$opts{'lodestone'}.$job");
        if($retval) {
            message("Using last known $job gearset");
        } else {
            message("Unknown gearset for $job");
            exit(0);
        }
    } else {
        my $current = $api->character( $opts{'lodestone'} );
        $job = $current->{'Character'}{'ActiveClassJob'}{'Job'}
            {'Abbreviation'};
        $retval = $api->character(
            $opts{'lodestone'} => "character.$opts{'lodestone'}.$job" );
    }
    return $retval;
}

__DATA__
{"DRK":{"stats":["Tenacity"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"AST":{"shops":[1769534,1769651,1769733,1769851,1769908,1770052,1770320,1770435,1770438],"stats":["Piety"]},"PLD":{"stats":["Tenacity"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"WHM":{"stats":["Piety"],"shops":[1769534,1769651,1769733,1769851,1769908,1770052,1770320,1770435,1770438]},"MCH":{"stats":["Dexterity"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"SMN":{"shops":[1769534,1769651,1769733,1769851,1769908,1770052,1770320,1770435,1770438],"stats":["Intelligence"]},"GNB":{"stats":["Tenacity"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"DRG":{"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437],"stats":["Strength","Critical Hit"]},"SGE":{"shops":[1769534,1769651,1769733,1769851,1769908,1770052,1770320,1770435,1770438],"stats":["Piety"]},"BLM":{"shops":[1769534,1769651,1769733,1769851,1769908,1770052,1770320,1770435,1770438],"stats":["Intelligence"]},"MNK":{"stats":["Strength","Critical Hit"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"DNC":{"stats":["Dexterity"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"RDM":{"stats":["Intelligence"],"shops":[1769534,1769651,1769733,1769851,1769908,1770052,1770320,1770435,1770438]},"WAR":{"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437],"stats":["Tenacity"]},"BRD":{"stats":["Dexterity"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"SAM":{"stats":["Strength","Critical Hit"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]},"SCH":{"shops":[1769534,1769651,1769733,1769851,1769908,1770052,1770320,1770435,1770438],"stats":["Piety"]},"NIN":{"stats":["Strength","Critical Hit"],"shops":[1769533,1769649,1769732,1769850,1769907,1770051,1770319,1770434,1770437]}}
