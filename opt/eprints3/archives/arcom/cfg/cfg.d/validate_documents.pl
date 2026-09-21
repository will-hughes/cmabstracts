$c->{validate_field} = sub {
    my ($field, $value, $session, $for_archive, $eprint) = @_;
    return () if $field->get_name eq "documents";
};