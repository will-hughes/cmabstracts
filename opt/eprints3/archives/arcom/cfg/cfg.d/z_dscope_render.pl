# Renders the dscope code (e.g. "3 PCT") as a sentence on abstract pages.
# Wording lives in phrases: dscope_summary_{none,one,many,all} and dscope_label_{P,C,T,E,A}.
# Browse view headings are unaffected: Views.pm uses render_single_value, not render_value.

$c->{dscope_render_value} = sub
{
    my( $repo, $field, $value, $alllangs, $nolink, $object ) = @_;

    return $repo->make_doc_fragment
        unless defined $value && $value =~ /^(\d)\s*([PCTEA]*)$/;
    my( $n, $letters ) = ( $1, $2 );

    my @labels = map { $repo->phrase( "dscope_label_$_" ) } split //, $letters;
    my $list = @labels > 1
        ? join( ', ', @labels[0 .. $#labels - 1] ) . ' and ' . $labels[-1]
        : ( $labels[0] // '' );

    my $id = $n == 0 ? 'dscope_summary_none'
           : $n == 1 ? 'dscope_summary_one'
           : $n == 5 ? 'dscope_summary_all'
           :           'dscope_summary_many';

    return $repo->html_phrase( $id,
        count    => $repo->make_text( $n ),
        elements => $repo->make_text( $list ),
    );
};