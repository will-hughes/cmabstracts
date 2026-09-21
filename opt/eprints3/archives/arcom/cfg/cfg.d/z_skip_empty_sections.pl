# 
# Custom grouping_function for the browse by author screens. 
# This eliminates empty letter groupings, skipping over sections with no values.
# Code suggested by David Newman
# This needs to be in a file under the archive's cfg/cfg.d/

$c->{group_by_a_to_z_hideempty} = sub {
    my $grouping = EPrints::Update::Views::group_by_n_chars(@_, 1);
    foreach my $c ('A'..'Z') {
        delete $grouping->{$c} unless defined $grouping->{$c};
    }
    return $grouping;
};

# Then set the grouping_function for the creators view under the creators_name menu to:
#
# grouping_function => "group_by_a_to_z_hideempty",