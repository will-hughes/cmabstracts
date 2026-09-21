$c->{set_eprint_automatic_fields} = sub
{
    my( $eprint ) = @_;

    # Set ispublished default and construct thesis_type_display for thesis records
    if( $eprint->get_type eq "thesis" )
    {
        # Set ispublished to "pub" if not already set
        unless( $eprint->is_set( "ispublished" ) )
        {
            $eprint->set_value( "ispublished", "pub" );
        }

        # Construct thesis_type_display from thesis_name and ispublished
        my $thesis_name = $eprint->value('thesis_name') || '';
        my $ispublished = $eprint->value('ispublished') || 'pub';

        if( $thesis_name ne '' )
        {
            if( $ispublished eq 'unpub' )
            {
                $eprint->set_value('thesis_type_display', 'Unpublished ' . $thesis_name . ' thesis');
            }
            else
            {
                $eprint->set_value('thesis_type_display', $thesis_name . ' thesis');
            }
        }
    }
};