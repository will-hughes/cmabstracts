#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use FindBin;
use lib $FindBin::Bin;          # find TaxMatch.pm beside this script
use lib "/opt/eprints3/perl_lib";
use EPrints;
use TaxMatch qw(build_lookup find_lwords);

# Command line options
my ($archive_id, $eprint_ids_file, $since_date, $help, $verbose, $batch_size, $batch_offset, $dry_run, $out_file);
GetOptions(
    'archive=s'      => \$archive_id,
    'eprints-file=s' => \$eprint_ids_file,
    'since-date=s'   => \$since_date,
    'batch-size=i'   => \$batch_size,      # Records per batch
    'batch-offset=i' => \$batch_offset,    # Starting offset
    'dry-run'        => \$dry_run,         # Compute and report, never write
    'out=s'          => \$out_file,        # Send the dry-run report to a file
    'verbose'        => \$verbose,
    'help'           => \$help
);

# Help and usage
if ($help || !$archive_id) {
    print <<"USAGE";
Usage: $0 --archive <archive_id> [options]

Options:
    --archive <id>        archive ID (required)
    --eprints-file <file> File containing eprint IDs to process
    --since-date <date>   Process eprints modified since date (YYYY-MM-DD)
    --batch-size <N>      Process in batches of N records
    --batch-offset <N>    Start at offset N
    --dry-run             Compute changes and report them, but do NOT write
    --out <file>          Write the report to <file> instead of the screen
    --verbose             Show detailed term matching output
    --help                Show this help message

Examples:
    perl $0 --archive arcom                    # Process entire archive
    perl $0 --archive arcom --batch-size 1000  # Process first 1000 records
    perl $0 --archive arcom --dry-run --batch-size 50            # Preview, no writes
    perl $0 --archive arcom --eprints-file ids.txt --dry-run --out report.txt
    perl $0 --archive arcom --since-date 2024-01-01  # Incremental update

USAGE
    exit;
}

my $archive = EPrints->new->repository($archive_id) or die "Could not load archive $archive_id";
my $dbh = $archive->get_database->{dbh};

# Defaults (removed default 1000 limit so it runs the whole archive if unspecified)
$batch_offset ||= 0;

# Where the report goes (dry-run details, and verbose output).
my $report_fh;
if ($out_file) {
    open($report_fh, '>:encoding(utf8)', $out_file) or die "Cannot open $out_file: $!";
} else {
    $report_fh = \*STDOUT;
}

print "Starting taxonomy indexing for archive: $archive_id\n";
print "DRY RUN: no records will be written.\n" if $dry_run;

# Get all lookup terms with all fields
my $lookup_terms = $dbh->selectall_hashref(
    "SELECT lword, iterm, topic, subject, facet FROM taxonomy",
    "lword"
);

print "Compiling taxonomy into optimized search structure...\n";

# Build the matching engine. Plural handling lives in TaxMatch::build_lookup,
# so it is identical to what test_taxindex.pl exercises.
my ($clean_to_original, $compiled_regex) = build_lookup($lookup_terms);

# Get eprint IDs based on options
my $eprint_ids = get_eprint_ids($archive, $eprint_ids_file, $since_date, $batch_size, $batch_offset);
my $total = scalar(@$eprint_ids);
print "Found $total eprints to index\n";

my $processing_batch_size = 100;  # Internal processing batch size
my $updated_count = 0;

for (my $i = 0; $i < $total; $i += $processing_batch_size) {
    my $end_idx = $i + $processing_batch_size - 1;
    $end_idx = $total - 1 if $end_idx >= $total;

    my @batch_ids = @$eprint_ids[$i .. $end_idx];

    $updated_count += process_batch(\@batch_ids, $lookup_terms, $clean_to_original, $compiled_regex, $i + 1, $total, $verbose, $dry_run, $report_fh);
}

if ($dry_run) {
    print "Dry run complete. $updated_count eprints would be updated. No records were written.\n";
} else {
    print "Taxonomy indexing complete. Updated $updated_count eprints.\n";
}

close($report_fh) if $out_file;


sub get_eprint_ids {
    my ($archive, $eprint_ids_file, $since_date, $batch_size, $batch_offset) = @_;

    if ($eprint_ids_file) {
        open my $fh, '<', $eprint_ids_file or die "Cannot open $eprint_ids_file: $!";
        chomp(my @ids = <$fh>);
        close $fh;
        return \@ids;
    }
    elsif ($since_date) {
        return $archive->dataset('eprint')->search(
            filters => [
                { meta_fields => ['lastmod'], value => $since_date, match => 'gt' }
            ]
        )->ids;
    }
    else {
        my %search_params = ();
        $search_params{limit}  = $batch_size  if $batch_size;
        $search_params{offset} = $batch_offset if $batch_offset;
        return $archive->dataset('eprint')->search(%search_params)->ids;
    }
}


