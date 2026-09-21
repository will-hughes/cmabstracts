#!/usr/bin/perl -w
#
# generate_sitemap.pl
#
# Writes a Google-compatible XML sitemap listing every live abstract page.
#
# Why this exists: EPrints' built-in /sitemap.xml is a semantic-web
# dataset descriptor (DERI sc: extension) containing zero <url> entries.
# Search engines fetch it, find nothing, and discover records only by
# crawling the browse hierarchies — the traversal that caused the
# CPU incident of 23 August 2026. This advertises records directly.
#
# Output: archives/arcom/cfg/static/sitemap_eprints.xml
#         Deployed to the web root by generate_static.
#
# URLs come from $eprint->get_url, which derives from base_url in
# 10_core.pl, so the sitemap follows any future domain change with
# no edit to this script.

use strict;
use FindBin;
use lib "$FindBin::Bin/../../../../perl_lib";
use EPrints;
use POSIX qw( strftime );

my $ARCHIVE = "arcom";
my $verbose = grep { $_ eq "--verbose" } @ARGV;

my $ep = EPrints->new;
my $repo = $ep->repository( $ARCHIVE )
    or die "Could not open repository '$ARCHIVE'\n";

my $outfile = $repo->config( "archiveroot" )
    . "/cfg/static/sitemap_eprints.xml";
my $tmpfile = "$outfile.tmp";

open( my $fh, ">:utf8", $tmpfile )
    or die "Cannot write $tmpfile: $!\n";

print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n};
print $fh qq{<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n};

my $count = 0;

my $list = $repo->dataset( "archive" )->search;

$list->map( sub {
    my( undef, undef, $eprint ) = @_;

    my $url = $eprint->get_url or return;

    print $fh "  <url>\n";
    print $fh "    <loc>" . xml_escape( $url ) . "</loc>\n";

    if( my $lastmod = $eprint->value( "lastmod" ) )
    {
        # EPrints stores "YYYY-MM-DD hh:mm:ss"; W3C date is enough here.
        my( $date ) = split / /, $lastmod;
        print $fh "    <lastmod>$date</lastmod>\n" if $date;
    }

    print $fh "  </url>\n";

    $count++;
    print STDERR "  $count\n" if $verbose && $count % 1000 == 0;
} );

print $fh "</urlset>\n";
close( $fh );

rename( $tmpfile, $outfile )
    or die "Cannot rename $tmpfile to $outfile: $!\n";

print "Wrote $count URLs to $outfile\n";

# generate_static is not run nightly, so deploy directly to the web
# root as well. cfg/static/ remains the source of record and is what
# generate_static will copy on any future full run.
my $webfile = $repo->config( "archiveroot" ) . "/html/en/sitemap_eprints.xml";
EPrints::Utils::copy( $outfile, $webfile )
    or warn "Could not copy to $webfile\n";
print "Deployed to $webfile\n";

$repo->terminate;

sub xml_escape
{
    my( $s ) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    return $s;
}