package TaxMatch;

# Shared taxonomy matching engine.
# Used by both taxindex.pl (production) and test_taxindex.pl (tests),
# so the two can never disagree about how matching works.

use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(build_lookup find_lwords);

# Build the clean-to-original map and the compiled matching regex.
# Input:  hashref whose KEYS are the original lookup words.
# Output: (\%clean_to_original, $compiled_regex)
sub build_lookup {
    my ($lookup_terms) = @_;

    my %clean_to_original;
    foreach my $orig_lword (keys %$lookup_terms) {
        my $clean_lword = lc($orig_lword);
        $clean_lword =~ s/['"]//g;   # remove quotes
        $clean_lword =~ s/\s+/ /g;   # normalize spaces
        $clean_to_original{$clean_lword} = $orig_lword;

        # ============================================================
        # PLURAL RULES.
        # Comment out this block to stop resolving plural lwords to singular index terms
        # Irregular plurals other than (?:s|es)? must be mapped as lwords in the taxonomy
        # This lookup only deals with plurals in the last word of an lword phrase
        if ($clean_lword =~ /[bcdfghjklmnpqrstvwxz]y$/) {
            # consonant + y -> ies   (strategy -> strategies)
            (my $ies = $clean_lword) =~ s/y$/ies/;
            $clean_to_original{$ies} = $orig_lword;
        }
        elsif ($clean_lword =~ /sis$/) {
            # sis -> ses             (analysis -> analyses)
            (my $ses = $clean_lword) =~ s/sis$/ses/;
            $clean_to_original{$ses} = $orig_lword;
        }
        # ============================================================

        # ============================================================
        # Z-SPELLING RESOLUTION  (-ization / -izational).
        # Comment out this block to revert to no s/z spelling handling.
        # The index terms are regularized to z spelling (-ization, -izational).
        # This lookup deals with individual words in an lword phrase
        #
        # All other s/z clashes require paired lookup words matching to common index terms:
        # organize/organise, analyze/analyse and -izing/-ising
        #
        if ($clean_lword =~ /ization(?:al)?\b/) {
            (my $s_form = $clean_lword) =~ s/izational\b/isational/g;
            $s_form =~ s/ization\b/isation/g;
            $clean_to_original{$s_form} = $orig_lword;
        }
        # ============================================================

        # ============================================================
        # HYPHEN / SPACE RESOLUTION.
        # Comment out this block to match hyphenated lwords on the hyphen only
        # For any lword with a hyphen, a spaced variant resolves to the same index term
        # Hyphens only; slashes and closed (no-space) forms are not generated
        if (index($clean_lword, '-') >= 0) {
            (my $spaced = $clean_lword) =~ s/-/ /g;
            $clean_to_original{$spaced} = $orig_lword;
        }
        # ============================================================

        # ============================================================
        # US SPELLING RESOLUTION.
        # Comment out this block to stop matching US spellings of UK lwords
        # Index terms are UK spelling; this generates the US variant as a key
        # Whole words only, so modeling resolves but remodeling does not
        # Add pairs as UK => US; words not listed need their own taxonomy row
        my %us_variant = (
            neighbourhood => 'neighborhood',
            labour        => 'labor',
            modelling     => 'modeling',
            behaviour     => 'behavior',
            fibre         => 'fiber',
            centre        => 'center',
            centred       => 'centered',
            ageing        => 'aging',
            harbor        => 'harbour',
            defence       => 'defense',
        );
        (my $us_form = $clean_lword) =~ s/\b(\w+)\b/$us_variant{$1} || $1/ge;
        $clean_to_original{$us_form} = $orig_lword if $us_form ne $clean_lword;
        # ============================================================
    }

    # Longer phrases first so they match before their shorter substrings.
    my $all = join('|',
        map  { quotemeta($_) }
        sort { length($b) <=> length($a) }
        keys %clean_to_original);

    my $regex = qr/\b($all)(?:s|es)?\b/i;
    return (\%clean_to_original, $regex);
}

# Return the set of original lwords present in $text (no duplicates).
sub find_lwords {
    my ($text, $clean_to_original, $regex) = @_;
    my %seen;
    my $t = lc($text);
    while ($t =~ /$regex/g) {
        my $w = lc($1);
        $seen{ $clean_to_original->{$w} } = 1 if exists $clean_to_original->{$w};
    }
    return keys %seen;
}

1;
