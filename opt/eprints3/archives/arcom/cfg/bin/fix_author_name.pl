#!/usr/bin/perl
#
# fix_author_name.pl - bring variant spellings of one author's name
# to a single authority form, saving each record through EPrints so that
# the search index, sort values, revision history and lastmod all update.
#
# Variants are identified by the HEX of the stored family name, so that
# look-alike strings (precomposed vs decomposed characters, dotted vs
# dotless i) are matched exactly and never by accident.
#
# Usage (run as the eprints user):
#   fix_author_name.pl <repoid> \
#       --to-family "Çıdık" --to-given "M S" \
#       --from-hex 436964696B --from-hex C3876964696B ... \
#       [--given-prefix M] [--commit]
#
# Without --commit it is a dry run: it lists what would change and
# writes nothing. Stop the indexer before a --commit run; restart it after.

use strict;
use warnings;
use lib '/opt/eprints3/perl_lib';
use EPrints;
use Getopt::Long;
use Encode qw(decode_utf8 encode_utf8);
use Unicode::Normalize qw(NFC);

binmode STDOUT, ':encoding(UTF-8)';

my ( $to_family, $to_given, @from_hex, $given_prefix, $commit );
GetOptions(
    'to-family=s'    => \$to_family,
    'to-given=s'     => \$to_given,
    'from-hex=s'     => \@from_hex,
    'given-prefix=s' => \$given_prefix,
    'commit'         => \$commit,
) or die "Bad options\n";

my $repoid = shift @ARGV
    or die "Usage: $0 <repoid> --to-family X --to-given Y --from-hex H [--from-hex H ...] [--given-prefix P] [--commit]\n";
die "Need --to-family, --to-given and at least one --from-hex\n"
    unless defined $to_family && defined $to_given && @from_hex;

# Normalise the target to precomposed form, whatever the terminal sent
$to_family = NFC( decode_utf8( $to_family ) );
$to_given  = NFC( decode_utf8( $to_given ) );
$given_prefix = decode_utf8( $given_prefix ) if defined $given_prefix;

my %from;
foreach my $h ( @from_hex ) {
    die "Not a hex string: $h\n" unless $h =~ /^[0-9A-Fa-f]+$/;
    $from{ uc $h } = 1;
}

my $repo = EPrints->new->repository( $repoid )
    or die "Cannot open repository $repoid\n";
my $db = $repo->database;

printf "Target: %s, %s   [family hex %s]\n",
    $to_family, $to_given, uc unpack( 'H*', encode_utf8( $to_family ) );
print $commit ? "MODE: COMMIT\n\n" : "MODE: DRY RUN - nothing will be written\n\n";

# Find the records that hold any of the variants
my $in  = join ',', map { "'$_'" } sort keys %from;
my $sth = $db->prepare(
    "SELECT DISTINCT eprintid FROM eprint_creators_name
     WHERE HEX(creators_name_family) IN ($in) ORDER BY eprintid" );
$sth->execute;
my @ids;
while ( my ( $id ) = $sth->fetchrow_array ) { push @ids, $id }

my $ds = $repo->dataset( 'eprint' );
my ( @changed, $rows );

foreach my $id ( @ids ) {
    my $ep = $ds->dataobj( $id ) or do { print "  $id: cannot load, skipped\n"; next };
    my $creators = EPrints::Utils::clone( $ep->value( 'creators' ) || [] );
    my $n = 0;

    foreach my $c ( @$creators ) {
        my $name = $c->{name} or next;
        my $fam  = defined $name->{family} ? $name->{family} : '';
        my $giv  = defined $name->{given}  ? $name->{given}  : '';
        next unless $from{ uc unpack( 'H*', encode_utf8( $fam ) ) };
        next if defined $given_prefix && index( $giv, $given_prefix ) != 0;

        printf "  %6d  %s, %s  ->  %s, %s\n", $id, $fam, $giv, $to_family, $to_given;
        $name->{family} = $to_family;
        $name->{given}  = $to_given;
        $n++;
    }
    next unless $n;

    $rows += $n;
    push @changed, $id;
    if ( $commit ) {
        $ep->set_value( 'creators', $creators );
        $ep->commit( 1 );
    }
}

printf "\n%d name(s) in %d record(s) %s\n",
    $rows || 0, scalar @changed, $commit ? 'changed' : 'would change';
print "Record ids: @changed\n" if @changed;