use strict;

# ---------------------------------------------------------------------------
# Related index terms block for abstract pages.
#
# WHY THIS EXISTS
# Index terms are assigned lexically: a controlled vocabulary matched against
# title, abstract and keywords. Frequent terms are therefore generic
# (methodology, construction industry, survey) and carry no discriminating
# power. Rare terms are specific to the subject matter. Selecting each
# record's rarest terms selects its most distinctive vocabulary, with no
# hand-maintained stop list to keep in step with the taxonomy.
#
# THRESHOLDS  (measured 14 Sep 2026: 6,153 terms over 30,239 records)
#   min_freq  3    Below this a link leads almost nowhere. 782 terms appear
#                  on exactly one record and would link back to this page.
#   max_freq  600  Above this the destination list is too large to be worth
#                  visiting, and the terms are generic (best practice 608,
#                  specification 680). Raised from 400 on 14 Sep 2026: terms
#                  identifying well-covered subjects sit just above 400
#                  (green building 486, sustainable construction 518). The
#                  401-600 band holds only 74 of 6,153 terms but lifts
#                  five-link coverage from 23,433 records to 25,741.
#   max_terms 5    23,433 records yield the full five; 106 yield none and
#                  correctly show no block at all.
#
# Re-measure these if the taxonomy is substantially revised.
#
# Called from citations/eprint/summary_page.xml as:
#   <epc:print expr="related_terms($item)"/>
# ---------------------------------------------------------------------------

$c->{related_terms} = {
	field     => "iterm",
	view      => "iterm",
	min_freq  => 3,
	max_freq  => 600,
	max_terms => 5,
};

# Term frequency table, built once per process on first use. Abstract pages
# are written in bulk by generate_abstracts, so one build serves the whole
# run of 30,000 records. No per-record query is made: a record's own terms
# come from the object already in memory.
my %FREQ;
my $FREQ_LOADED = 0;

sub _related_terms_freq
{
	my( $repo ) = @_;
	return \%FREQ if $FREQ_LOADED;

	my $conf    = $repo->config( "related_terms" );
	my $dataset = $repo->dataset( "eprint" );
	my $field   = $dataset->field( $conf->{field} );

	# Ask EPrints for the table and column names rather than hardcoding
	# them, so this survives a schema change or a 3.5 upgrade.
	my $table = $dataset->get_sql_sub_table_name( $field );
	my $col   = $field->get_sql_name;

	my $db  = $repo->database;
	my $sth = $db->prepare( "SELECT $col, COUNT(*) FROM $table GROUP BY $col" );
	$db->execute( $sth, [] );
	while( my( $term, $n ) = $sth->fetchrow_array )
	{
		$FREQ{$term} = $n;
	}
	$sth->finish;

	$FREQ_LOADED = 1;
	return \%FREQ;
}

sub EPrints::Script::Compiled::run_related_terms
{
	my( $self, $state, $eprint ) = @_;

	my $repo = $state->{session};
	my $xml  = $repo->xml;
	my $conf = $repo->config( "related_terms" );

	my $empty = $xml->create_document_fragment;

	my $item = $eprint->[0];
	return [ $empty, "XHTML" ] unless defined $item;

	my $terms = $item->value( $conf->{field} );
	return [ $empty, "XHTML" ] unless defined $terms;
	$terms = [ $terms ] unless ref( $terms ) eq "ARRAY";

	my $freq = _related_terms_freq( $repo );

	# Rarest first. Alphabetical as a tie-break so output is deterministic
	# and successive regenerations produce identical pages.
	my @usable =
		sort { $freq->{$a} <=> $freq->{$b} or $a cmp $b }
		grep {
			defined $freq->{$_}
			&& $freq->{$_} >= $conf->{min_freq}
			&& $freq->{$_} <= $conf->{max_freq}
		} @$terms;

	return [ $empty, "XHTML" ] unless @usable;

	@usable = @usable[ 0 .. $conf->{max_terms} - 1 ]
		if scalar(@usable) > $conf->{max_terms};

	require EPrints::Update::Views;

	my $div = $xml->create_element( "div", class => "cma_related" );
	$div->appendChild( $repo->html_phrase( "related_terms:heading" ) );

	my $ul = $xml->create_element( "ul", class => "cma_related_list" );
	foreach my $term ( @usable )
	{
		# Reproduce generate_views' filename rule by calling it, not by
		# copying it. abbr_path MD5s any component of 40 characters or
		# more, which affects 12 terms at present.
		my( $file ) = EPrints::Update::Views::abbr_path(
			EPrints::Utils::escape_filename( $term ) );

		my $a = $xml->create_element( "a",
			# Root-relative, so the link survives a domain change.
			href => $repo->config( "http_root" )
			        . "/view/" . $conf->{view} . "/" . $file . ".html",
			"data-umami-event" => "related-term",
		);
		$a->appendChild( $xml->create_text_node( $term ) );

		my $li = $xml->create_element( "li" );
		$li->appendChild( $a );
		$li->appendChild(
			$xml->create_text_node( " (" . $freq->{$term} . ")" ) );
		$ul->appendChild( $li );
	}

	$div->appendChild( $ul );
	return [ $div, "XHTML" ];
}