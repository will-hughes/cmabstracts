=head1 NAME

EPrints::Plugin::Import::RIS

Author: Stewart Brownrigg, University of Kent, 10 Feb 2012
Edited: Will Hughes, ARCOM, 15 Mar 2025 with specifics for EndNote RIS data
Edited: Will Hughes, ARCOM, 5 Jun 2026 to bring thesis citations into line with APA7 recommendations

(Ensured that A2 maps to editors for CONF and CPAPER)
=cut



package EPrints::Plugin::Import::RIS;

use EPrints::Plugin::Import::TextFile;
use strict;
use Data::Dumper;

our @ISA = ('EPrints::Plugin::Import::TextFile');

sub new {
    my( $class, %params ) = @_;
    my $self = $class->SUPER::new( %params );
    $self->{name} = 'ARCOM (RIS format)';
    $self->{visible} = 'all';
    $self->{produce} = [ 'list/eprint' ];
    return $self;
}

sub input_fh {
    my( $plugin, %opts ) = @_;
    my @ids;
    my $fh = $opts{fh}; # File handle
    binmode($fh, ":encoding(UTF-8)") or die "Can't set encoding: $!";
    my $file_content = do { local $/; <$fh> };
    $file_content =~ s/\r\n/\n/g;
    $file_content =~ s/\r/\n/g;
    my @file = split(/\n/, $file_content);
    if (@file) {
        $file[0] =~ s/^\x{FEFF}//;
    }
    my (%record, @records);
    my $lastkey = undef;
    foreach my $row (@file) {
        next if $row =~ /^\s*$/;
        if ($row =~ /^([A-Z0-9]{2})\s\s-\s(.*)$/) {
            my ($key, $value) = ($1, $2);
            if ($key eq 'ER') {
                my $epdata = $plugin->convert_input(\%record);
                %record = ();
                $lastkey = undef;
                next unless defined $epdata;
                my $dataobj = $plugin->epdata_to_dataobj($opts{dataset}, $epdata);
                push @ids, $dataobj->get_id if defined $dataobj;
            } else {
                push @{$record{$key}}, $value;
                $lastkey = $key;
				}
        } elsif (defined $lastkey) {
            push @{$record{$lastkey}}, $row;
			}
    }
    return EPrints::List->new(
        dataset => $opts{dataset},
        session => $plugin->{session},
        ids => \@ids
    );
}

