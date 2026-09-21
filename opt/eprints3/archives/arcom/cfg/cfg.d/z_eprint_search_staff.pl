$c->{datasets}->{eprint}->{search}->{staff} =
{
	search_fields => [
		{ meta_fields => [qw( eprintid )] },
		{ meta_fields => [qw( userid.username )] },
		{ meta_fields => [qw( userid.name )] },
		{ meta_fields => [qw( eprint_status )], default=>"archive buffer" },
		{ meta_fields => [qw( dir )] },
		{ meta_fields => [qw( eprintid )] },
		{ meta_fields => [ "title" ] },
		{ meta_fields => [ "creators_name" ] },
		{ meta_fields => [ "publication" ] },
		{ meta_fields => [ "abstract" ] },
		{ meta_fields => [ "volume" ] }, #do not try 'number' as it fails for some reason
		{ meta_fields => [ "date" ] },
		{ meta_fields => [ "issn" ] },
		{ meta_fields => [ "keywords" ] },
		{ meta_fields => [ "iterm" ] },
		{ meta_fields => [ "topic" ] },
		{ meta_fields => [ "subject" ] },
		{ meta_fields => [ "official_url" ] },
		{ meta_fields => [ "id_number" ] },
		{ meta_fields => [ "place_of_pub" ] },
		{ meta_fields => [ "institution" ] },
		{ meta_fields => [ "type" ] },
	],
	preamble_phrase => "Plugin/Screen/Staff/EPrintSearch:description",
	title_phrase => "Plugin/Screen/Staff/EPrintSearch:title",
	citation => "result",
	page_size => 200,
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"byname"  	 => "creators_name/-date/title",
		"bytitle" 	 => "title/creators_name/-date",
		"byeprintid_asc"  => "eprintid",
        "byeprintid_desc" => "-eprintid"
	},
	default_order => "byname",
	show_zero_results => 1,
	staff => 1,
};

