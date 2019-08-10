#! /usr/bin/env perl

use 5.020;
use warnings;
use autodie;

use Getopt::Long;
use JSON;
use LWP;

use Toolkit;

my %opts;
if ( !GetOptions( \%opts, 'commit' ) ) {
  die("Invalid incantation\n");
}

main();
exit(0);

sub main {

  my $recId = 2198;
  my $obj = getData(
    "recipi$recId" => "https://xivapi.com/recipe/$recId" );

  my %recipe;
  foreach my $key (keys %{$obj}){
     if( $key =~ /^ItemIngredient(\d+)$/ ){
       my $itemId = $1;
       if( ref($obj->{$key}) ){
         $recipe{$itemId} = $obj->{$key}{'Name'} . '(' .$obj->{"AmountIngredient$itemId"} .")";

         printObject($obj->{"ItemIngredientRecipe$itemId"});
       }
     }
  }

  printObject(\%recipe);


}

sub getData {
  my ( $name, $url ) = @_;

  my $json = JSON->new->allow_nonref();
  my $obj  = undef;
  if ( -f "cache/$name.json" ) {
    open( my $fh, '<', "cache/$name.json" );
    local $/ = undef;
    $obj = $json->decode(<$fh>);
    close($fh);
  } else {
    my $ua   = LWP::UserAgent->new();
    my $req  = HTTP::Request->new( GET => $url );
    my $resp = $ua->request($req);
    if ( $resp->is_success() ) {
      $obj = $json->decode( $resp->decoded_content() );
      open( my $fh, '>', "cache/$name.json" );
      $fh->print( $resp->decoded_content() );
      close($fh);
    } else {
      quick( error => $resp->status_line() );
    }
  }

  return $obj;
}
