package XIVAPI;

use 5.020;
use warnings;
use strict;

use version;
our $VERSION = qv('0.0.3');

our $AUTOLOAD;

use LWP;
use URL::Encode qw( url_encode );

use Toolkit;

sub new {
    my ($class) = shift;
    my $self = {@_};

    my %known = map { $_ => undef } qw( host cache cacheDir verbose );
    for my $key ( keys %{$self} ) {
        die( __PACKAGE__ . ": unknown parameter: [$key]" )
            unless( exists( $known{$key} ) );
    }

    $self->{'_ua'} = LWP::UserAgent->new( agent => 'presselam' );
    $self->{'_json'} = JSON->new->allow_nonref();

    return bless( $self, $class );
}

sub AUTOLOAD{
  my ($self, $id, $cacheName) = @_;
  return if( $AUTOLOAD eq 'XIVAPI::DESTROY');

  my ($name) = $AUTOLOAD =~ /::(.+)$/;
  $name = lc($name);
  my %check = map{lc($_) => undef} @{$self->content()};
  if( !exists($check{$name}) ){
    die("Cannot locate object method '$name' via package ".__PACKAGE__);
  }

  my $endpoint = $name;
  $endpoint .= "/$id" if( defined($id) );

  $cacheName = "$name.$id" unless( $cacheName );
  return $self->_getApiData($endpoint => $cacheName);
}

sub character{
  my ($self, $id, $cacheName) = @_;

  my $name = 'character';
  my $endpoint = $name;
  $endpoint .= "/$id?extended=1&data=cj" if( defined($id) );

  $cacheName = "$name.$id" unless( $cacheName );
  return $self->_getApiData($endpoint);
}

sub content{
  my ($self) = @_;

  if( !exists($self->{'indexes'}) ){
    my $obj = $self->getApiData("$self->{'host'}/content" => 'content');
    $self->{'indexes'} = $obj;
  }

  return $self->{'indexes'};
}

sub esQuery {
  my ( $self, $index, $query, $cacheName ) = @_;

    $cacheName = undef unless( $self->{'cache'} );

    my $retval = undef;
    if( defined($cacheName) && -f "$self->{'cacheDir'}/$cacheName.json" ) {
        open( my $fh, '<', "$self->{'cacheDir'}/$cacheName.json" );
        local $/ = undef;
        $retval = $self->{'_json'}->decode(<$fh>);
        close($fh);
    } else {
        $retval = $self->_query( $index, $query );
        open( my $fh, '>', "$self->{'cacheDir'}/$cacheName.json" );
        $fh->print( $self->{'_json'}->encode($retval) );
        close($fh);
    }
    return $retval;
}

sub _query {
    my ( $self, $index, $query ) = @_;

    my @terms;
    foreach my $field ( keys %{$query} ) {
        foreach my $item ( @{ $query->{$field} } ) {
            push( @terms, qq/{"wildcard":{"$field":"$item"}}/ );
        }
    }

    my $esQuery = qq/{
  "indexes": "recipe",
  "columns": "ID,Name,Icon",
  "body": {
    "query": {
      "bool": {
        "should": [
/;
    $esQuery .= join( ",\n", @terms );

    $esQuery .= qq/
        ]
      }
    },
    "from": 0,
    "size": 100
  }
}/;

    my $req = HTTP::Request->new( POST => "$self->{'host'}/search" );
    $req->content($esQuery);

    my $retval = {};
    my $resp   = $self->{_ua}->request($req);
    if( $resp->is_success() ) {
        $retval = $self->{'_json'}->decode( $resp->decoded_content() );
    } else {
        quick( error => $resp->status_line() );
    }
    return $retval;
}

sub getApiData {
    my ( $self, $url, $cacheName ) = @_;

    $cacheName = undef unless( $self->{'cache'} );

    my $obj = undef;
    if( defined($cacheName) && -f "$self->{'cacheDir'}/$cacheName.json" ) {
        open( my $fh, '<', "$self->{'cacheDir'}/$cacheName.json" );
        local $/ = undef;
        $obj = $self->{'_json'}->decode(<$fh>);
        close($fh);
    } else {
        my $req = HTTP::Request->new( GET => $url );
        my $resp = $self->{_ua}->request($req);
        if( $resp->is_success() ) {
            $obj = $self->{'_json'}->decode( $resp->decoded_content() );
            if( defined($cacheName) ){
            open( my $fh, '>', "$self->{'cacheDir'}/$cacheName.json" );
            $fh->print( $resp->decoded_content() );
            close($fh);
            }
        } else {
            quick( error => $resp->status_line() );
        }
    }

    return $obj;
}

sub _getApiData {
    my ( $self, $endpoint, $cacheName ) = @_;

    $cacheName = undef unless( $self->{'cache'} );

    my $obj = undef;
    if( defined($cacheName) && -f "$self->{'cacheDir'}/$cacheName.json" ) {
        open( my $fh, '<', "$self->{'cacheDir'}/$cacheName.json" );
        local $/ = undef;
        $obj = $self->{'_json'}->decode(<$fh>);
        close($fh);
    } else {
    quick("$self->{'host'}/$endpoint") if( $self->{'verbose'} );
        my $req = HTTP::Request->new( GET => "$self->{'host'}/$endpoint" );
        my $resp = $self->{_ua}->request($req);
        if( $resp->is_success() ) {
            $obj = $self->{'_json'}->decode( $resp->decoded_content() );
            if( defined($cacheName) ){
            open( my $fh, '>', "$self->{'cacheDir'}/$cacheName.json" );
            $fh->print( $resp->decoded_content() );
            close($fh);
            }
        } else {
            quick( error => $resp->status_line() );
        }
    }

    return $obj;
}

sub search{
  my ($self, $filters, $cacheName) = @_;

    $cacheName = undef unless( $self->{'cache'} );

  my $filter = join(',', (map{ url_encode($_) } @{$filters}));
  $filter =~ s/\+//g;

  my @retval;
  my $nextPage = 1;
  while( defined($nextPage) ){
  my $obj = $self->_getApiData("search?filters=$filter&page=$nextPage");
  printObject($obj);
    push(@retval, @{$obj->{'Results'}});
    $nextPage=$obj->{'Pagination'}{'PageNext'};
  }

  return wantarray ? @retval : \@retval;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

XIVAPI - [One line description of module's purpose here]


=head1 VERSION

This document describes XIVAPI version 0.0.1


=head1 SYNOPSIS

    use XIVAPI;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

XIVAPI requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-xivapi@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Andrew Pressel  C<< <ufotofu@whistlinglemons.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2019, Andrew Pressel C<< <ufotofu@whistlinglemons.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


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

