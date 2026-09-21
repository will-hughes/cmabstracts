$c->{search}->{advanced} = 
{
	search_fields => [
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
	template => "default",
	preamble_phrase => "cgi/advsearch:preamble",
	title_phrase => "cgi/advsearch:adv_search",
	citation => "result",
	page_size => 100,
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"byname"  	 => "creators_name/-date/title",
		"bytitle" 	 => "title/creators_name/-date"
	},
	default_order => "byname",
	show_zero_results => 1,
};


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2024 University of Southampton.
EPrints 3.4 is supplied by EPrints Services.

http://www.eprints.org/eprints-3.4/

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints 3.4 L<http://www.eprints.org/>.

EPrints 3.4 and this file are released under the terms of the
GNU Lesser General Public License version 3 as published by
the Free Software Foundation unless otherwise stated.

EPrints 3.4 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints 3.4.
If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END









