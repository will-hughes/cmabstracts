#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use lib "/opt/eprints3/perl_lib";
use EPrints;

# Command line options
my ($archive_id, $csv_file, $help);
GetOptions(
    'archive=s'   => \$archive_id,  # Actually archive ID
    'csv-file=s'  => \$csv_file,
    'help'        => \$help
);

# Help and usage
if ($help || !$archive_id) {
    print <<"USAGE";
Usage: $0 --archive <archive_id> [options]

Options:
    --archive <id>    Archive ID (required)
    --csv-file <file>    Path to CSV file (default: <archive_path>/taxonomy.csv)
    --help               Show this help message

Examples:
    $0 --archive arcom                    # Load into live archive
    $0 --archive arcom                   # Load into test archive  
    $0 --archive arcom --csv-file /path/to/custom.csv  # Load custom CSV

USAGE
    exit;
}
my $archive = EPrints->new->repository($archive_id) or die "Could not load archive $archive_id";
my $dbh = $archive->get_database->{dbh};

# Determine CSV file path
my $csv_path = $archive->get_conf("archiveroot") . "/" . ($csv_file || "taxonomy.csv");

print "Loading taxonomy for repository: $archive_id\n";
print "CSV file: $csv_path\n";

# Clear existing data
$dbh->do("TRUNCATE TABLE taxonomy");

# Load CSV
open my $fh, "<:encoding(utf8)", $csv_path or die "Cannot open CSV file '$csv_path': $!";
my $header = <$fh>;  # Read and discard the header line

my $sth = $dbh->prepare("INSERT INTO taxonomy (iterm, facet, topic, subject, lword) VALUES (?, ?, ?, ?, ?)");
my $line_count = 0;
my $loaded_count = 0;

while (<$fh>) {
    chomp;
    $line_count++;
    
    my ($iterm, $facet, $topic, $subject, $lword) = split /,/;
    
    # Skip empty lines or malformed rows
    unless ($iterm && $lword) {
        print "Warning: Skipping malformed line $line_count: $_\n";
        next;
    }
    
    eval {
        $sth->execute($iterm, $facet, $topic, $subject, $lword);
        $loaded_count++;
    };
    
    if ($@) {
        print "Error inserting line $line_count: $@\n";
    }
}

close $fh;
$dbh->disconnect;

print "Taxonomy loading complete!\n";
print "Processed $line_count lines, loaded $loaded_count terms into archive: $archive_id\n";
