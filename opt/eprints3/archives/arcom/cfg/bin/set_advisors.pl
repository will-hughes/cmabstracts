#!/usr/bin/perl
# set_advisors.pl  -  set Thesis Advisor contributors on thesis records from a TSV file
#
# Input: tab-separated, one advisor per line, in the order they should appear:
#   eprintid <TAB> family <TAB> given [<TAB> lineage]
# Lines starting with # and blank lines are ignored.
#
# For each eprintid, any existing Thesis Advisor contributors are replaced by the
# names in the file. Other contributors are kept. Non-thesis records are skipped.
#
# Usage:
#   perl set_advisors.pl arcom advisors.tsv           (dry run: shows before and after)
#   perl set_advisors.pl arcom advisors.tsv commit    (saves the changes)

use strict;
use warnings;
use lib '/opt/eprints3/perl_lib';
use EPrints;

my ( $repoid, $file, $mode ) = @ARGV;
die "Usage: $0 <repoid> <file.tsv> [commit]\n" unless $repoid && $file;
my $commit = defined $mode && $mode eq 'commit';

my $THS = 'http://www.loc.gov/loc.terms/relators/THS';

# read the file, keeping the order of records and names
my ( %names, @order );
open my $fh, '<:encoding(UTF-8)', $file or die "Cannot open $file: $!\n";
while ( my $line = <$fh> )
{
    $line =~ s/[\r\n]+$//;
    next if $line =~ /^\s*(#|$)/;
    my ( $id, $family, $given, $lineage ) = map { defined $_ ? s/^\s+|\s+$//gr : '' } split /\t/, $line;
    unless ( $id =~ /^\d+$/ && length $family )
    {
        warn "Skipping malformed line: $line\n";
        next;
    }
    push @order, $id unless $names{$id};
    push @{ $names{$id} }, { family => $family, given => $given, ( length $lineage ? ( lineage => $lineage ) : () ) };
}
close $fh;

my $session = EPrints::Session->new( 1, $repoid ) or die "Cannot open repository $repoid\n";
my $ds = $session->dataset( 'eprint' );

sub show
{
    my ( $list ) = @_;
    return '(none)' unless @$list;
    return join '; ', map {
        my $t = $_->{type} // 'UNSPECIFIED';
        $t =~ s{.*/}{};
        sprintf '%s, %s%s [%s]', $_->{name}->{family} // '', $_->{name}->{given} // '', ( $_->{name}->{lineage} ? ', ' . $_->{name}->{lineage} : '' ), $t;
    } @$list;
}

my ( $done, $skipped ) = ( 0, 0 );
foreach my $id ( @order )
{
    my $ep = $ds->dataobj( $id );
    unless ( $ep )
    {
        print "$id: not found, skipped\n";
        $skipped++;
        next;
    }
    my $type = $ep->value( 'type' ) // '';
    unless ( $type eq 'thesis' )
    {
        print "$id: type is '$type', not thesis, skipped\n";
        $skipped++;
        next;
    }

    my @before = @{ $ep->value( 'contributors' ) || [] };
    my @others = grep { ( $_->{type} // '' ) ne $THS } @before;
    my @advisors = map { { type => $THS, name => { %$_ } } } @{ $names{$id} };
    my @after = ( @advisors, @others );

    my $title = $ep->value( 'title' ) // '';
    $title = substr( $title, 0, 70 ) . '...' if length $title > 70;
    binmode STDOUT, ':encoding(UTF-8)';
    print "$id: $title\n";
    print "   before: ", show( \@before ), "\n";
    print "   after:  ", show( \@after ), "\n";

    if ( $commit )
    {
        $ep->set_value( 'contributors', \@after );
        $ep->commit;
        print "   saved\n";
    }
    $done++;
}

print "\n", ( $commit ? 'Saved' : 'Dry run, nothing saved:' ), " $done records; $skipped skipped\n";
$session->terminate;
