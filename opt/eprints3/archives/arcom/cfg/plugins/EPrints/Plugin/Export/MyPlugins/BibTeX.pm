package EPrints::Plugin::Export::MyPlugins::BibTeX;

@ISA = ( "EPrints::Plugin::Export" );

use strict;
use warnings;
use EPrints::Plugin::Export;
use TeX::Encode;

sub new {
    my( $class, %params ) = @_;
    my $self = $class->SUPER::new( %params );

    $self->{name} = "BibTeX";
    $self->{accept} = [ 'dataobj/eprint', 'list/eprint' ];
    $self->{visible} = "all";
    $self->{suffix} = ".bib";
    $self->{mimetype} = "text/plain; charset=utf-8";

    return $self;
}

sub output_dataobj {
    my( $plugin, $eprint ) = @_;

    my $type = $eprint->get_type;
    my $entry_type = "misc";

    $entry_type = "article" if $type eq "article";
    $entry_type = "inproceedings" if $type eq "conference_item";
    $entry_type = "phdthesis" if $type eq "thesis";

    my $key = $plugin->{session}->get_repository->get_id . $eprint->get_id;
    my @fields;

    # Title
    push @fields, format_field("title", $eprint->get_value("title"));

    # Authors
    if( $eprint->exists_and_set("creators") ) {
        my @authors;
        foreach my $creator (@{ $eprint->get_value("creators") }) {
            push @authors, make_bibtex_name($creator->{name});
        }
        push @fields, format_field("author", join(" and ", @authors));
    }

    # Supervisors (as custom field)
    if( $type eq "thesis" && $eprint->exists_and_set("contributors") ) {
        foreach my $contrib (@{ $eprint->get_value("contributors") }) {
            if( $contrib->{type} eq "http://www.loc.gov/loc.terms/relators/THS" ) {
                push @fields, format_field("supervisor", make_bibtex_name($contrib->{name}));
            }
        }
    }

    # Abstract
    push @fields, format_field("abstract", $eprint->get_value("abstract"));

    # URL
    if( $eprint->is_set("official_url") ) {
        push @fields, format_field("url", $eprint->get_value("official_url"));
    } else {
        push @fields, format_field("url", $eprint->get_url);
    }

    # DOI
    if( $eprint->is_set("id_number") && $eprint->get_value("id_number") =~ m/(doi|10\.)/ ) {
        push @fields, format_field("doi", $eprint->get_value("id_number"));
    }

    # Journal info
    if( $type eq "article" ) {
        push @fields, format_field("journal", $eprint->get_value("publication"));
        push @fields, format_field("volume", $eprint->get_value("volume"));
        push @fields, format_field("number", $eprint->get_value("number"));
    }

    # Conference info
    if( $type eq "conference_item" ) {
        push @fields, format_field("booktitle", $eprint->get_value("event_title"));
        push @fields, format_field("address", $eprint->get_value("event_location"));
        push @fields, format_field("eventdate", $eprint->get_value("event_dates"));
        push @fields, format_field("publisher", $eprint->get_value("publisher"));
    }

    # Thesis info
    if( $type eq "thesis" ) {
        push @fields, format_field("school", $eprint->get_value("institution"));
        push @fields, format_field("address", $eprint->get_value("place_of_pub"));
        push @fields, format_field("type", $eprint->get_value("thesis_type_display"));
        push @fields, format_field("ethosid", $eprint->get_id);
    }

    # Keywords
    my $kw = $eprint->get_value("keywords");
    if( ref($kw) eq "ARRAY" ) {
        push @fields, format_field("keywords", join(", ", @$kw));
    } elsif( defined $kw ) {
        push @fields, format_field("keywords", $kw);
    }

    # ISSN / ISBN
    push @fields, format_field("issn", $eprint->get_value("issn")) if $eprint->is_set("issn");
    push @fields, format_field("isbn", $eprint->get_value("isbn")) if $eprint->is_set("isbn");

    # Year
    if( $eprint->is_set("date") && $eprint->get_value("date") =~ /^([0-9]{4})/ ) {
        push @fields, format_field("year", $1);
    }

    # Pages
    if( $eprint->exists_and_set("pagerange") ) {
        my $pagerange = $eprint->get_value("pagerange");
        $pagerange =~ s/-/--/;
        push @fields, format_field("pages", $pagerange);
    } elsif( $eprint->exists_and_set("pages") ) {
        push @fields, format_field("pages", $eprint->get_value("pages"));
    }

    # Note
    push @fields, format_field("note", $eprint->get_value("note")) if $eprint->is_set("note");

    my $entry = "\@$entry_type\{$key,
";
    $entry .= join(",
", @fields);
    $entry .= "
\}

";

    return $entry;
}

sub format_field {
    my ($key, $value) = @_;
    return "" unless defined $value && $value ne "";
    $value = TeX::Encode::encode('bibtex', $value);
    return sprintf("  %-12s = {%s}", $key, $value);
}

sub make_bibtex_name {
    my ($name) = @_;
    return "" unless ref($name) eq "HASH";
    my $family = $name->{family} || "";
    my $given = $name->{given} || "";
    return "$family, $given";
}

1;
