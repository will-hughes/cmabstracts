#!/usr/bin/perl

use strict;
use warnings;
use lib "/opt/eprints3/perl_lib";
use EPrints;

my $repo = EPrints->new->repository("arcom") or die "Could not load repository";

# Statistics storage
my %yearly_stats;
my %type_counts;
my %journal_yearly;
my %all_years;

my $dataset = $repo->dataset('eprint');

print "Starting eprint processing...\n";

# Get all IDs first, then process them - handle array reference correctly
my $search = $dataset->search;
my $ids_ref = $search->get_ids;  # This returns an array reference
my @all_ids = @$ids_ref;         # Dereference it to get a regular array
my $total_eprints = scalar(@all_ids);

print "Found $total_eprints eprints to process\n";

my $counter = 0;
my $last_report = 0;

foreach my $id (@all_ids) {
    $counter++;
    
    # Show progress
    if ($counter % 1000 == 0 || time() - $last_report > 10) {
        my $percent = int(($counter / $total_eprints) * 100);
        print "Processed $counter records ($percent% of $total_eprints)...\n";
        $last_report = time();
    }
    
    my $eprint = $dataset->dataobj($id);
    if (!$eprint) {
        print "Warning: Could not load record ID: $id\n";
        next;
    }
    
    # Get values with proper EPrints methods
    my $type = $eprint->get_value('type') || 'Unknown';
    my $publication = $eprint->get_value('publication') || 'Unknown';
    
    # Handle date - from debug we see dates are simple strings like "2001"
    my $year = 'Unknown';
    my $date = $eprint->get_value('date');
    
    if ($date && $date =~ /(\d{4})/) {
        $year = $1;
    }
    
    # Store statistics
    $all_years{$year} = 1;
    $yearly_stats{$year}{$type}++;
    $type_counts{$type}++;
    
    if ($type eq 'article' && $publication ne 'Unknown') {
        $journal_yearly{$publication}{$year}++;
    }
}

print "Processing complete! Processed $counter records.\n";

# Generate screen reports (same as before)
my @years = sort { $a <=> $b } grep { $_ ne 'Unknown' && $_ =~ /^\d{4}$/ } keys %all_years;

print "\nOVERALL STATISTICS BY TYPE:\n";
foreach my $type (sort keys %type_counts) {
    printf "%-20s: %d\n", $type, $type_counts{$type};
}

print "\nYEARLY BREAKDOWN:\n";
print "Year     | Theses | Conference | Articles | Total\n";
print "---------|--------|------------|----------|------\n";

foreach my $year (@years) {
    my $theses = $yearly_stats{$year}{thesis} || 0;
    my $conference = $yearly_stats{$year}{conference_item} || 0;
    my $articles = $yearly_stats{$year}{article} || 0;
    my $total = $theses + $conference + $articles;
    
    printf "%-8s | %6d | %10d | %8d | %5d\n", 
           $year, $theses, $conference, $articles, $total;
}

# Also show unknown years
if ($yearly_stats{'Unknown'}) {
    my $theses = $yearly_stats{'Unknown'}{thesis} || 0;
    my $conference = $yearly_stats{'Unknown'}{conference_item} || 0;
    my $articles = $yearly_stats{'Unknown'}{article} || 0;
    my $total = $theses + $conference + $articles;
    
    printf "%-8s | %6d | %10d | %8d | %5d\n", 
           'Unknown', $theses, $conference, $articles, $total;
}

print "\nALL JOURNALS YEARLY BREAKDOWN:\n";
my @journals = sort keys %journal_yearly;

if (@journals) {
    foreach my $journal (@journals) {
        print "\n$journal:\n";
        foreach my $year (@years) {
            my $count = $journal_yearly{$journal}{$year} || 0;
            printf "  %s: %d\n", $year, $count if $count > 0;
        }
        my $journal_total = 0;
        $journal_total += $_ for values %{$journal_yearly{$journal}};
        printf "  Total: %d\n", $journal_total;
    }
} else {
    print "No journal articles found.\n";
}

# Generate CSV file
print "\nGenerating CSV file...\n";
generate_csv(\@years, \%journal_yearly, \%yearly_stats);

print "\nADDITIONAL STATISTICS:\n";
printf "Total records processed: %d\n", $counter;
printf "Years with data: %d\n", scalar(@years);
printf "Different publication types: %d\n", scalar(keys %type_counts);
printf "Different journals: %d\n", scalar(keys %journal_yearly);

sub generate_csv {
    my ($years_ref, $journals_ref, $yearly_stats_ref) = @_;
    my @years = @$years_ref;
    my %journal_yearly = %$journals_ref;
    my %yearly_stats = %$yearly_stats_ref;
    
    my $filename = "eprints_statistics.csv";
    
    open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
    
    # Write header row
    print $fh "Type/Journal";
    foreach my $year (@years) {
        print $fh ",$year";
    }
    print $fh ",Total\n";
    
    # Write Theses row
    print $fh "Theses";
    my $theses_total = 0;
    foreach my $year (@years) {
        my $count = $yearly_stats{$year}{thesis} || 0;
        print $fh ",$count";
        $theses_total += $count;
    }
    print $fh ",$theses_total\n";
    
    # Write Conference row
    print $fh "Conference";
    my $conference_total = 0;
    foreach my $year (@years) {
        my $count = $yearly_stats{$year}{conference_item} || 0;
        print $fh ",$count";
        $conference_total += $count;
    }
    print $fh ",$conference_total\n";
    
    # Write Articles row (total across all journals)
    print $fh "Articles";
    my $articles_total = 0;
    foreach my $year (@years) {
        my $count = $yearly_stats{$year}{article} || 0;
        print $fh ",$count";
        $articles_total += $count;
    }
    print $fh ",$articles_total\n";
    
    # Write each journal
    foreach my $journal (sort keys %journal_yearly) {
        print $fh "\"$journal\"";
        my $journal_total = 0;
        foreach my $year (@years) {
            my $count = $journal_yearly{$journal}{$year} || 0;
            print $fh ",$count";
            $journal_total += $count;
        }
        print $fh ",$journal_total\n";
    }
    
    close($fh);
    print "CSV file created: $filename\n";
    
    # Print CSV summary
    print "\nCSV FILE SUMMARY:\n";
    printf "Rows: %d (Theses, Conference, Articles + %d journals)\n", 
           3 + scalar(keys %journal_yearly), scalar(keys %journal_yearly);
    printf "Columns: %d (Type/Journal + %d years + Total)\n", 
           scalar(@years) + 2, scalar(@years);
    printf "File: $filename\n";
}