sub process_batch {
    my ($batch_ids, $lookup_terms, $clean_to_orig_ref, $compiled_regex, $current, $total, $verbose, $dry_run, $report_fh) = @_;

    my $batch_end = $current + scalar(@$batch_ids) - 1;
    print "Processing records $current to $batch_end of $total\n";

    my $batch_updated = 0;
    my $count = 0;

    foreach my $eprint_id (@$batch_ids) {
        next unless $eprint_id;
        $count++;

        if ($verbose) {
            print "  Processing record: $eprint_id\n";
        } else {
            print "  Processed $count of " . scalar(@$batch_ids) . " records in batch\r";
        }

        my $eprint = $archive->dataset('eprint')->dataobj($eprint_id);
        next unless $eprint;

        my %found_iterms;
        my %found_topics;
        my %found_subjects;
        my %found_facets;

        my $text = lc(join(' ',
            $eprint->value('title')    || '',
            $eprint->value('abstract') || '',
            $eprint->value('keywords') || '',
        ));

        # Single shared matching call (same engine as the test harness).
        foreach my $orig_lword (find_lwords($text, $clean_to_orig_ref, $compiled_regex)) {
            my $t = $lookup_terms->{$orig_lword};
            next unless $t;
            $found_iterms{$t->{iterm}}     = 1 if defined $t->{iterm};
            $found_topics{$t->{topic}}     = 1 if defined $t->{topic};
            $found_subjects{$t->{subject}} = 1 if defined $t->{subject};
            $found_facets{$t->{facet}}     = 1 if defined $t->{facet};
        }

        # --- DIFF CHECK ---
        my @new_iterms   = keys %found_iterms;
        my @new_topics   = keys %found_topics;
        my @new_subjects = keys %found_subjects;
        my @new_facets   = keys %found_facets;
        my $new_dscope   = @new_iterms ? update_dscope($eprint, \%found_facets) : "0";

        my $old_iterms   = $eprint->value('iterm')   || [];
        my $old_topics   = $eprint->value('topic')   || [];
        my $old_subjects = $eprint->value('subject') || [];
        my $old_facets   = $eprint->value('facet')   || [];
        my $old_dscope   = $eprint->value('dscope')  || "0";

        my $changed = 0;
        $changed = 1 if join('||', sort @new_iterms)   ne join('||', sort @$old_iterms);
        $changed = 1 if join('||', sort @new_topics)   ne join('||', sort @$old_topics);
        $changed = 1 if join('||', sort @new_subjects) ne join('||', sort @$old_subjects);
        $changed = 1 if join('||', sort @new_facets)   ne join('||', sort @$old_facets);
        $changed = 1 if $new_dscope ne $old_dscope;

        if ($changed) {
            if ($verbose || $dry_run) {
                my $tag = $dry_run ? "would update (dry run, not written)" : "updated";
                print {$report_fh} "\n  EPrint $eprint_id $tag:\n";
                print {$report_fh} "    Terms: "             . join(', ', @new_iterms)   . "\n";
                print {$report_fh} "    topics: "            . join(', ', @new_topics)   . "\n";
                print {$report_fh} "    Subjects: "          . join(', ', @new_subjects) . "\n";
                print {$report_fh} "    Facets: "            . join(', ', @new_facets)   . "\n";
                print {$report_fh} "    Descriptive Scope: $new_dscope\n";
            }

            unless ($dry_run) {
                $eprint->set_value('iterm',   \@new_iterms);
                $eprint->set_value('topic',   \@new_topics);
                $eprint->set_value('subject', \@new_subjects);
                $eprint->set_value('facet',   \@new_facets);
                $eprint->set_value('dscope',  $new_dscope);
                $eprint->commit();
            }
            $batch_updated++;
        }
        else {
            if ($verbose) {
                print {$report_fh} "\n  EPrint $eprint_id unchanged (skipping).\n";
            }
        }
    }

    my $label = $dry_run ? "would-be updates" : "actual database commits";
    print "\n  Batch complete ($batch_updated $label)\n";
    return $batch_updated;
}


sub update_dscope {
    my ( $eprint, $found_facets_ref ) = @_;

    my %facet_letters;
    foreach my $facet (keys %$found_facets_ref) {
        if    ($facet =~ /phenomenon_/)            { $facet_letters{'P'} = 1; }
        elsif ($facet eq 'concept')                { $facet_letters{'C'} = 1; }
        elsif ($facet eq 'theoretical_framing')    { $facet_letters{'T'} = 1; }
        elsif ($facet eq 'empirical_technique')    { $facet_letters{'E'} = 1; }
        elsif ($facet eq 'analytical_technique')   { $facet_letters{'A'} = 1; }
    }

    my $scope_count = scalar(keys %facet_letters);

    my $facet_code = '';
    $facet_code .= 'P' if exists $facet_letters{'P'};
    $facet_code .= 'C' if exists $facet_letters{'C'};
    $facet_code .= 'T' if exists $facet_letters{'T'};
    $facet_code .= 'E' if exists $facet_letters{'E'};
    $facet_code .= 'A' if exists $facet_letters{'A'};

    return "$scope_count $facet_code";
}
