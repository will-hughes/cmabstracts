#!/usr/bin/perl
# research_design.pl - build the "Research design" browse pages: a list of
# facets, then for each facet the index terms in A-Z range pages laid out like
# the iterm view, each term linked to its existing iterm view page.
# No record lists are generated: the iterm view's pages are reused.
#
# Usage (as eprints):
#   perl research_design.pl           dry run: report only, writes nothing
#   perl research_design.pl --write   writes changed xpages, removes stale ones
#
# Output: cfg/lang/en/static/browse/research_design/ (xpages), rendered by
# generate_static to /browse/research_design/. Not under /view/, because
# Apache/Rewrite.pm routes every /view/ URL to update_view_file, which only
# serves ids in browse_views.
#
# Run after generate_views, then generate_static.
# Headings are phrases facet_<id> in zz_webcfg.xml (Phrase Editor).
# Term filenames use EPrints' own escape_filename + abbr_path; A-Z ranges use
# EPrints' own cluster_ranges_30, matching the iterm view.
# MySQL credentials are read from ~/.my.cnf.

use strict;
use warnings;
use lib '/opt/eprints3/perl_lib';
use EPrints::Utils;
use EPrints::Update::Views;
use XML::LibXML;
use POSIX qw(ceil);
use File::Path qw(make_path);

my $WRITE = (@ARGV && $ARGV[0] eq '--write');

my $DB         = 'arcom';
my $VIEW_DIR   = '/opt/eprints3/archives/arcom/html/en/view/iterm';
my $OUT_DIR    = '/opt/eprints3/archives/arcom/cfg/lang/en/static/browse/research_design';
my $ITERM_LINK = '../../../view/iterm/';   # relative from /browse/research_design/<facet>/
my $TITLE      = 'Browse by Research design';
my $COLS       = 3;                        # as the iterm view (new_column_at => [1,1])

# Display order of facets. Values must match taxonomy.facet exactly.
my @FACETS = qw(
    phenomenon_object
    phenomenon_process
    phenomenon_role
    phenomenon_location
    phenomenon_individual
    concept
    theoretical_framing
    empirical_technique
    analytical_technique
    dissemination
);
my %known = map { $_ => 1 } @FACETS;

sub query {
    my ($sql) = @_;
    open(my $fh, '-|', 'mysql', '-N', '-B', $DB, '-e', $sql)
        or die "mysql: $!\n";
    my @rows;
    while (my $line = <$fh>) {
        chomp $line;
        push @rows, [ split /\t/, $line, -1 ];
    }
    close($fh) or die "mysql query failed: $sql\n";
    return @rows;
}

sub stem {
    my ($f) = EPrints::Update::Views::abbr_path(
        EPrints::Utils::escape_filename($_[0]));
    return $f;
}

