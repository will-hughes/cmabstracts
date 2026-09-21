
package EPrints::Plugin::Export::MyPlugins::EndNote;

use EPrints::Plugin::Export::TextFile;
use EPrints;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new {
    my( $class, %opts ) = @_;
    my $self = $class->SUPER::new( %opts );

    $self->{name} = "EndNote";
    $self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
    $self->{visible} = "all";
    $self->{suffix} = ".enw";

    return $self;
}

sub convert_dataobj {
    my( $plugin, $dataobj ) = @_;

    my $data = {};
    my $type = $dataobj->get_type;
    $data->{0} = "Generic";
    $data->{0} = "Book" if $type eq "book";
    $data->{0} = "Book Section" if $type eq "book_section";
    $data->{0} = "Conference Paper" if $type eq "conference_item";
    $data->{0} = "Edited Book" if $type eq "book" && !$dataobj->is_set("creators") && $dataobj->is_set("editors");
    $data->{0} = "Journal Article" if $type eq "article";
    $data->{0} = "Patent" if $type eq "patent";
    $data->{0} = "Report" if $type eq "monograph";
    $data->{0} = "Thesis" if $type eq "thesis";

    if( $dataobj->exists_and_set("date") ) {
        $dataobj->get_value("date") =~ /^([0-9]{4})/;
        $data->{D} = $1;
    }

    $data->{J} = $dataobj->get_value("publication") if $type eq "article" && $dataobj->exists_and_set("publication");
    $data->{K} = $dataobj->get_value("keywords") if $dataobj->exists_and_set("keywords");
    $data->{T} = $dataobj->get_value("title") if $dataobj->exists_and_set("title");

    if( $dataobj->is_set("official_url") ) {
        $data->{U} = $dataobj->get_value("official_url");
    } else {
        $data->{U} = $dataobj->get_url;
    }

    $data->{X} = $dataobj->get_value("abstract") if $dataobj->exists_and_set("abstract");
    $data->{Z} = $dataobj->get_value("note") if $dataobj->exists_and_set("note");

    if( $type eq "thesis" && $dataobj->exists_and_set("thesis_type_display") ) {
        $data->{9} = $dataobj->get_value("thesis_type_display");
    }

    if( $dataobj->exists_and_set("creators") ) {
        foreach my $name ( @{ $dataobj->get_value("creators") } ) {
            push @{ $data->{A} }, EPrints::Utils::make_name_string( $name->{name}, 0 );
        }
    }

    if( $dataobj->exists_and_set("corp_creators") ) {
        foreach my $corp ( @{ $dataobj->get_value("corp_creators") } ) {
            push @{ $data->{A} }, $corp . ",";
        }
    }

    if( $type eq "conference_item" ) {
        $data->{B} = $dataobj->get_value("event_title") if $dataobj->exists_and_set("event_title");
        $data->{C} = $dataobj->get_value("event_location") if $dataobj->exists_and_set("event_location");
    } elsif( $type eq "thesis" ) {
        $data->{B} = $dataobj->get_value("department") if $dataobj->exists_and_set("department");
        $data->{C} = $dataobj->get_value("place_of_pub") if $dataobj->exists_and_set("place_of_pub");
    } elsif( $type eq "book" || $type eq "monograph" ) {
        $data->{B} = $dataobj->get_value("series") if $dataobj->exists_and_set("series");
        $data->{C} = $dataobj->get_value("place_of_pub") if $dataobj->exists_and_set("place_of_pub");
    } elsif( $type eq "book_section" ) {
        $data->{B} = $dataobj->get_value("book_title") if $dataobj->exists_and_set("book_title");
        $data->{S} = $dataobj->get_value("series") if $dataobj->exists_and_set("series");
    }

    if( $dataobj->exists_and_set("editors") ) {
        foreach my $name ( @{ $dataobj->get_value("editors") } ) {
            push @{ $data->{E} }, EPrints::Utils::make_name_string( $name->{name}, 0 );
        }
    }

    if( $type eq "monograph" || $type eq "thesis" ) {
        $data->{I} = $dataobj->get_value("institution") if $dataobj->exists_and_set("institution");
    } else {
        $data->{I} = $dataobj->get_value("publisher") if $dataobj->exists_and_set("publisher");
    }

    $data->{N} = $dataobj->get_value("number") if $dataobj->exists_and_set("number");

    if( $type eq "book" || $type eq "thesis" ) {
        $data->{P} = $dataobj->get_value("pages") if $dataobj->exists_and_set("pages");
    } else {
        $data->{P} = $dataobj->get_value("pagerange") if $dataobj->exists_and_set("pagerange");
    }

    $data->{V} = $dataobj->get_value("volume") if $dataobj->exists_and_set("volume");

    if( $type eq "article" ) {
        $data->{"@"} = $dataobj->get_value("issn") if $dataobj->exists_and_set("issn");
    } elsif( $type eq "book" || $type eq "book_section" ) {
        $data->{"@"} = $dataobj->get_value("isbn") if $dataobj->exists_and_set("isbn");
    }

    if( $dataobj->exists_and_set("id_number") && EPrints::DOI->parse( $dataobj->get_value("id_number"), ( test => 1 ) ) ) {
        $data->{R} = $dataobj->get_value("id_number");
    }

    if( $type eq "thesis" ) {
        my %relator_map = (
            "http://www.loc.gov/loc.terms/relators/THS" => "supervisor",
        );
        foreach my $contrib ( @{ $dataobj->get_value("contributors") || [] } ) {
            my $role = $relator_map{ $contrib->{type} };
            next unless defined $role && $role eq "supervisor";
            my $name_str = EPrints::Utils::make_name_string( $contrib->{name}, 0 );
            push @{ $data->{Y} }, $name_str if $name_str;
        }

        my $ethos_id = $dataobj->get_id;
        $data->{Z} .= "\nEThOS ID: $ethos_id";
    }

    $data->{F} = $plugin->{session}->get_repository->get_id . ":" . $dataobj->get_id;

    return $data;
}

sub output_dataobj {
    my( $plugin, $dataobj ) = @_;

    my $data = $plugin->convert_dataobj( $dataobj );

    my $out = "";
    foreach my $k ( sort { $a eq "0" ? -1 : $b eq "0" ? 1 : $a cmp $b } keys %{ $data } ) {
        if( ref( $data->{$k} ) eq "ARRAY" ) {
            foreach my $v ( @{ $data->{$k} } ) {
                $v =~ s/[\r\n]/ /g;
                $out .= "\%$k $v\n";
            }
        } else {
            my $v = $data->{$k};
            $v =~ s/[\r\n]/ /g;
            $out .= "\%$k $v\n";
        }
    }
    $out .= "\n";

    return $out;
}

1;