sub convert_input
{
	my ( $plugin, $entry ) = @_;
 	my ( $epdata ) = ();
 	my ( $unmapped ) = [];
 	my $eptypes = { # hash table for mapping RIS types to EPrint types
            'ABST'   => 'article',
            'EJOUR'  => 'article',
            'JFULL'  => 'article',
            'JOUR'   => 'article',
            'MAG'    => 'article',
            'MGZN'   => 'article',
            'NEWS'   => 'article',
            'BOOK'   => 'book',
            'EBOOK'  => 'book',
            'EDBOOK' => 'book',
            'CONF'   => 'conference_item',
            'CPAPER' => 'conference_item',
            'CHAP'   => 'book_section',
            'DATA'   => 'dataset',
            'AGGR'   => 'dataset',
            'DBASE'  => 'dataset',
            'RPRT'   => 'monograph',
            'PAT'    => 'patent',
            'THES'   => 'thesis',
            'SLIDE'  => 'image',
            'MUSIC'  => 'audio',
            'SOUND'  => 'audio',
            'VIDEO'  => 'video',
            'BLOG'   => 'artefact',
            'MULTI'  => 'artefact',
            'ELEC'   => 'artefact',
            'PAMP'   => 'monograph',
            'PAT'    => 'patent',
            'INPR'   => 'other',
            'UNPB'   => 'other',
            'GEN'    => 'other'
 	};

    foreach my $type ( @{ $entry->{TY} } )
    {
        if ( !defined $eptypes->{$type} )
        {
            $type = 'GEN';
        }

        $epdata->{type} = $eptypes->{$type};  # map RIS types to EPrint types

        # Process reviews first
        if ( defined $entry->{RI} && defined $entry->{C4} && !grep /$type/, ('MPCT','GRANT') )
        {
            $epdata->{type} = 'review';
            $type = 'REVIEW';
        }

        #
        # Process other type-dependent fields
        # Add exceptions to the norm here
        # General catch-all rules are declared outside this look
        #

        # Process authors, creators, editors, etc. Mapping varies according to type
        &_process_names($epdata, $entry, $type);

        # Date type/publication status - published, submitted or completion (unused)
        if ( grep /$type/, ('UNPB','INPR','RPRT') )
        {
            $epdata->{date_type} = 'submitted';

            if ( $type eq 'INPR' )
            {
                $epdata->{ispublished} = 'inpress';
            }
            elsif ( $type eq 'UNPB' )
            {
                $epdata->{ispublished} = 'unpub';
            }
            else
            {
                $epdata->{ispublished} = 'submitted';
            }
        }
        else
        {
            $epdata->{date_type} = 'published';
            $epdata->{ispublished} = 'pub';
        }

        # CY - Place of publication / Location of conference (event) & C3 Event dates
        if ( grep /$type/, ('CPAPER','CONF') )
        {
            &_join_field_data($epdata, $entry, 'CY', 'event_location', ', ');
            &_join_field_data($epdata, $entry, 'C3', 'event_dates', ', ');
        }

        # IS - Number of volumes CHAP otherwise Issue
        if ( grep /$type/, ('CHAP') )
        {
            &_join_field_data($epdata, $entry, 'IS', 'num_pieces', ', ');
        }

        # SN - ISSN
        if ( grep /$type/, ('ABST','INPR','JFULL','JOUR','AGGR','DATA', 'EJOUR','MGZN', 'MUSIC','NEWS' ) )
        { 
            &_join_field_data($epdata, $entry, 'SN', 'issn', '; ');
        }

        # VL - Volume / Other
        if ( grep /$type/, ('BLOG','THES') )
        {
            &_store_unmapped($epdata, $entry, 'VL', $unmapped );
        }
        elsif ( grep /$type/, ('CHART','EQUA','FIGURE') )
        {
            &_join_field_data($epdata, $entry, 'VL', 'size', ', ');
            &_store_unmapped($epdata, $entry, 'A2', $unmapped, 'Field not mapped to EPrints' );
        }

        # T2 - Book/Volume title / Series title / Publication / Conference name
        if ( grep /$type/, ('CPAPER','CONF','HEAR','UNPB' ) )
        { 
            &_join_field_data($epdata, $entry, 'T2', 'event_title');
        }
        elsif ( grep /$type/, ('CHAP','ECHAP','ENCYC','EQUA','FIGURE','MUSIC') )
        {
            &_join_field_data($epdata, $entry, 'T2', 'book_title', ', ');
        }
        elsif ( grep /$type/, ('BOOK', 'CTLG','CLSWK','COMP','MPCT','MAP','UNPB','ELEC') ) # added conf to populate equiv in views
        {
            &_join_field_data($epdata, $entry, 'T2', 'series', ', ');
        }

		# THES - type specific 
		if ( $type eq 'THES' )
			{
			&_join_field_data($epdata, $entry, 'T2', 'department');
			&_join_field_data($epdata, $entry, 'PB', 'institution');
			&_names($epdata, $entry, ['A2'], 'contributors', 'thesis_advisor'); # EndNote must export thesis advisor in A2 or multiple names not properly rendered.

			# Make a deep copy of the M3 field before calling _join_field_data
			my $m3 = $entry->{'M3'} ? [ @{$entry->{'M3'}} ] : undef;

			# Pass the copy of M3 to _join_field_data to avoid modifying the original
			&_join_field_data($epdata, { %$entry, 'M3' => $m3 }, 'M3', 'thesis_type_display');

			$epdata->{date_type} = 'completed';
			$epdata->{thesis_type} = 'doctoral';

			# Process the M3 field for thesis-specific details
			if ( defined $m3->[0] ) {
				# Extract words from M3 field (trim leading/trailing spaces)
				my @words = split(/\s+/, $m3->[0] =~ s/^\s+|\s+$//gr);
				
				# Determine ispublished based on first word
				# Only 'Unpublished' as first word triggers unpub; everything else is pub
				if ( lc($words[0]) eq 'unpublished' ) {
					$epdata->{ispublished} = 'unpub';
					$epdata->{thesis_name} = $words[1];
					$epdata->{thesis_type_display} = join(' ', @words[1..$#words]);
				} else {
					$epdata->{ispublished} = 'pub';
					$epdata->{thesis_name} = $words[0];
					$epdata->{thesis_type_display} = join(' ', @words);
				}
			}
			
			# Clear M3 in $epdata and $entry to prevent it from being interpreted as "Unmapped bibliographic data"
			$entry->{M3} = undef;   # Set the key to undef instead of deleting it
			}
		
		# T3 - Tertiary title / Series title / Corporation
		if ( grep /$type/, ('BILL','BLOG','HEAR','UNPB' ) )
			{ 
			&_push_array_field_data($epdata, $entry, 'T3', 'corp_creators');
			}
	delete $entry->{TY};
	}

    # The rest: not type dependent, or left over after picking out specific cases above

    # Title
    &_join_multiple_field_data($epdata, $entry, ['T1','TI'], 'title');

    # Publication title
    &_join_multiple_field_data($epdata, $entry, ['T2', 'JF'], 'publication', ', ');

    # Series title
    &_join_field_data($epdata, $entry, 'T3', 'series', ', ');

    # Abstract
    &_join_multiple_field_data($epdata, $entry, ['AB','N2'], 'abstract');

    # Caption
    &_join_field_data($epdata, $entry, 'CA', 'commentary', ', ');

    # source repository id of bib information
    &_join_field_data($epdata, $entry, 'ID', 'original_repository_id');

    # source repository of bib information
    &_join_field_data($epdata, $entry, 'NV', 'num_pieces');

    # NV - Number of volumes
    &_join_field_data($epdata, $entry, 'SO', 'original_repository');

    # keywords
    &_join_field_data($epdata, $entry, 'KW', 'keywords', ', ');
    
    # CY - Place of publication
    &_join_field_data($epdata, $entry, 'CY', 'place_of_pub', ', ');

    # DOI / NIHMSID / CFDA / PMCID
    &_return_first_value($epdata, $entry, ['DO','C6'], 'id_number', $unmapped);

    # SN - ISBN (ISSN are caught earlier
    &_join_field_data($epdata, $entry, 'SN', 'isbn', '; ');

    # UR - URL
    &_process_urls($epdata, $entry);

    # PB - Publisher
    &_join_field_data($epdata, $entry, 'PB', 'publisher', ', ');

    # M1/IS - Issue number
    &_join_multiple_field_data($epdata, $entry, ['IS','M1'], 'number', ', ');

    # VL - Volume numbering
    &_join_field_data($epdata, $entry, 'VL', 'volume', ', ');

    # RI - Reviewed item
    &_join_field_data($epdata, $entry, 'RI', 'reviewed_item', ', ');


    # Check if SP is defined; if not, skip the SP/EP processing
    if (defined $entry->{SP}) {
        # SP/EP - Pages & pagerange. Pages can be in format:
        #    SP  - [start page]-[end page]
        # or SP  - [start page];  EP  - [end page]

        my $sp = defined $entry->{SP} ? join('', @{$entry->{SP}}) : undef;
        delete $entry->{SP};
        my $ep = defined $entry->{EP} ? join('', @{$entry->{EP}}) : undef;
        delete $entry->{EP};
		
		# Replace Unicode en/em dashes with ASCII hyphen (from ChatGPT 1 Jul 2025 - WPH)
		$sp =~ s/[\x{2013}\x{2014}]/-/g if defined $sp;
		$ep =~ s/[\x{2013}\x{2014}]/-/g if defined $ep;

        if ( $sp =~ /^[0-9]*-[0-9]*$/ )
        {
            $epdata->{pagerange} = $sp;
            my ($start_page, $end_page) = split(/-/, $sp);
            $epdata->{pages} = ($end_page - $start_page) + 1;
        }
        elsif ( defined $ep )
        {
            $epdata->{pagerange} = "$sp-$ep";
            $epdata->{pages} = ($ep - $sp) + 1;
        }
        elsif ( defined $sp )
        {
            $epdata->{pages} = int $sp;
        }
    }
    elsif (defined $entry->{C7}) {
    my $c7 = join('', @{$entry->{C7}});
    delete $entry->{C7};
    $epdata->{article_number} = $c7;  # Pick up article number for use as start page (WH 4 Jun 2025)
}
    
    # Date of publication - Take the first 4 digit match
    &_process_dates($epdata, $entry, ['PY','Y1','Y2','DA'], $unmapped);

    &_join_field_data($epdata, $entry, 'N1', 'note');

    # Process any leftovers and add $unmapped fields to the notes field
    &_process_unmapped($epdata, $entry, $unmapped);

    if ( $epdata ->{type} eq "conference_item" ) # WH This sets defaults for this type
    {
        $epdata->{pres_type} = "paper";
        $epdata->{event_type} = "conference";
 #       $epdata->{publication_browse_name} = "Conference paper";    # This is not a defined variable yet (24 Feb 2025)
    }

# This was the devil in the detail that changed ispublished to 'pub' (WH 14 Mar 2024)
#    if ( $epdata ->{type} eq "thesis" ) # This sets defaults for this type
#    {
#        $epdata->{ispublished} = "pub";
 #       $epdata->{publication_browse_name} = "Thesis";
 #   }

    $epdata->{eprint_status} //= 'buffer'; # Set default eprint_status if not defined
    return $epdata;
}


sub _store_unmapped
{
    my ( $epdata, $entry, $risfield, $unmapped, $reason ) = @_;

    foreach my $field_value ( @{$entry->{$risfield}} )
    {
        if ( @{$unmapped} == 0 )
        {
            push @{$unmapped}, 'Unmapped bibliographic data:';
        }

        push @{$unmapped}, "$risfield  - $field_value [$reason]";
    }
    delete $entry->{$risfield};
}

sub _process_unmapped
{
    # append unmapped fields to the notes field

    my ( $epdata, $entry, $unmapped ) = @_;

    foreach my $risfield (keys %{$entry})
    {
        if ($risfield =~ /[a-z0-9]/i)
        {
            foreach my $risstring (@{$entry->{$risfield}})
            {
                &_store_unmapped( $epdata, $entry, $risfield, $unmapped, 'Field not mapped to EPrints' );
            }
        }
    }

    if ( @{$unmapped} > 0 )
    {
        my $string = join("\r\n", @{$unmapped});
        defined $epdata->{note}
            ? $epdata->{note} .= "\r\n" . $string
            : $epdata->{note} = $string;
    }
}


sub _process_urls
{
#    If there are multiple URLs then the first one goes in official_url, other into related urls  
# 
#     _join_field_data(
#         array ref <eprint data>, (required)
#         array ref <RIS data>, (required)
#     );

    my ( $epdata, $entry ) = @_;

    foreach my $url ( @{ $entry->{UR} } )
    {
        if ( defined $epdata->{official_url} )
        {
            push @{$epdata->{related_url}}, { url => $url} ;
        }
        else
        {
            $epdata->{official_url} = $url;
        }
    }
    delete $entry->{UR};
}

sub _process_dates
{
    my ( $epdata, $entry, $risfields, $unmapped ) = @_;
    foreach my $risfield ( @{$risfields} )
    {
        # continue until we have $epdata->{date_year} - don't bother looping through arrays - get
        # first date and store the rest
        foreach my $date_string (@{$entry->{$risfield}})
        {
            if ( !defined $epdata->{date_year} )
            {
                my ($year, $month, $day, $other) = split('/', $date_string);
                $epdata->{date}  = $year if $year =~ /^[0-9]{4}$/;
                $epdata->{date} .= '-' . $month if defined $month && $month =~ /^[0-9]{2}$/;
                $epdata->{date} .= '-' . $day if defined $day && $day =~ /^[0-9]{2}$/;
                if ( defined $other )
                {
                    &_store_unmapped( $epdata, $entry, $risfield, $unmapped, 'EPrints field already has value set' );
                }
            }
            else
            {
                &_store_unmapped( $epdata, $entry, $risfield, $unmapped, 'EPrints field already has value set' );
            }
        }
        delete $entry->{$risfield};
    }
}

sub _return_first_value
{
#    Take an array of RIS fields and pass back the first value encountered.
#    Useful for sifting through a prioritised list of fields looking for a single value, where we 
#    are certain that there is little chance of subsequent values - and if there are, of little
#    value
#
#     _return_first_value
#     (
#         $epdata    array ref        <eprint data>                     (required)
#         $entry     array ref        <RIS data>                        (required)
#         $risfields array ref        <RIS field names to parse>        (required)
#         $epfield   string           <destination EPrint fieldname>    (required)
#         $unmapped  array ref        <array to store unused values>    (required)
#     );
    my ( $epdata, $entry, $risfields, $epfield, $unmapped ) = @_;

    foreach my $risfield ( @{$risfields} )
    {
        if ( defined $entry->{$risfield} && !defined $epdata->{$epfield} )
        {
            $epdata->{$epfield} = $entry->{$risfield}[0];
            delete $entry->{$risfield};
        }
        else
        {
            &_store_unmapped( $epdata, $entry, $risfield, $unmapped, 'EPrints field already has value set' );
        }
    }
}

sub _join_multiple_field_data
{
#    append RIS fields for multiple fields types, where each field type could have more than
#      one value (i.e. on multiple lines)
# 
#     _join_field_data
#     (
#         array ref <eprint data>, (required)
#         array ref <RIS data>, (required)
#         string <RIS fields to parse>, (required)
#         string <destination EPrint field>, (required)
#         string <separator> (NULL allowed)
#     );

    my ( $epdata, $entry, $risfields, $epfield, $separator ) = @_;
    $separator //= ''; # Default to an empty string if $separator is undefined
    my @values = ();

    foreach my $risfield ( @{$risfields} )
    {
        if ( defined $entry->{$risfield} )
        {
            push @values, join($separator, @{$entry->{$risfield}});
            delete $entry->{$risfield};
        }
    }

    $epdata->{$epfield} = join($separator, @values) if @values > 0;
}

sub _join_field_data
{
#    append RIS fields where field type could have more than one value (i.e. on multiple lines)  
# 
#     _join_field_data
#     (
#         array ref <eprint data>, (required)
#         array ref <RIS data>, (required)
#         string or array <RIS fields to parse>, (required)
#         string <destination EPrint field>, (required)
#         string <separator> (NULL allowed)
#     );

    my ( $epdata, $entry, $risfield, $epfield, $separator ) = @_;
    $separator //= ''; # Default to an empty string if $separator is undefined
    if ( defined $entry->{$risfield} )
    {
        $epdata->{$epfield} = join($separator, @{$entry->{$risfield}});
        delete $entry->{$risfield};
    }
}

sub _push_array_field_data
{
#    append RIS fields where field type could have more than one value (i.e. on multiple lines)  
# 
#     _join_field_data
#     (
#         array ref <eprint data>, (required)
#         array ref <RIS data>, (required)
#         string or array <RIS fields to parse>, (required)
#         string <destination EPrint field>, (required)
#         string <separator> (NULL allowed)
#     );

    my ( $epdata, $entry, $risfield, $epfield ) = @_;

    foreach my $risstring ( @{$entry->{$risfield}} )
    {
        push @{$epdata->{$epfield}}, $risstring;
        delete $entry->{$risfield};
    }
}

sub _process_names
{
#     names get converted differently depending on the publication type
#
#     _process_names
#     (
#         array ref <eprint data>, (required)
#         array ref <RIS data>, (required)
#         string <document type> (required)
#     );

    my ( $epdata, $entry, $type ) = @_;

    # Primary authors - catch reviewers first
    if ( grep /$type/, ('REVIEW') )
    {
        &_names($epdata, $entry, ['C5'], 'creators');
        &_names($epdata, $entry, ['AU','A1'], 'ri_creator');
    }
    else
    {
        &_names($epdata, $entry, ['AU','A1'], 'creators');
    }

    # secondary/tertiary authors
    if ( grep /$type/, ('BILL','CONF') )
    {
        &_names($epdata, $entry, ['A2'], 'contributors', 'sponsor');
    }
    elsif ( grep /$type/, ('CONF','CPAPER') )
    {
        &_names($epdata, $entry, ['A2'], 'contributors', 'editor');
    }
    elsif ( grep /$type/, ('ADVS','SLIDE','SOUND','VIDEO') )
    {
        &_names($epdata, $entry, ['A2'], 'contributors', 'performer');
    }
    elsif ( grep /$type/, ('BLOG') )
    {
        &_names($epdata, $entry, ['A3'], 'contributors', 'illustrator');
    }
    elsif ( grep /$type/, ('CASE') )
    {
        &_names($epdata, $entry, ['A2'], 'contributors', 'reporter');
        &_names($epdata, $entry, ['A3','A4'], 'contributors', 'other');
    }
    elsif ( grep /$type/, ('THES') )
    {
        &_names($epdata, $entry, ['A3'], 'contributors', 'thesis_advisor');
    }
    elsif ( grep /$type/, ('DATA','MUSIC') )
    {
        &_names($epdata, $entry, ['A2'], 'contributors', 'producer');
    }
    elsif ( grep /$type/, ('MPCT') )
    {
        &_names($epdata, $entry, ['A2'], 'contributors', 'director');
        &_names($epdata, $entry, ['A3'], 'contributors', 'producer');
        &_names($epdata, $entry, ['A4'], 'contributors', 'performer');
    }
    elsif ( grep /$type/, ('PCOMM','ICOMM') )
    {
        &_names($epdata, $entry, ['A2'], 'contributors', 'receipient');
    }
    else
    {
        &_names($epdata, $entry, ['A2','A3'], 'editors');
        &_names($epdata, $entry, ['A4'], 'contributors', 'translator');
    }
}

sub _names
{
#     _names(
#         array ref <eprint data>, (required)
#         array ref <RIS data>, (required)
#         array ref <name fields to parse>, (required)
#         string <destination EPrint field>, (required)
#         string <contributor type> (NULL allowed)
#     );

    my ( $epdata, $entry, $risfields, $epfield, $contributor_type ) = @_;
	
	    # list of contributor types taken from the EPrints contributor_type namedset
    my $contributor_types =
    {
        'translator' => 'http://www.loc.gov/loc.terms/relators/TRL',
        'performer' => 'http://www.loc.gov/loc.terms/relators/PRF',
        'Reporter' => 'http://www.loc.gov/loc.terms/relators/RPT',
        'Sponsor' => 'http://www.loc.gov/loc.terms/relators/SPN',
        'Other' => 'http://www.loc.gov/loc.terms/relators/OTH',
        'Producer' => 'http://www.loc.gov/loc.terms/relators/PRO',
        'Director' => 'http://www.loc.gov/loc.terms/relators/DRT',
        'Recipient' => 'http://www.loc.gov/loc.terms/relators/RCP',
        'editor' => 'http://www.loc.gov/loc.terms/relators/EDT',  # Add editor type
        'thesis_advisor' => 'http://www.loc.gov/loc.terms/relators/THS',  # Add thesis_advisor type
		
    };
    my @names = ();

    foreach my $risfield ( @{$risfields} )
    {
        foreach my $risstring ( @{ $entry->{$risfield} } )
        {
           if ( $risstring !~ m/,/ )
            {
                # Corporate bodies can be authors.  This is a crude test: if no comma then assume is
                # corporation (not accurate as could match creators with a single name, or
                # ignore corporations with comma in their name).  This is best guess.
                push @{$epdata->{corp_creators}}, $risstring;
            }
            else
            {
                my $name = {};
                next unless my ( $family, $given, $lineage ) = split(/,/, $risstring);
                $name->{name} = { family => $family, given => $given, lineage => $lineage };
                if ( defined($contributor_type) && $epfield eq 'contributors' )
                {
                    $name->{type} = $contributor_types->{$contributor_type};
                }
                push @names, $name;
            }
        }
        delete $entry->{$risfield};
    }

    if ( @names > 0 )
    {
        push @{$epdata->{$epfield}}, @names;
    }
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END