sub xml {
    my ($s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

# ---------------------------------------------------------------- data

# Terms carried by live (archive) records, with record counts.
# Keyed by lower case, since MySQL's GROUP BY folds case.
my %nrec;
for my $r (query(q{
    SELECT ei.iterm, COUNT(DISTINCT ei.eprintid)
    FROM eprint_iterm ei
    JOIN eprint e ON e.eprintid = ei.eprintid
    WHERE e.eprint_status = 'archive'
    GROUP BY ei.iterm
})) {
    $nrec{ lc $r->[0] } = $r->[1];
}
die "Fewer than 1000 live index terms returned - aborting\n"
    unless keys(%nrec) > 1000;

my (%by_facet, %unknown, %facets_of, %seen, @missing);
my $no_records = 0;
for my $r (query(q{
    SELECT DISTINCT iterm, facet FROM taxonomy
    WHERE iterm IS NOT NULL AND iterm <> ''
})) {
    my ($term, $facet) = @$r;
    $facet = '' if !defined $facet || $facet eq 'NULL';
    next if $seen{"$facet\t$term"}++;

    unless ($known{$facet}) {
        $unknown{ $facet eq '' ? '(empty)' : $facet }++;
        next;
    }
    $facets_of{$term}{$facet} = 1;

    my $n = $nrec{ lc $term };
    unless ($n) { $no_records++; next; }

    my $stem = stem($term);
    if (-e "$VIEW_DIR/$stem.page") {
        push @{ $by_facet{$facet} }, [ $term, $stem, $n ];
    }
    else {
        push @missing, "$facet\t$term\t$n records\t$stem";
    }
}

# ---------------------------------------------------------------- report

print "== Facet values not in the facet list (terms skipped) ==\n";
print %unknown
    ? map { "  $_\t$unknown{$_} terms\n" } sort keys %unknown
    : "  none\n";

print "\n== Terms with live records but no iterm view page (omitted) ==\n";
print @missing ? map { "  $_\n" } sort @missing : "  none\n";

my @multi = grep { keys %{ $facets_of{$_} } > 1 } sort keys %facets_of;
print "\n== Terms in more than one facet (listed under each) ==\n";
print @multi
    ? map { "  $_\t" . join(', ', sort keys %{ $facets_of{$_} }) . "\n" } @multi
    : "  none\n";

print "\n== Terms listed per facet ==\n";
my $total = 0;
for my $f (@FACETS) {
    my $c = $by_facet{$f} ? scalar @{ $by_facet{$f} } : 0;
    $total += $c;
    printf "  %-24s %5d\n", $f, $c;
}
printf "  %-24s %5d\n", 'total', $total;
print "  Taxonomy terms with no live records (skipped): $no_records\n";

# If the view's filename scheme or layout ever changes (e.g. in an upgrade),
# most lookups fail. Stop rather than overwrite good pages with thin ones.
die "\nOnly $total terms matched view pages (", scalar(@missing),
    " missing) - view layout may have changed; nothing written\n"
    if $total < 1000 || @missing > 50;

# ---------------------------------------------------------------- pages

sub xpage {
    my ($title, $body) = @_;
    return <<"END";
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<!DOCTYPE page SYSTEM "entities.dtd">
<!-- Generated by cfg/bin/research_design.pl. Do not edit by hand. -->
<xpage:page xmlns="http://www.w3.org/1999/xhtml" xmlns:xpage="http://eprints.org/ep3/xpage" xmlns:epc="http://eprints.org/ep3/control">
<xpage:title>$title</xpage:title>
<xpage:body>
$body</xpage:body>
</xpage:page>
END
}

# Columns as EPrints' render_menu draws them.
sub render_cols {
    my ($terms) = @_;
    my $len = ceil(@$terms / $COLS);
    my $h = qq{<div class="ep_view_cols ep_view_cols_$COLS"><div>\n};
    for my $c (1 .. $COLS) {
        my @slice = grep { defined } @$terms[ ($c - 1) * $len .. $c * $len - 1 ];
        $h .= qq{<div class="ep_view_col ep_view_col_$c">};
        if (@slice) {
            $h .= "<ul>\n";
            $h .= sprintf qq{<li><a href="%s%s.html">%s</a> (%d)</li>\n},
                $ITERM_LINK, xml($_->[1]), xml($_->[0]), $_->[2]
                for @slice;
            $h .= "</ul>";
        }
        $h .= "</div>\n";
    }
    $h .= "</div></div>\n";
    return $h;
}

my %pages;   # path relative to $OUT_DIR => content

# Top page: the facets.
my $top = qq{<div class="ep_view_menu">\n<ul>\n};
for my $f (@FACETS) {
    my $list = $by_facet{$f} or next;
    $top .= sprintf qq{<li><a href="%s/index.html"><epc:phrase ref="facet_%s"/></a> (%d)</li>\n},
        $f, $f, scalar @$list;
}
$top .= "</ul>\n</div>\n";
$pages{'index.xpage'} = xpage(xml($TITLE), $top);

# One set of A-Z range pages per facet.
for my $f (@FACETS) {
    my $list = $by_facet{$f} or next;

    # Group by first letter or digit, as EPrints' group_by_n_chars does.
    my %groups;
    for my $t (@$list) {
        (my $v = $t->[0]) =~ s/[^A-Za-z0-9]+//g;
        my $g = $v eq '' ? '?' : uc substr($v, 0, 1);
        push @{ $groups{$g} }, $t;
    }
    my @order  = sort keys %groups;
    my $ranges = EPrints::Update::Views::cluster_ranges_30(undef, undef, \%groups, \@order);

    my $title = qq{Research design: <epc:phrase ref="facet_$f"/>};

    for my $i (0 .. $#$ranges) {
        my $range = $ranges->[$i];

        my $body = qq{<div class="no_link_decor"><a href="../index.html"><epc:phrase ref="Update/Views:up_a_level"/></a></div>\n};
        $body .= qq{<div class="ep_view_menu">\n};
        if (@$ranges > 1) {
            $body .= qq{<div class="ep_toolbox"><div class="ep_toolbox_content">};
            $body .= join ' | ', map {
                $_->[0] eq $range->[0]
                    ? '<b>' . xml($_->[0]) . '</b>'
                    : sprintf('<a href="index.%s.html">%s</a>',
                        xml(EPrints::Utils::escape_filename($_->[0])), xml($_->[0]))
            } @$ranges;
            $body .= "</div></div>\n";
        }
        for my $g (@{ $range->[1] }) {
            my @terms = sort { lc($a->[0]) cmp lc($b->[0]) or $a->[0] cmp $b->[0] }
                @{ $groups{$g} };
            $body .= '<h2>' . xml($g) . "...</h2>\n";
            $body .= render_cols(\@terms);
        }
        $body .= "</div>\n";

        my $page = xpage($title, $body);
        $pages{ "$f/index." . EPrints::Utils::escape_filename($range->[0]) . ".xpage" } = $page
            if @$ranges > 1;
        $pages{"$f/index.xpage"} = $page if $i == 0;   # front page shows the first range
    }
}

# Refuse to write anything that is not well-formed XML.
my $parser = XML::LibXML->new(load_ext_dtd => 0);
for my $p (sort keys %pages) {
    eval { $parser->parse_string($pages{$p}); 1 }
        or die "Generated page $p is not well-formed XML - nothing written:\n$@";
}

# ---------------------------------------------------------------- write

# Existing generated xpages (this directory belongs to the script).
my @existing;
if (opendir(my $d, $OUT_DIR)) {
    for my $e (readdir $d) {
        next if $e =~ /^\./;
        if ($e =~ /\.xpage$/) { push @existing, $e; next; }
        next unless -d "$OUT_DIR/$e";
        opendir(my $s, "$OUT_DIR/$e") or next;
        push @existing, map { "$e/$_" } grep { /\.xpage$/ } readdir $s;
        closedir $s;
    }
    closedir $d;
}
my @stale = sort grep { !exists $pages{$_} } @existing;

my (@new, @changed, $same);
$same = 0;
for my $p (sort keys %pages) {
    my $old;
    if (open(my $in, '<:raw', "$OUT_DIR/$p")) { local $/; $old = <$in>; close $in; }
    if    (!defined $old)       { push @new, $p }
    elsif ($old ne $pages{$p})  { push @changed, $p }
    else                        { $same++ }
}

printf "\n== Pages ==\n  new %d, changed %d, unchanged %d, stale %d\n",
    scalar @new, scalar @changed, $same, scalar @stale;
print map { "  stale: $_\n" } @stale;

unless ($WRITE) {
    print "\nDry run: nothing written. Output directory: $OUT_DIR\n";
    exit 0;
}

for my $p (@new, @changed) {
    my $file = "$OUT_DIR/$p";
    (my $dir = $file) =~ s{/[^/]+$}{};
    make_path($dir);
    open(my $out, '>:raw', "$file.tmp") or die "write $file.tmp: $!\n";
    print $out $pages{$p};
    close($out) or die "close $file.tmp: $!\n";
    rename("$file.tmp", $file) or die "rename to $file: $!\n";
}
for my $p (@stale) {
    unlink("$OUT_DIR/$p") or warn "could not remove $p: $!\n";
}
printf "\nWritten %d, removed %d.\n", scalar(@new) + scalar(@changed), scalar @stale;
