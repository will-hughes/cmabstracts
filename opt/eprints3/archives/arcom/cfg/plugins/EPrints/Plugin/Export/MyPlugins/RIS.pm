package EPrints::Plugin::Export::MyPlugins::RIS;

@ISA = ('EPrints::Plugin::Export');

use strict;

sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);

    $self->{name}        = 'ARCOM-RIS';
    $self->{accept}      = [ 'dataobj/eprint', 'list/eprint' ];
    $self->{visible}     = 'all';
    $self->{suffix}      = '.ris';
    $self->{mimetype}    = 'text/plain';
    $self->{disposition} = 'attachment';

    return $self;
	}

sub output_file_name {
    my ($plugin, $list) = @_;
    return "arcom.ris";
	}

sub output_dataobj {
	my ($plugin, $eprint) = @_;
	my $ris = "";
		
	# TY - Reference Type
	my $type = $eprint->get_type;
	my $ty = "GEN";  # Default fallback

	$ty = "JOUR" if $type eq "article";
	$ty = "BOOK" if $type eq "book";
	$ty = "CHAP" if $type eq "book_section";
	$ty = "CONF" if $type eq "conference_item";
	$ty = "RPRT" if $type eq "monograph";
	$ty = "PAT"  if $type eq "patent";
	$ty = "THES" if $type eq "thesis";

	$ris .= "TY  - $ty\n";

	# TI - Title of article
	$ris .= "TI  - " . ($eprint->get_value("title") || "") . "\n";

	# AU Authors
	if( $eprint->exists_and_set( "creators" ) )
	{
		foreach my $creator ( @{ $eprint->get_value( "creators" ) } )
		{
			my $name_str = "";
			if (ref($creator) eq "HASH" && exists $creator->{name}) {
				$name_str = EPrints::Utils::make_name_string( $creator->{name}, 0 );
			}
			$ris .= "AU  - $name_str\n" if $name_str;
		}
	}
	
	# AB - Abstract
	$ris .= "AB  - " . ($eprint->get_value("abstract") || "") . "\n";

	# UR - Official URL
	if( $eprint->is_set("official_url") )
		{
			$ris .= "UR  - " . $eprint->get_value("official_url") . "\n";
		}

	# DO - DOI
		if( $eprint->is_set("id_number") )
		{
			$ris .= "DO  - " . $eprint->get_value("id_number") . "\n";
		}

	# T2, VL, IS - Journal Info (only if type is 'article')
	if( $type eq "article" )
	{
		if( $eprint->is_set("publication") )
		{
			$ris .= "T2  - " . $eprint->get_value("publication") . "\n";
		}
		if( $eprint->is_set("volume") )
		{
			$ris .= "VL  - " . $eprint->get_value("volume") . "\n";
		}
		if( $eprint->is_set("number") )
		{
			$ris .= "IS  - " . $eprint->get_value("number") . "\n";
		}
	}

	# T2, PB, CY, C3 (only if type is 'CONF'
	$type = $eprint->get_type;
	if ( $type eq "conference_item" )
	{
		# T2 - Conference name
		$ris .= "T2  - " . ($eprint->get_value("event_title") || "") . "\n";

		# PB - Publisher
		$ris .= "PB  - " . ($eprint->get_value("publisher") || "") . "\n";

		# CY - Event location
		$ris .= "CY  - " . ($eprint->get_value("event_location") || "") . "\n";

		# C3 - Event dates
		$ris .= "C3  - " . ($eprint->get_value("event_dates") || "") . "\n";

	}

	# THESIS-specific fields
	if( $type eq "thesis" )
	{
	# Supervisors -> A2
    my %relator_map = (
        "http://www.loc.gov/loc.terms/relators/THS" => "supervisor",
        # add more mappings here if needed
    );
    foreach my $contrib ( @{ $eprint->get_value( "contributors" ) || [] } )
    {
        my $role = $relator_map{ $contrib->{type} };
        next unless defined $role && $role eq "supervisor";

        my $name_str = EPrints::Utils::make_name_string( $contrib->{name}, 0 );
        $ris .= "A2  - $name_str\n" if $name_str;
    }
    # M3 - Full thesis type display
    if( $eprint->exists_and_set( "thesis_type_display" ) )
    {
        $ris .= "M3  - " . $eprint->get_value( "thesis_type_display" ) . "\n";
    }
    # PB - Institution
    if( $eprint->exists_and_set( "institution" ) )
    {
        $ris .= "PB  - " . $eprint->get_value( "institution" ) . "\n";
    }
    # CY - Place of publication
    if( $eprint->exists_and_set( "place_of_pub" ) )
    {
        $ris .= "CY  - " . $eprint->get_value( "place_of_pub" ) . "\n";
    }
    # CN - External reference
    $ris .= "CN  - EThOS ID: " . $eprint->get_id . "\n";
	}


	# A2 - Editors (from contributors of type 'editor')
	if( $type eq "book" || $type eq "book_section" || $type eq "conference_item" || $type eq "monograph" )
	{
		if( $eprint->exists_and_set( "contributors" ) )
		{
			my %relator_map = (
				"http://www.loc.gov/loc.terms/relators/EDT" => "editor",
				# add additional roles here if needed
			);

			foreach my $c ( @{ $eprint->get_value( "contributors" ) } )
			{
				my $role = $relator_map{ $c->{type} };
				next unless defined $role && $role eq "editor";

				my $name_str = EPrints::Utils::make_name_string( $c->{name}, 0 );
				$ris .= "A2  - $name_str\n" if $name_str;
			}
		}
	}


	# PY - Year (from 'date' field)
	if( $eprint->is_set("date") )
	{
		my $date = $eprint->get_value("date");
		if( $date =~ /^(\d{4})/ )
		{
			$ris .= "PY  - $1\n";
		}
	}

	#SP-EP Page range
	if( $eprint->exists_and_set( "pagerange" ) )
	{
		my $pagerange = $eprint->get_value( "pagerange" );
		if( $pagerange =~ /^(.*?)\s*-\s*(.*?)$/ )
		{
			$ris .= "SP  - $1\n" if defined $1;
			$ris .= "EP  - $2\n" if defined $2;
		}
	}
	elsif( $eprint->exists_and_set( "pages" ) )
	{
		my $pages = $eprint->get_value( "pages" );
		$ris .= "EP  - $pages\n" if defined $pages;
	}

	#Keywords
	my $kw = $eprint->get_value("keywords");
	if (ref($kw) eq "ARRAY") {
		foreach my $k (@$kw) {
			$ris .= "KW  - $k\n";
			}
	}
	elsif (defined $kw) {
		my @kw_array = split /\s*;\s*/, $kw;
		foreach my $k (@kw_array) {
			$ris .= "KW  - $k\n";
			}
	}

	# N1 - Note
	if( $eprint->is_set("note") )
	{
		$ris .= "N1  - " . $eprint->get_value("note") . "\n";
	}

	# ID - Unique Reference ID
	my $repo_id = $plugin->{session}->get_repository->get_id;
	my $eprint_id = $eprint->get_id;
	$ris .= "ID  - ${repo_id}${eprint_id}\n";

	# ER - End of record, incl space and extra para break
	$ris .= "ER  - \n\n";

	return $ris;
}

1;
